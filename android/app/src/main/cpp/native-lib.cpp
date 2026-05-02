#include <jni.h>
#include <string>
#include <vector>
#include <mutex>
#include <android/log.h>
#include <unistd.h>
#include <llama.h>

#define LOG_TAG "AIOS-Native"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static llama_model *g_model = nullptr;
static llama_context *g_ctx = nullptr;
static const llama_vocab *g_vocab = nullptr;

static int g_n_past = 0;
static int g_n_ctx = 2048;

static float g_temperature = 0.7f;
static int g_top_k = 40;
static float g_top_p = 0.9f;
static float g_repeat_penalty = 1.1f;

static int g_n_threads = 4;
static int g_n_batch = 512;
static int g_cpu_count = 4;

static std::mutex g_mutex;

class JniStringHolder {
public:
    JniStringHolder(JNIEnv *env, jstring str) : env_(env), str_(str), chars_(nullptr) {
        if (str_) chars_ = env_->GetStringUTFChars(str_, nullptr);
    }
    ~JniStringHolder() {
        if (chars_ && str_) env_->ReleaseStringUTFChars(str_, chars_);
    }
    const char *c_str() const { return chars_; }
    bool valid() const { return chars_ != nullptr; }
    JniStringHolder(const JniStringHolder &) = delete;
    JniStringHolder &operator=(const JniStringHolder &) = delete;
private:
    JNIEnv *env_;
    jstring str_;
    const char *chars_;
};

#define JNI_CATCH_EXCEPTION(env, ret) \
    do { \
        if ((env)->ExceptionCheck()) { \
            LOGE("JNI exception at %s:%d", __FILE__, __LINE__); \
            (env)->ExceptionClear(); \
            return ret; \
        } \
    } while (0)

static std::vector<llama_token> tokenize(const char *text, bool add_bos);
static bool decode_tokens(std::vector<llama_token> &tokens);

static void reset_kv_cache_locked() {
    g_n_past = 0;
}

static std::vector<llama_token> tokenize(const char *text, bool add_bos) {
    if (!g_vocab) {
        LOGE("tokenize: g_vocab is null");
        return {};
    }
    if (!text || strlen(text) == 0) {
        return {};
    }

    const int n_tokens = -llama_tokenize(
        g_vocab, text, strlen(text), nullptr, 0, add_bos, true);

    if (n_tokens <= 0) return {};

    std::vector<llama_token> tokens(n_tokens);
    llama_tokenize(
        g_vocab, text, strlen(text),
        tokens.data(), tokens.size(), add_bos, true);

    return tokens;
}

static bool decode_tokens(std::vector<llama_token> &tokens) {
    if (tokens.empty()) return true;
    if (!g_ctx) return false;

    llama_batch batch = llama_batch_get_one(tokens.data(), static_cast<int32_t>(tokens.size()));
    if (llama_decode(g_ctx, batch) != 0) {
        LOGE("Failed to decode batch (size=%zu, n_past=%d, n_ctx=%d)", tokens.size(), g_n_past, g_n_ctx);
        return false;
    }
    return true;
}

