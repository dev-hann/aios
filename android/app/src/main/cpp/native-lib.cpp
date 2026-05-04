#include <jni.h>
#include <string>
#include <vector>
#include <mutex>
#include <android/log.h>
#include <unistd.h>
#include <llama.h>
#include <ggml-backend.h>

#define LOG_TAG "AIOS-Native"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

constexpr int BATCH_SIZE = 512;
constexpr int OVERFLOW_HEADROOM = 4;
constexpr int N_THREADS_MIN = 2;
constexpr int N_THREADS_MAX = 4;
constexpr int N_THREADS_HEADROOM = 2;

static llama_model *g_model = nullptr;
static llama_context *g_ctx = nullptr;
static const llama_vocab *g_vocab = nullptr;
static llama_batch g_batch = {};
static llama_sampler *g_sampler = nullptr;

static llama_pos g_current_pos = 0;
static int g_n_ctx = 2048;
static int g_n_threads = 4;

static float g_temperature = 0.7f;
static int g_top_k = 40;
static float g_top_p = 0.9f;
static float g_repeat_penalty = 1.1f;

static std::string g_cached_token_chars;
static bool g_initialized = false;
static llama_pos g_system_prompt_pos = 0;

static float g_load_progress = 0.0f;
static int g_load_stage = 0;
static std::string g_load_model_name;

static std::mutex g_mutex;

static void batch_clear() { g_batch.n_tokens = 0; }

static void batch_add(llama_token id, llama_pos pos, bool logits) {
    int i = g_batch.n_tokens;
    g_batch.token[i] = id;
    g_batch.pos[i] = pos;
    g_batch.n_seq_id[i] = 1;
    g_batch.seq_id[i][0] = 0;
    g_batch.logits[i] = logits;
    g_batch.n_tokens++;
}

static void shift_context() {
    const int n_discard = (g_current_pos - g_system_prompt_pos) / 2;
    if (n_discard <= 0) return;
    LOGI("shift_context: discard %d (cur=%d, sys=%d, ctx=%d)",
         n_discard, (int)g_current_pos, (int)g_system_prompt_pos, g_n_ctx);
    llama_memory_t mem = llama_get_memory(g_ctx);
    llama_memory_seq_rm(mem, 0, g_system_prompt_pos, g_system_prompt_pos + n_discard);
    llama_memory_seq_add(mem, 0, g_system_prompt_pos + n_discard, g_current_pos, -n_discard);
    g_current_pos -= n_discard;
    LOGI("shift_context: done, pos=%d", (int)g_current_pos);
}

static std::vector<llama_token> tokenize(const char *text, bool add_bos) {
    if (!g_vocab || !text || strlen(text) == 0) return {};
    const int n_tokens = -llama_tokenize(
        g_vocab, text, strlen(text), nullptr, 0, add_bos, true);
    if (n_tokens <= 0) return {};
    std::vector<llama_token> tokens(n_tokens);
    llama_tokenize(g_vocab, text, strlen(text), tokens.data(), tokens.size(), add_bos, true);
    return tokens;
}

