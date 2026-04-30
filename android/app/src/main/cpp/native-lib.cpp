#include <jni.h>
#include <string>
#include <vector>
#include <android/log.h>
#include <llama.h>

#define LOG_TAG "AIOS-Native"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static llama_model *g_model = nullptr;
static llama_context *g_ctx = nullptr;
static const llama_vocab *g_vocab = nullptr;

static std::vector<llama_chat_message> g_chat_messages;
static int g_n_past = 0;

static void reset_kv_cache() {
    g_chat_messages.clear();
    g_n_past = 0;
}

static std::string apply_chat_template_full(const std::vector<llama_chat_message> &messages) {
    std::vector<char> buf(4096);
    int32_t res = llama_chat_apply_template(
        nullptr,
        const_cast<llama_chat_message*>(messages.data()),
        static_cast<int32_t>(messages.size()),
        true,
        buf.data(),
        static_cast<int32_t>(buf.size())
    );

    if (res < 0) {
        LOGE("llama_chat_apply_template failed");
        return "";
    }

    if (res >= static_cast<int32_t>(buf.size())) {
        buf.resize(res + 1);
        llama_chat_apply_template(
            nullptr,
            const_cast<llama_chat_message*>(messages.data()),
            static_cast<int32_t>(messages.size()),
            true,
            buf.data(),
            static_cast<int32_t>(buf.size())
        );
    }

    return std::string(buf.data(), res);
}

static std::vector<llama_token> tokenize(const char *text, bool add_bos) {
    const int n_tokens = -llama_tokenize(
        g_vocab, text, strlen(text), nullptr, 0, add_bos, true);

    std::vector<llama_token> tokens(n_tokens);
    llama_tokenize(
        g_vocab, text, strlen(text),
        tokens.data(), tokens.size(), add_bos, true);

    return tokens;
}

static bool decode_tokens(std::vector<llama_token> &tokens) {
    llama_batch batch = llama_batch_get_one(tokens.data(), static_cast<int32_t>(tokens.size()));
    if (llama_decode(g_ctx, batch) != 0) {
        LOGE("Failed to decode batch");
        return false;
    }
    return true;
}