static llama_sampler *create_sampler() {
    llama_sampler *smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(smpl, llama_sampler_init_temp(g_temperature));
    llama_sampler_chain_add(smpl, llama_sampler_init_top_k(g_top_k));
    llama_sampler_chain_add(smpl, llama_sampler_init_top_p(g_top_p, 1));
    llama_sampler_chain_add(smpl, llama_sampler_init_penalties(64, 0.0f, g_repeat_penalty, 0.0f));
    llama_sampler_chain_add(smpl, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
    return smpl;
}

static std::string sample_response(llama_sampler *smpl, int max_tokens, JNIEnv *env, jobject thiz, bool stream) {
    jmethodID onTokenMid = nullptr;
    if (stream) {
        jclass clazz = env->GetObjectClass(thiz);
        if (clazz) {
            onTokenMid = env->GetMethodID(clazz, "onTokenGenerated", "(Ljava/lang/String;)V");
            env->DeleteLocalRef(clazz);
        }
        if (!onTokenMid) {
            LOGE("sample_response: failed to get onTokenGenerated methodID, disabling stream");
            stream = false;
        }
    }

    std::string result;
    int n_decoded = 0;

    while (n_decoded < max_tokens) {
        if (!g_ctx || !g_vocab) break;

        if (g_n_past >= g_n_ctx) {
            LOGE("Context overflow: n_past=%d >= n_ctx=%d", g_n_past, g_n_ctx);
            break;
        }

        llama_token new_token = llama_sampler_sample(smpl, g_ctx, -1);
        if (llama_vocab_is_eog(g_vocab, new_token)) break;

        char buf[256];
        int n = llama_token_to_piece(g_vocab, new_token, buf, sizeof(buf), 0, true);
        if (n > 0) {
            std::string token_str(buf, n);
            result.append(token_str);

            if (stream && onTokenMid) {
                jstring jtoken = env->NewStringUTF(token_str.c_str());
                if (env->ExceptionCheck()) {
                    LOGE("sample_response: JNI exception in NewStringUTF, stopping");
                    env->ExceptionClear();
                    break;
                }
                env->CallVoidMethod(thiz, onTokenMid, jtoken);
                if (env->ExceptionCheck()) {
                    LOGE("sample_response: JNI exception in CallVoidMethod (onTokenGenerated), stopping");
                    env->ExceptionClear();
                    env->DeleteLocalRef(jtoken);
                    break;
                }
                env->DeleteLocalRef(jtoken);
            }
        }

        n_decoded++;
        g_n_past++;
        llama_batch batch = llama_batch_get_one(&new_token, 1);
        if (llama_decode(g_ctx, batch) != 0) {
            LOGE("sample_response: decode failed at token %d", n_decoded);
            break;
        }
    }

    return result;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_agent_aios_LlamaBridge_nativeLoadModel(
        JNIEnv *env, jobject thiz, jstring model_path, jint context_size) {
    std::lock_guard<std::mutex> lock(g_mutex);

    JniStringHolder path(env, model_path);
    if (!path.valid()) return JNI_FALSE;

    LOGI("Loading model from: %s (ctx=%d)", path.c_str(), context_size);

    if (g_ctx) { llama_free(g_ctx); g_ctx = nullptr; }
    if (g_model) { llama_model_free(g_model); g_model = nullptr; g_vocab = nullptr; }

    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0;
    model_params.use_mmap = true;
    model_params.use_mlock = false;

    g_model = llama_model_load_from_file(path.c_str(), model_params);

    if (!g_model) {
        LOGE("Failed to load model: %s", path.c_str());
        return JNI_FALSE;
    }

    g_vocab = llama_model_get_vocab(g_model);

    int n_layers = llama_model_n_layer(g_model);

    g_cpu_count = static_cast<int>(sysconf(_SC_NPROCESSORS_ONLN));
    if (g_cpu_count <= 0) g_cpu_count = 4;

    g_n_threads = std::max(2, std::min(g_cpu_count * 3 / 5, 8));
    if (n_layers <= 24) g_n_threads = std::min(g_n_threads, 4);

    g_n_ctx = context_size;
    g_n_batch = std::min(1024, context_size / 2);

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = context_size;
    ctx_params.n_batch = g_n_batch;
    ctx_params.n_threads = g_n_threads;
    ctx_params.n_threads_batch = g_n_threads;

    g_ctx = llama_init_from_model(g_model, ctx_params);
    if (!g_ctx) {
        LOGE("Failed to create context");
        llama_model_free(g_model);
        g_model = nullptr;
        g_vocab = nullptr;
        return JNI_FALSE;
    }

    reset_kv_cache_locked();
    LOGI("Model loaded (n_ctx=%d, n_batch=%d, n_threads=%d, n_layers=%d, cpu=%d)",
         context_size, g_n_batch, g_n_threads, n_layers, g_cpu_count);
    return JNI_TRUE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_agent_aios_LlamaBridge_nativeFormatChat(
        JNIEnv *env, jobject thiz, jobjectArray roles, jobjectArray contents) {
    std::lock_guard<std::mutex> lock(g_mutex);

    if (!g_model) return env->NewStringUTF("");

    jsize len = env->GetArrayLength(roles);
    JNI_CATCH_EXCEPTION(env, env->NewStringUTF(""));
    if (len == 0) return env->NewStringUTF("");

    std::vector<std::string> role_strings;
    std::vector<std::string> content_strings;

    role_strings.reserve(len);
    content_strings.reserve(len);

    for (jsize i = 0; i < len; i++) {
        auto *role_str = static_cast<jstring>(env->GetObjectArrayElement(roles, i));
        auto *content_str = static_cast<jstring>(env->GetObjectArrayElement(contents, i));

        if (env->ExceptionCheck()) {
            LOGE("nativeFormatChat: exception getting array element %d", i);
            env->ExceptionClear();
            if (role_str) env->DeleteLocalRef(role_str);
            if (content_str) env->DeleteLocalRef(content_str);
            continue;
        }

        if (!role_str || !content_str) {
            if (role_str) env->DeleteLocalRef(role_str);
            if (content_str) env->DeleteLocalRef(content_str);
            continue;
        }

        const char *role = env->GetStringUTFChars(role_str, nullptr);
        const char *content = env->GetStringUTFChars(content_str, nullptr);

        if (role && content) {
            role_strings.emplace_back(role);
            content_strings.emplace_back(content);
        }

        if (role) env->ReleaseStringUTFChars(role_str, role);
        if (content) env->ReleaseStringUTFChars(content_str, content);
        env->DeleteLocalRef(role_str);
        env->DeleteLocalRef(content_str);
    }

    std::vector<llama_chat_message> messages;
    messages.reserve(role_strings.size());
    for (size_t i = 0; i < role_strings.size(); i++) {
        messages.push_back({role_strings[i].c_str(), content_strings[i].c_str()});
    }

    std::vector<char> buf(4096);
    int32_t res = llama_chat_apply_template(
        nullptr, messages.data(), static_cast<int32_t>(messages.size()),
        true, buf.data(), static_cast<int32_t>(buf.size()));

    if (res < 0) {
        LOGE("nativeFormatChat: llama_chat_apply_template failed");
        return env->NewStringUTF("");
    }

    if (res >= static_cast<int32_t>(buf.size())) {
        buf.resize(res + 1);
        messages.clear();
        for (size_t i = 0; i < role_strings.size(); i++) {
            messages.push_back({role_strings[i].c_str(), content_strings[i].c_str()});
        }
        llama_chat_apply_template(
            nullptr, messages.data(), static_cast<int32_t>(messages.size()),
            true, buf.data(), static_cast<int32_t>(buf.size()));
    }

    jstring result = env->NewStringUTF(std::string(buf.data(), res).c_str());
    JNI_CATCH_EXCEPTION(env, env->NewStringUTF(""));
    return result;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_agent_aios_LlamaBridge_nativeInfer(
        JNIEnv *env, jobject thiz, jstring prompt, jint max_tokens) {
    std::lock_guard<std::mutex> lock(g_mutex);

    if (!g_ctx || !g_model || !g_vocab) return -1;

    JniStringHolder prompt_holder(env, prompt);
    if (!prompt_holder.valid()) return -1;

    const char *prompt_str = prompt_holder.c_str();
    LOGI("Infer: tokenizing (%zu chars, n_past=%d/%d)", strlen(prompt_str), g_n_past, g_n_ctx);

    bool add_bos = (g_n_past == 0);
    auto tokens = tokenize(prompt_str, add_bos);

    if (tokens.empty() && strlen(prompt_str) > 0) {
        LOGE("nativeInfer: tokenization failed for non-empty prompt");
        return -1;
    }

    if (!decode_tokens(tokens)) {
        return -1;
    }
    g_n_past += static_cast<int>(tokens.size());

    llama_sampler *smpl = create_sampler();
    std::string result = sample_response(smpl, max_tokens, env, thiz, true);
    llama_sampler_free(smpl);

    LOGI("Infer done: %zu chars (n_past=%d/%d)", result.size(), g_n_past, g_n_ctx);
    return static_cast<jint>(result.size());
}

extern "C" JNIEXPORT void JNICALL
Java_com_agent_aios_LlamaBridge_nativeReleaseModel(
        JNIEnv *env, jobject thiz) {
    std::lock_guard<std::mutex> lock(g_mutex);
    reset_kv_cache_locked();
    if (g_ctx) { llama_free(g_ctx); g_ctx = nullptr; }
    if (g_model) { llama_model_free(g_model); g_model = nullptr; g_vocab = nullptr; }
    LOGI("Model released");
}

extern "C" JNIEXPORT void JNICALL
Java_com_agent_aios_LlamaBridge_nativeResetContext(
        JNIEnv *env, jobject thiz) {
    std::lock_guard<std::mutex> lock(g_mutex);
    reset_kv_cache_locked();
    LOGI("Context reset");
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_agent_aios_LlamaBridge_nativeIsModelLoaded(
        JNIEnv *env, jobject thiz) {
    std::lock_guard<std::mutex> lock(g_mutex);
    return (g_model != nullptr && g_ctx != nullptr) ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_agent_aios_LlamaBridge_nativeGetModelInfo(
        JNIEnv *env, jobject thiz) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!g_model) return env->NewStringUTF("No model loaded");

    int n_ctx_train = llama_model_n_ctx_train(g_model);
    int n_embd = llama_model_n_embd(g_model);
    int n_layer = llama_model_n_layer(g_model);

    char info[512];
    snprintf(info, sizeof(info),
             "n_ctx_train=%d, n_embd=%d, n_layer=%d, threads=%d, batch=%d, cpu=%d",
             n_ctx_train, n_embd, n_layer, g_n_threads, g_n_batch, g_cpu_count);
    return env->NewStringUTF(info);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_agent_aios_LlamaBridge_nativeGetContextUsage(
        JNIEnv *env, jobject thiz) {
    std::lock_guard<std::mutex> lock(g_mutex);
    char usage[64];
    snprintf(usage, sizeof(usage), "%d/%d", g_n_past, g_n_ctx);
    return env->NewStringUTF(usage);
}

extern "C" JNIEXPORT void JNICALL
Java_com_agent_aios_LlamaBridge_nativeSetSamplingParams(
        JNIEnv *env, jobject thiz, jfloat temperature, jint top_k, jfloat top_p, jfloat repeat_penalty) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_temperature = temperature;
    g_top_k = top_k;
    g_top_p = top_p;
    g_repeat_penalty = repeat_penalty;
    LOGI("Sampling: temp=%.2f, top_k=%d, top_p=%.2f, rep_penalty=%.2f",
         g_temperature, g_top_k, g_top_p, g_repeat_penalty);
}