static int decode_tokens(const std::vector<llama_token> &tokens, llama_pos start_pos, bool last_logit) {
    for (int i = 0; i < (int)tokens.size(); i += BATCH_SIZE) {
        int cur_size = std::min((int)tokens.size() - i, BATCH_SIZE);
        if (start_pos + i + cur_size >= g_n_ctx - OVERFLOW_HEADROOM) {
            shift_context();
        }
        batch_clear();
        for (int j = 0; j < cur_size; j++) {
            bool want_logit = last_logit && (i + j == (int)tokens.size() - 1);
            batch_add(tokens[i + j], start_pos + i + j, want_logit);
        }
        int rc = llama_decode(g_ctx, g_batch);
        if (rc != 0) {
            LOGE("decode_tokens: failed at offset %d (rc=%d)", i, rc);
            return -1;
        }
    }
    return 0;
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

static bool is_valid_utf8(const char *s) {
    if (!s) return true;
    const auto *bytes = (const unsigned char *)s;
    while (*bytes != 0) {
        int num;
        if ((*bytes & 0x80) == 0x00)        num = 1;
        else if ((*bytes & 0xE0) == 0xC0)   num = 2;
        else if ((*bytes & 0xF0) == 0xE0)   num = 3;
        else if ((*bytes & 0xF8) == 0xF0)   num = 4;
        else return false;
        bytes += 1;
        for (int i = 1; i < num; ++i) {
            if ((*bytes & 0xC0) != 0x80) return false;
            bytes += 1;
        }
    }
    return true;
}

static int processPromptInternal(JNIEnv *env, jstring prompt, bool set_sys_pos, const char *func_name) {
    if (!g_ctx || !g_model || !g_vocab) return -1;

    const char *str = env->GetStringUTFChars(prompt, nullptr);
    if (!str) return -1;
    LOGI("%s: %zu chars (pos=%d/%d)", func_name, strlen(str), (int)g_current_pos, g_n_ctx);

    g_cached_token_chars.clear();
    if (g_sampler) { llama_sampler_free(g_sampler); g_sampler = nullptr; }
    g_sampler = create_sampler();

    bool add_bos = (g_current_pos == 0);
    auto tokens = tokenize(str, add_bos);
    env->ReleaseStringUTFChars(prompt, str);

    if (tokens.empty()) { LOGE("%s: tokenize failed", func_name); return -1; }
    if ((int)tokens.size() >= g_n_ctx) { LOGE("%s: too many tokens", func_name); return -1; }

    if (decode_tokens(tokens, g_current_pos, true) != 0) return -1;

    g_current_pos += (llama_pos)tokens.size();
    if (set_sys_pos) g_system_prompt_pos = g_current_pos;

    LOGI("%s: done (%zu tokens, pos=%d)", func_name, tokens.size(), (int)g_current_pos);
    return 0;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_agent_aios_LlamaBridge_nativeInit(
        JNIEnv *env, jobject, jstring nativeLibDir) {
    if (g_initialized) return JNI_TRUE;
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_initialized) return JNI_TRUE;
    const char *dir = env->GetStringUTFChars(nativeLibDir, nullptr);
    if (!dir) {
        LOGE("nativeInit: failed to get native lib dir string");
        return JNI_FALSE;
    }
    LOGI("nativeInit: loading backends from %s", dir);
    ggml_backend_load_all_from_path(dir);
    env->ReleaseStringUTFChars(nativeLibDir, dir);
    llama_backend_init();
    g_initialized = true;
    LOGI("nativeInit: done");
    return JNI_TRUE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_agent_aios_LlamaBridge_nativeLoadModel(
        JNIEnv *env, jobject, jstring model_path, jint context_size) {
    std::lock_guard<std::mutex> lock(g_mutex);
    const char *path = env->GetStringUTFChars(model_path, nullptr);
    if (!path) return JNI_FALSE;
    LOGI("loadModel: %s (ctx=%d)", path, context_size);

    g_load_progress = 0.0f;
    g_load_stage = 0;
    std::string path_str(path);
    size_t slash_pos = path_str.find_last_of('/');
    g_load_model_name = (slash_pos != std::string::npos) ? path_str.substr(slash_pos + 1) : path_str;
    env->ReleaseStringUTFChars(model_path, path);

    if (g_sampler) { llama_sampler_free(g_sampler); g_sampler = nullptr; }
    if (g_batch.token) { llama_batch_free(g_batch); g_batch = {}; }
    if (g_ctx) { llama_free(g_ctx); g_ctx = nullptr; }
    if (g_model) { llama_model_free(g_model); g_model = nullptr; g_vocab = nullptr; }

    g_load_progress = 0.05f;
    g_load_stage = 1;

    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0;
    model_params.use_mmap = true;
    model_params.use_mlock = false;
    model_params.progress_callback = [](float progress, void *) {
        g_load_progress = 0.05f + progress * 0.75f;
        return true;
    };

    g_model = llama_model_load_from_file(path_str.c_str(), model_params);

    if (!g_model) {
        LOGE("loadModel: model load failed");
        g_load_stage = -1;
        return JNI_FALSE;
    }

    g_load_progress = 0.8f;
    g_load_stage = 2;
    g_vocab = llama_model_get_vocab(g_model);

    g_n_threads = std::max(N_THREADS_MIN, std::min(N_THREADS_MAX,
        (int)sysconf(_SC_NPROCESSORS_ONLN) - N_THREADS_HEADROOM));
    int n_layers = llama_model_n_layer(g_model);
    if (n_layers <= 24) g_n_threads = std::min(g_n_threads, 4);

    g_n_ctx = context_size;
    g_load_progress = 0.85f;

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = context_size;
    ctx_params.n_batch = BATCH_SIZE;
    ctx_params.n_ubatch = BATCH_SIZE;
    ctx_params.n_threads = g_n_threads;
    ctx_params.n_threads_batch = g_n_threads;

    g_ctx = llama_init_from_model(g_model, ctx_params);
    if (!g_ctx) {
        LOGE("loadModel: context creation failed");
        llama_model_free(g_model);
        g_model = nullptr;
        g_vocab = nullptr;
        g_load_stage = -1;
        return JNI_FALSE;
    }

    g_load_progress = 0.95f;
    g_load_stage = 3;

    g_batch = llama_batch_init(BATCH_SIZE, 0, 1);
    g_sampler = create_sampler();
    g_current_pos = 0;
    g_cached_token_chars.clear();
    g_system_prompt_pos = 0;

    g_load_progress = 1.0f;
    g_load_stage = 4;

    LOGI("loadModel: done (ctx=%d, threads=%d, layers=%d)", context_size, g_n_threads, n_layers);
    return JNI_TRUE;
}

extern "C" JNIEXPORT jfloat JNICALL
Java_com_agent_aios_LlamaBridge_nativeGetLoadProgress(JNIEnv *, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    return g_load_progress;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_agent_aios_LlamaBridge_nativeGetLoadStage(JNIEnv *, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    return g_load_stage;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_agent_aios_LlamaBridge_nativeGetLoadModelName(JNIEnv *env, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    return env->NewStringUTF(g_load_model_name.c_str());
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_agent_aios_LlamaBridge_nativeFormatChat(
        JNIEnv *env, jobject, jobjectArray roles, jobjectArray contents) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!g_model) return env->NewStringUTF("");

    jsize len = env->GetArrayLength(roles);
    if (len == 0) return env->NewStringUTF("");

    std::vector<std::string> role_strs, content_strs;
    for (jsize i = 0; i < len; i++) {
        auto *r = static_cast<jstring>(env->GetObjectArrayElement(roles, i));
        auto *c = static_cast<jstring>(env->GetObjectArrayElement(contents, i));
        if (env->ExceptionCheck()) { env->ExceptionClear(); continue; }
        if (!r || !c) continue;
        const char *rv = env->GetStringUTFChars(r, nullptr);
        const char *cv = env->GetStringUTFChars(c, nullptr);
        if (rv && cv) { role_strs.emplace_back(rv); content_strs.emplace_back(cv); }
        if (rv) env->ReleaseStringUTFChars(r, rv);
        if (cv) env->ReleaseStringUTFChars(c, cv);
        env->DeleteLocalRef(r);
        env->DeleteLocalRef(c);
    }

    std::vector<llama_chat_message> msgs;
    msgs.reserve(role_strs.size());
    for (size_t i = 0; i < role_strs.size(); i++) {
        msgs.push_back({role_strs[i].c_str(), content_strs[i].c_str()});
    }

    std::vector<char> buf(4096);
    int32_t res = llama_chat_apply_template(nullptr, msgs.data(), (int32_t)msgs.size(), true, buf.data(), (int32_t)buf.size());
    if (res < 0) return env->NewStringUTF("");
    if (res >= (int32_t)buf.size()) {
        buf.resize(res + 1);
        msgs.clear();
        msgs.reserve(role_strs.size());
        for (size_t i = 0; i < role_strs.size(); i++) msgs.push_back({role_strs[i].c_str(), content_strs[i].c_str()});
        llama_chat_apply_template(nullptr, msgs.data(), (int32_t)msgs.size(), true, buf.data(), (int32_t)buf.size());
    }
    return env->NewStringUTF(std::string(buf.data(), res).c_str());
}

extern "C" JNIEXPORT jint JNICALL
Java_com_agent_aios_LlamaBridge_nativeProcessSystemPrompt(
        JNIEnv *env, jobject, jstring prompt) {
    std::lock_guard<std::mutex> lock(g_mutex);
    return processPromptInternal(env, prompt, true, "processSystemPrompt");
}

extern "C" JNIEXPORT jint JNICALL
Java_com_agent_aios_LlamaBridge_nativeProcessPrompt(
        JNIEnv *env, jobject, jstring prompt) {
    std::lock_guard<std::mutex> lock(g_mutex);
    return processPromptInternal(env, prompt, false, "processPrompt");
}

extern "C" JNIEXPORT jint JNICALL
Java_com_agent_aios_LlamaBridge_nativeProcessPromptIncremental(
        JNIEnv *env, jobject, jstring prompt) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!g_ctx || !g_model || !g_vocab) return -1;

    const char *str = env->GetStringUTFChars(prompt, nullptr);
    if (!str) return -1;
    LOGI("processPromptInc: %zu chars (reset KV, full decode)", strlen(str));

    llama_memory_clear(llama_get_memory(g_ctx), false);
    g_current_pos = 0;
    g_system_prompt_pos = 0;
    g_cached_token_chars.clear();
    if (g_sampler) { llama_sampler_free(g_sampler); g_sampler = nullptr; }
    g_sampler = create_sampler();

    auto tokens = tokenize(str, true);
    env->ReleaseStringUTFChars(prompt, str);

    if (tokens.empty()) { LOGE("processPromptInc: tokenize failed"); return -1; }
    if ((int)tokens.size() >= g_n_ctx) { LOGE("processPromptInc: too many tokens"); return -1; }

    if (decode_tokens(tokens, 0, true) != 0) return -1;

    g_current_pos = (llama_pos)tokens.size();
    LOGI("processPromptInc: done (pos=%d, tokens=%zu)", (int)g_current_pos, tokens.size());
    return 0;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_agent_aios_LlamaBridge_nativeGenerateOneToken(JNIEnv *env, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!g_ctx || !g_model || !g_vocab) return nullptr;
    if (!g_sampler) g_sampler = create_sampler();
    if (!g_sampler) return nullptr;

    if (g_current_pos >= g_n_ctx - OVERFLOW_HEADROOM) shift_context();

    llama_token new_token = llama_sampler_sample(g_sampler, g_ctx, -1);

    if (llama_vocab_is_eog(g_vocab, new_token)) {
        LOGI("generateOneToken: EOG");
        return nullptr;
    }

    batch_clear();
    batch_add(new_token, g_current_pos, true);
    if (llama_decode(g_ctx, g_batch) != 0) {
        LOGE("generateOneToken: decode failed");
        return nullptr;
    }
    g_current_pos++;

    char buf[256];
    int n = llama_token_to_piece(g_vocab, new_token, buf, sizeof(buf), 0, true);
    if (n <= 0) return env->NewStringUTF("");

    std::string token_str(buf, n);
    g_cached_token_chars += token_str;

    jstring result = nullptr;
    if (is_valid_utf8(g_cached_token_chars.c_str())) {
        result = env->NewStringUTF(g_cached_token_chars.c_str());
        g_cached_token_chars.clear();
    } else {
        result = env->NewStringUTF("");
    }
    return result;
}

extern "C" JNIEXPORT void JNICALL
Java_com_agent_aios_LlamaBridge_nativeSetSystemPromptPosition(JNIEnv *, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_system_prompt_pos == 0) {
        g_system_prompt_pos = g_current_pos;
        LOGI("system_prompt_pos=%d", (int)g_system_prompt_pos);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_agent_aios_LlamaBridge_nativeReleaseModel(JNIEnv *, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_current_pos = 0;
    g_system_prompt_pos = 0;
    g_cached_token_chars.clear();
    if (g_sampler) { llama_sampler_free(g_sampler); g_sampler = nullptr; }
    if (g_batch.token) { llama_batch_free(g_batch); g_batch = {}; }
    if (g_ctx) { llama_free(g_ctx); g_ctx = nullptr; }
    if (g_model) { llama_model_free(g_model); g_model = nullptr; g_vocab = nullptr; }
    g_load_progress = 0.0f;
    g_load_stage = 0;
    g_load_model_name.clear();
    LOGI("Model released");
}

extern "C" JNIEXPORT void JNICALL
Java_com_agent_aios_LlamaBridge_nativeResetContext(JNIEnv *, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_ctx) llama_memory_clear(llama_get_memory(g_ctx), false);
    g_current_pos = 0;
    g_system_prompt_pos = 0;
    g_cached_token_chars.clear();
    LOGI("Context reset");
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_agent_aios_LlamaBridge_nativeIsModelLoaded(JNIEnv *, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    return (g_model && g_ctx) ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_agent_aios_LlamaBridge_nativeGetModelInfo(JNIEnv *env, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!g_model) return env->NewStringUTF("No model loaded");
    char info[512];
    snprintf(info, sizeof(info), "n_ctx_train=%d, n_embd=%d, n_layer=%d, threads=%d, ctx=%d",
        llama_model_n_ctx_train(g_model), llama_model_n_embd(g_model),
        llama_model_n_layer(g_model), g_n_threads, g_n_ctx);
    return env->NewStringUTF(info);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_agent_aios_LlamaBridge_nativeGetContextUsage(JNIEnv *env, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    char buf[64];
    snprintf(buf, sizeof(buf), "%d/%d", (int)g_current_pos, g_n_ctx);
    return env->NewStringUTF(buf);
}

extern "C" JNIEXPORT void JNICALL
Java_com_agent_aios_LlamaBridge_nativeSetSamplingParams(
        JNIEnv *, jobject, jfloat temp, jint top_k, jfloat top_p, jfloat rep_penalty) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_temperature = temp;
    g_top_k = top_k;
    g_top_p = top_p;
    g_repeat_penalty = rep_penalty;
}