static llama_sampler *create_sampler() {
    llama_sampler *smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(smpl, llama_sampler_init_temp(0.7f));
    llama_sampler_chain_add(smpl, llama_sampler_init_top_k(40));
    llama_sampler_chain_add(smpl, llama_sampler_init_top_p(0.9f, 1));
    llama_sampler_chain_add(smpl, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
    return smpl;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_agent_aios_LlamaBridge_nativeLoadModel(
        JNIEnv *env, jobject thiz, jstring model_path, jint context_size) {
    const char *path = env->GetStringUTFChars(model_path, nullptr);
    if (!path) {
        LOGE("Failed to get model path string");
        return JNI_FALSE;
    }

    LOGI("Loading model from: %s", path);

    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0;

    g_model = llama_model_load_from_file(path, model_params);
    env->ReleaseStringUTFChars(model_path, path);

    if (!g_model) {
        LOGE("Failed to load model");
        return JNI_FALSE;
    }

    g_vocab = llama_model_get_vocab(g_model);
    LOGI("Model loaded successfully");

    int n_layers = llama_model_n_layer(g_model);
    int n_threads = (n_layers <= 24) ? 4 : 6;

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = context_size;
    ctx_params.n_batch = 1024;
    ctx_params.n_threads = n_threads;
    ctx_params.n_threads_batch = n_threads;

    g_ctx = llama_init_from_model(g_model, ctx_params);
    if (!g_ctx) {
        LOGE("Failed to create context");
        llama_model_free(g_model);
        g_model = nullptr;
        g_vocab = nullptr;
        return JNI_FALSE;
    }

    reset_kv_cache();
    LOGI("Context created (n_ctx=%d, n_threads=%d, n_layers=%d)", context_size, n_threads, n_layers);
    return JNI_TRUE;
}

static jint generate_stream_internal(
        JNIEnv *env, jobject thiz, jstring prompt, jint max_tokens, bool stream) {

    if (!g_ctx || !g_model || !g_vocab) {
        return -1;
    }

    const char *prompt_str = env->GetStringUTFChars(prompt, nullptr);
    if (!prompt_str) return -1;

    g_chat_messages.push_back({"user", prompt_str});
    env->ReleaseStringUTFChars(prompt, prompt_str);

    std::string formatted = apply_chat_template_full(g_chat_messages);
    if (formatted.empty()) {
        g_chat_messages.pop_back();
        return -1;
    }

    LOGI("%s: template applied (%zu chars, n_past=%d)",
         stream ? "Stream" : "Generate", formatted.size(), g_n_past);

    auto tokens = tokenize(formatted.c_str(), g_n_past == 0);

    if (g_n_past > 0 && tokens.size() > 1) {
        tokens.erase(tokens.begin());
    }

    if (!tokens.empty()) {
        if (!decode_tokens(tokens)) {
            g_chat_messages.pop_back();
            return -1;
        }
        g_n_past += static_cast<int>(tokens.size());
    }

    jmethodID onTokenMid = nullptr;
    if (stream) {
        jclass clazz = env->GetObjectClass(thiz);
        onTokenMid = env->GetMethodID(clazz, "onTokenGenerated", "(Ljava/lang/String;)V");
        if (!onTokenMid) {
            LOGE("onTokenGenerated method not found");
            return -1;
        }
    }

    int n_decoded = 0;
    std::string result;
    llama_sampler *smpl = create_sampler();

    while (n_decoded < max_tokens) {
        llama_token new_token = llama_sampler_sample(smpl, g_ctx, -1);

        if (llama_vocab_is_eog(g_vocab, new_token)) break;

        char buf[256];
        int n = llama_token_to_piece(g_vocab, new_token, buf, sizeof(buf), 0, true);
        if (n > 0) {
            std::string token_str(buf, n);
            result.append(token_str);

            if (stream && onTokenMid) {
                jstring jtoken = env->NewStringUTF(token_str.c_str());
                env->CallVoidMethod(thiz, onTokenMid, jtoken);
                env->DeleteLocalRef(jtoken);
            }
        }

        n_decoded++;
        g_n_past++;
        llama_batch batch = llama_batch_get_one(&new_token, 1);
        if (llama_decode(g_ctx, batch) != 0) break;
    }

    llama_sampler_free(smpl);

    g_chat_messages.push_back({"assistant", result});

    LOGI("%s done: %d tokens (n_past=%d)", stream ? "Stream" : "Generate", n_decoded, g_n_past);
    return n_decoded;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_agent_aios_LlamaBridge_nativeGenerate(
        JNIEnv *env, jobject thiz, jstring prompt, jint max_tokens) {
    if (!g_ctx || !g_model || !g_vocab) {
        return env->NewStringUTF("Error: model not loaded");
    }

    const char *prompt_str = env->GetStringUTFChars(prompt, nullptr);
    if (!prompt_str) {
        return env->NewStringUTF("Error: invalid prompt");
    }

    reset_kv_cache();

    std::string formatted;
    {
        std::vector<llama_chat_message> msgs = {
            {"system", "You are an AI agent. Respond EXACTLY in one of these formats:\n1. Action: tool_name\\nArgs: {\"param\": \"value\"}\n2. Answer: your response\nBe concise."},
            {"user", prompt_str}
        };
        formatted = apply_chat_template_full(msgs);
    }
    env->ReleaseStringUTFChars(prompt, prompt_str);

    if (formatted.empty()) {
        return env->NewStringUTF("Error: template failed");
    }

    LOGI("Generate (standalone): template applied (%zu chars)", formatted.size());

    auto tokens = tokenize(formatted.c_str(), true);
    if (!decode_tokens(tokens)) {
        return env->NewStringUTF("Error: decode failed");
    }

    std::string result;
    int n_decoded = 0;
    llama_sampler *smpl = create_sampler();

    while (n_decoded < max_tokens) {
        llama_token new_token = llama_sampler_sample(smpl, g_ctx, -1);
        if (llama_vocab_is_eog(g_vocab, new_token)) break;

        char buf[256];
        int n = llama_token_to_piece(g_vocab, new_token, buf, sizeof(buf), 0, true);
        if (n > 0) result.append(buf, n);

        n_decoded++;
        llama_batch batch = llama_batch_get_one(&new_token, 1);
        if (llama_decode(g_ctx, batch) != 0) break;
    }

    llama_sampler_free(smpl);
    LOGI("Generated %d tokens", n_decoded);
    return env->NewStringUTF(result.c_str());
}

extern "C" JNIEXPORT jint JNICALL
Java_com_agent_aios_LlamaBridge_nativeGenerateStream(
        JNIEnv *env, jobject thiz, jstring prompt, jint max_tokens) {
    return generate_stream_internal(env, thiz, prompt, max_tokens, true);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_agent_aios_LlamaBridge_nativeGenerateStreamStandalone(
        JNIEnv *env, jobject thiz, jstring prompt, jint max_tokens) {
    reset_kv_cache();
    return generate_stream_internal(env, thiz, prompt, max_tokens, true);
}

extern "C" JNIEXPORT void JNICALL
Java_com_agent_aios_LlamaBridge_nativeReleaseModel(
        JNIEnv *env, jobject thiz) {
    reset_kv_cache();
    if (g_ctx) {
        llama_free(g_ctx);
        g_ctx = nullptr;
        LOGI("Context released");
    }
    if (g_model) {
        llama_model_free(g_model);
        g_model = nullptr;
        g_vocab = nullptr;
        LOGI("Model released");
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_agent_aios_LlamaBridge_nativeResetContext(
        JNIEnv *env, jobject thiz) {
    reset_kv_cache();
    if (g_ctx) {
        llama_kv_cache_clear(g_ctx);
        LOGI("KV cache cleared, context reset");
    }
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_agent_aios_LlamaBridge_nativeIsModelLoaded(
        JNIEnv *env, jobject thiz) {
    return (g_model != nullptr && g_ctx != nullptr) ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_agent_aios_LlamaBridge_nativeGetModelInfo(
        JNIEnv *env, jobject thiz) {
    if (!g_model) {
        return env->NewStringUTF("No model loaded");
    }

    int n_ctx_train = llama_model_n_ctx_train(g_model);
    int n_embd = llama_model_n_embd(g_model);
    int n_layer = llama_model_n_layer(g_model);
    int n_threads = (n_layer <= 24) ? 4 : 6;

    char info[512];
    snprintf(info, sizeof(info),
             "n_ctx_train=%d, n_embd=%d, n_layer=%d, threads=%d",
             n_ctx_train, n_embd, n_layer, n_threads);
    return env->NewStringUTF(info);
}
