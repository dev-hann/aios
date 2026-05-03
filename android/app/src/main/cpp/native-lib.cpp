#include <jni.h>
#include <string>
#include <vector>
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

static std::vector<llama_token> g_kv_tokens;
static llama_pos g_system_prompt_end = 0;

static std::vector<uint8_t> g_cached_system_kv;
static std::vector<llama_token> g_cached_system_tokens;

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

struct PrefixResult {
    int kv_keep;
    int new_start_idx;
};

static PrefixResult find_common_prefix(const std::vector<llama_token> &new_tokens) {
    if (g_kv_tokens.empty() || new_tokens.empty()) return {0, 0};

    int kv_i = 0;
    int new_i = 0;

    llama_token bos = llama_vocab_bos(g_vocab);
    if (g_kv_tokens[0] == bos && new_tokens[0] != bos) {
        kv_i = 1;
    }
    if (new_tokens[0] == bos && g_kv_tokens[0] != bos) {
        new_i = 1;
    }

    while (kv_i < (int)g_kv_tokens.size() && new_i < (int)new_tokens.size()) {
        if (g_kv_tokens[kv_i] != new_tokens[new_i]) break;
        kv_i++;
        new_i++;
    }

    return {kv_i, new_i};
}

static void shift_context() {
    const int n_discard = (g_current_pos - g_system_prompt_end) / 2;
    if (n_discard <= 0) return;
    LOGI("shift_context: discarding %d tokens (cur=%d, sys_end=%d, ctx=%d)",
         n_discard, (int)g_current_pos, (int)g_system_prompt_end, g_n_ctx);
    llama_memory_t mem = llama_get_memory(g_ctx);
    llama_memory_seq_rm(mem, 0, g_system_prompt_end, g_system_prompt_end + n_discard);
    llama_memory_seq_add(mem, 0, g_system_prompt_end + n_discard, g_current_pos, -n_discard);
    g_current_pos -= n_discard;

    auto erase_end = g_kv_tokens.begin() + std::min<size_t>(g_system_prompt_end + n_discard, g_kv_tokens.size());
    g_kv_tokens.erase(g_kv_tokens.begin() + g_system_prompt_end, erase_end);

    LOGI("shift_context: done, pos=%d, kv_tokens=%zu", (int)g_current_pos, g_kv_tokens.size());
}

static std::vector<llama_token> tokenize(const char *text, bool add_bos) {
    if (!g_vocab || !text || strlen(text) == 0) return {};
    const int n_tokens = -llama_tokenize(
        g_vocab, text, strlen(text), nullptr, 0, add_bos, true);
    if (n_tokens <= 0) return {};
    std::vector<llama_token> tokens(n_tokens);
    llama_tokenize(
        g_vocab, text, strlen(text),
        tokens.data(), tokens.size(), add_bos, true);
    return tokens;
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

extern "C" JNIEXPORT void JNICALL
Java_com_agent_aios_LlamaBridge_nativeInit(
        JNIEnv *env, jobject, jstring nativeLibDir) {
    if (g_initialized) return;
    const char *dir = env->GetStringUTFChars(nativeLibDir, nullptr);
    LOGI("nativeInit: loading backends from %s", dir);
    ggml_backend_load_all_from_path(dir);
    env->ReleaseStringUTFChars(nativeLibDir, dir);
    llama_backend_init();
    g_initialized = true;
    LOGI("nativeInit: backend initialized");
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_agent_aios_LlamaBridge_nativeLoadModel(
        JNIEnv *env, jobject, jstring model_path, jint context_size) {

    const char *path = env->GetStringUTFChars(model_path, nullptr);
    if (!path) return JNI_FALSE;
    LOGI("loadModel: %s (ctx=%d)", path, context_size);

    if (g_sampler) { llama_sampler_free(g_sampler); g_sampler = nullptr; }
    if (g_batch.token) { llama_batch_free(g_batch); g_batch = {}; }
    if (g_ctx) { llama_free(g_ctx); g_ctx = nullptr; }
    if (g_model) { llama_model_free(g_model); g_model = nullptr; g_vocab = nullptr; }

    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0;
    model_params.use_mmap = true;
    model_params.use_mlock = false;

    g_model = llama_model_load_from_file(path, model_params);
    env->ReleaseStringUTFChars(model_path, path);

    if (!g_model) {
        LOGE("loadModel: failed");
        return JNI_FALSE;
    }

    g_vocab = llama_model_get_vocab(g_model);

    int cpu_count = static_cast<int>(sysconf(_SC_NPROCESSORS_ONLN));
    if (cpu_count <= 0) cpu_count = 4;
    g_n_threads = std::max(2, std::min(cpu_count * 3 / 5, 8));

    int n_layers = llama_model_n_layer(g_model);
    if (n_layers <= 24) g_n_threads = std::min(g_n_threads, 4);

    g_n_ctx = context_size;

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
        return JNI_FALSE;
    }

    g_batch = llama_batch_init(BATCH_SIZE, 0, 1);
    g_sampler = create_sampler();
    g_current_pos = 0;
    g_cached_token_chars.clear();
    g_kv_tokens.clear();
    g_system_prompt_end = 0;

    LOGI("loadModel: done (ctx=%d, threads=%d, layers=%d)",
         context_size, g_n_threads, n_layers);
    return JNI_TRUE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_agent_aios_LlamaBridge_nativeFormatChat(
        JNIEnv *env, jobject, jobjectArray roles, jobjectArray contents) {

    if (!g_model) return env->NewStringUTF("");

    jsize len = env->GetArrayLength(roles);
    if (len == 0) return env->NewStringUTF("");

    std::vector<std::string> role_strings;
    std::vector<std::string> content_strings;
    role_strings.reserve(len);
    content_strings.reserve(len);

    for (jsize i = 0; i < len; i++) {
        auto *role_str = static_cast<jstring>(env->GetObjectArrayElement(roles, i));
        auto *content_str = static_cast<jstring>(env->GetObjectArrayElement(contents, i));

        if (env->ExceptionCheck()) {
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
        LOGE("formatChat: template failed");
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

    return env->NewStringUTF(std::string(buf.data(), res).c_str());
}

extern "C" JNIEXPORT jint JNICALL
Java_com_agent_aios_LlamaBridge_nativeProcessPrompt(
        JNIEnv *env, jobject, jstring prompt) {

    if (!g_ctx || !g_model || !g_vocab) return -1;

    const char *prompt_str = env->GetStringUTFChars(prompt, nullptr);
    if (!prompt_str) return -1;

    LOGI("processPrompt: %zu chars (pos=%d/%d)",
         strlen(prompt_str), (int)g_current_pos, g_n_ctx);

    g_cached_token_chars.clear();
    if (g_sampler) llama_sampler_free(g_sampler);
    g_sampler = create_sampler();

    bool add_bos = (g_current_pos == 0);
    auto tokens = tokenize(prompt_str, add_bos);
    env->ReleaseStringUTFChars(prompt, prompt_str);

    if (tokens.empty()) {
        LOGE("processPrompt: tokenization failed or empty prompt");
        return -1;
    }

    if (static_cast<int>(tokens.size()) >= g_n_ctx) {
        LOGE("processPrompt: tokens(%zu) >= ctx(%d)",
             tokens.size(), g_n_ctx);
        return -1;
    }

    for (int i = 0; i < static_cast<int>(tokens.size()); i += BATCH_SIZE) {
        int cur_size = std::min(static_cast<int>(tokens.size()) - i, BATCH_SIZE);

        if (g_current_pos + cur_size >= g_n_ctx - OVERFLOW_HEADROOM) {
            LOGW("processPrompt: context overflow approaching, shifting...");
            shift_context();
        }

        batch_clear();
        for (int j = 0; j < cur_size; j++) {
            bool want_logit = (i + j == static_cast<int>(tokens.size()) - 1);
            batch_add(tokens[i + j], g_current_pos + i + j, want_logit);
        }

        if (llama_decode(g_ctx, g_batch) != 0) {
            LOGE("processPrompt: decode failed at offset %d", i);
            return -1;
        }
    }

    g_current_pos += static_cast<llama_pos>(tokens.size());
    LOGI("processPrompt: done (pos=%d/%d, tokens=%zu)",
         (int)g_current_pos, g_n_ctx, tokens.size());
    return 0;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_agent_aios_LlamaBridge_nativeProcessPromptIncremental(
        JNIEnv *env, jobject, jstring prompt) {

    if (!g_ctx || !g_model || !g_vocab) return -1;

    const char *prompt_str = env->GetStringUTFChars(prompt, nullptr);
    if (!prompt_str) return -1;

    LOGI("processPromptInc: %zu chars (pos=%d/%d, kv_tokens=%zu)",
         strlen(prompt_str), (int)g_current_pos, g_n_ctx, g_kv_tokens.size());

    g_cached_token_chars.clear();

    bool add_bos = (g_current_pos == 0);
    auto tokens = tokenize(prompt_str, add_bos);
    env->ReleaseStringUTFChars(prompt, prompt_str);

    if (tokens.empty()) {
        LOGE("processPromptInc: tokenization failed");
        return -1;
    }

    if (static_cast<int>(tokens.size()) >= g_n_ctx) {
        LOGE("processPromptInc: tokens(%zu) >= ctx(%d)", tokens.size(), g_n_ctx);
        return -1;
    }

    if (g_kv_tokens.empty()) {
        if (!g_cached_system_kv.empty()) {
            LOGI("processPromptInc: restoring cached system prompt (%zu bytes, %zu tokens)",
                 g_cached_system_kv.size(), g_cached_system_tokens.size());
            size_t restored = llama_state_seq_set_data_ext(
                g_ctx, g_cached_system_kv.data(), g_cached_system_kv.size(), 0, 0);
            if (restored == g_cached_system_kv.size()) {
                g_kv_tokens = g_cached_system_tokens;
                g_current_pos = (llama_pos)g_kv_tokens.size();
                g_system_prompt_end = g_current_pos;
                if (g_sampler) llama_sampler_free(g_sampler);
                g_sampler = create_sampler();
                LOGI("processPromptInc: restored (pos=%d, sys_end=%d, sampler=%s)",
                     (int)g_current_pos, (int)g_system_prompt_end,
                     g_sampler ? "ok" : "NULL");
            } else {
                LOGE("processPromptInc: cache restore failed (%zu/%zu), full decode (sampler=%s)",
                     restored, g_cached_system_kv.size(),
                     g_sampler ? "ok" : "NULL");
                g_cached_system_kv.clear();
                g_cached_system_tokens.clear();
            }
        }

        if (g_kv_tokens.empty()) {
            LOGI("processPromptInc: full decode (kv empty)");
            if (g_sampler) llama_sampler_free(g_sampler);
            g_sampler = create_sampler();

            for (int i = 0; i < static_cast<int>(tokens.size()); i += BATCH_SIZE) {
                int cur_size = std::min(static_cast<int>(tokens.size()) - i, BATCH_SIZE);
                if (g_current_pos + cur_size >= g_n_ctx - OVERFLOW_HEADROOM) {
                    shift_context();
                }
                batch_clear();
                for (int j = 0; j < cur_size; j++) {
                    bool want_logit = (i + j == static_cast<int>(tokens.size()) - 1);
                    batch_add(tokens[i + j], g_current_pos + j, want_logit);
                }
                if (llama_decode(g_ctx, g_batch) != 0) {
                    LOGE("processPromptInc: decode failed at offset %d", i);
                    return -1;
                }
                g_current_pos += cur_size;
            }

            g_kv_tokens = tokens;
            g_system_prompt_end = 0;
            LOGI("processPromptInc: full done (pos=%d, kv=%zu)", (int)g_current_pos, g_kv_tokens.size());
            return 0;
        }
    }

    auto result = find_common_prefix(tokens);
    int kv_keep = result.kv_keep;
    int new_start_idx = result.new_start_idx;

    LOGI("processPromptInc: prefix kv_keep=%d, new_start=%d", kv_keep, new_start_idx);

    if (kv_keep < (int)g_kv_tokens.size()) {
        llama_memory_t mem = llama_get_memory(g_ctx);
        llama_memory_seq_rm(mem, 0, kv_keep, g_current_pos);
        g_current_pos = kv_keep;
        g_kv_tokens.resize(kv_keep);
        if (g_system_prompt_end > 0 && kv_keep < (int)g_system_prompt_end) {
            LOGW("processPromptInc: system_prompt_end reset (%d > kv_keep=%d)",
                 (int)g_system_prompt_end, kv_keep);
            g_system_prompt_end = 0;
        }
    }

    int delta = (int)tokens.size() - new_start_idx;
    if (delta <= 0) {
        LOGI("processPromptInc: no new tokens");
        return 0;
    }

    LOGI("processPromptInc: decoding %d new tokens (pos=%d)", delta, (int)g_current_pos);

    for (int i = 0; i < delta; i += BATCH_SIZE) {
        int cur_size = std::min(delta - i, BATCH_SIZE);
        if (g_current_pos + cur_size >= g_n_ctx - OVERFLOW_HEADROOM) {
            shift_context();
        }
        batch_clear();
        for (int j = 0; j < cur_size; j++) {
            bool want_logit = (i + j == delta - 1);
            batch_add(tokens[new_start_idx + i + j], g_current_pos + j, want_logit);
        }
        if (llama_decode(g_ctx, g_batch) != 0) {
            LOGE("processPromptInc: decode failed at offset %d", i);
            return -1;
        }
        g_current_pos += cur_size;
    }

    g_kv_tokens.insert(g_kv_tokens.end(),
                       tokens.begin() + new_start_idx, tokens.end());

    LOGI("processPromptInc: done (pos=%d/%d, kv=%zu, delta=%d)",
         (int)g_current_pos, g_n_ctx, g_kv_tokens.size(), delta);
    return 0;
}

extern "C" JNIEXPORT void JNICALL
Java_com_agent_aios_LlamaBridge_nativeSetSystemPromptPosition(JNIEnv *, jobject) {
    if (g_system_prompt_end == 0) {
        g_system_prompt_end = g_current_pos;
        LOGI("system_prompt_end set to %d", (int)g_system_prompt_end);
    }
}

extern "C" JNIEXPORT jint JNICALL
Java_com_agent_aios_LlamaBridge_nativeProcessSystemPrompt(
        JNIEnv *env, jobject, jstring prompt) {

    if (!g_ctx || !g_model || !g_vocab) return -1;

    const char *prompt_str = env->GetStringUTFChars(prompt, nullptr);
    if (!prompt_str) return -1;

    LOGI("processSystemPrompt: %zu chars (pos=%d/%d)",
         strlen(prompt_str), (int)g_current_pos, g_n_ctx);

    if (!g_cached_system_kv.empty()) {
        LOGI("processSystemPrompt: already cached (%zu bytes)", g_cached_system_kv.size());
        env->ReleaseStringUTFChars(prompt, prompt_str);
        return 0;
    }

    g_cached_token_chars.clear();
    if (g_sampler) llama_sampler_free(g_sampler);
    g_sampler = create_sampler();

    bool add_bos = (g_current_pos == 0);
    auto tokens = tokenize(prompt_str, add_bos);
    env->ReleaseStringUTFChars(prompt, prompt_str);

    if (tokens.empty()) {
        LOGE("processSystemPrompt: tokenization failed");
        return -1;
    }

    if (static_cast<int>(tokens.size()) >= g_n_ctx) {
        LOGE("processSystemPrompt: tokens(%zu) >= ctx(%d)", tokens.size(), g_n_ctx);
        return -1;
    }

    for (int i = 0; i < static_cast<int>(tokens.size()); i += BATCH_SIZE) {
        int cur_size = std::min(static_cast<int>(tokens.size()) - i, BATCH_SIZE);
        if (g_current_pos + cur_size >= g_n_ctx - OVERFLOW_HEADROOM) {
            shift_context();
        }
        batch_clear();
        for (int j = 0; j < cur_size; j++) {
            bool want_logit = (i + j == static_cast<int>(tokens.size()) - 1);
            batch_add(tokens[i + j], g_current_pos + j, want_logit);
        }
        if (llama_decode(g_ctx, g_batch) != 0) {
            LOGE("processSystemPrompt: decode failed at offset %d", i);
            return -1;
        }
        g_current_pos += cur_size;
    }

    g_kv_tokens = tokens;
    g_system_prompt_end = g_current_pos;

    size_t kv_size = llama_state_seq_get_size_ext(g_ctx, 0, 0);
    if (kv_size > 0) {
        g_cached_system_kv.resize(kv_size);
        size_t written = llama_state_seq_get_data_ext(
            g_ctx, g_cached_system_kv.data(), kv_size, 0, 0);
        if (written == kv_size) {
            g_cached_system_tokens = g_kv_tokens;
            LOGI("processSystemPrompt: cached %zu bytes (%zu tokens)",
                 kv_size, g_cached_system_tokens.size());
        } else {
            LOGE("processSystemPrompt: KV serialize failed (wrote %zu/%zu)", written, kv_size);
            g_cached_system_kv.clear();
        }
    }

    llama_memory_t mem = llama_get_memory(g_ctx);
    llama_memory_clear(mem, false);
    g_current_pos = 0;
    g_kv_tokens.clear();
    g_system_prompt_end = 0;
    if (g_sampler) { llama_sampler_free(g_sampler); g_sampler = nullptr; }

    return 0;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_agent_aios_LlamaBridge_nativeGenerateOneToken(
        JNIEnv *env, jobject) {

    if (!g_ctx || !g_model || !g_vocab) return nullptr;
    if (!g_sampler) {
        LOGW("generateOneToken: g_sampler null, recreating...");
        g_sampler = create_sampler();
        if (!g_sampler) return nullptr;
    }

    if (g_current_pos >= g_n_ctx - OVERFLOW_HEADROOM) {
        LOGW("generateOneToken: context full, shifting...");
        shift_context();
    }

    llama_token new_token = llama_sampler_sample(g_sampler, g_ctx, -1);

    if (llama_vocab_is_eog(g_vocab, new_token)) {
        LOGI("generateOneToken: EOG token %d", new_token);
        return nullptr;
    }

    batch_clear();
    batch_add(new_token, g_current_pos, true);
    if (llama_decode(g_ctx, g_batch) != 0) {
        LOGE("generateOneToken: decode failed");
        return nullptr;
    }
    g_current_pos++;
    g_kv_tokens.push_back(new_token);

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
Java_com_agent_aios_LlamaBridge_nativeReleaseModel(
        JNIEnv *, jobject) {
    g_current_pos = 0;
    g_cached_token_chars.clear();
    g_kv_tokens.clear();
    g_system_prompt_end = 0;
    g_cached_system_kv.clear();
    g_cached_system_kv.shrink_to_fit();
    g_cached_system_tokens.clear();
    if (g_sampler) { llama_sampler_free(g_sampler); g_sampler = nullptr; }
    if (g_batch.token) { llama_batch_free(g_batch); g_batch = {}; }
    if (g_ctx) { llama_free(g_ctx); g_ctx = nullptr; }
    if (g_model) { llama_model_free(g_model); g_model = nullptr; g_vocab = nullptr; }
    LOGI("Model released");
}

extern "C" JNIEXPORT void JNICALL
Java_com_agent_aios_LlamaBridge_nativeResetContext(
        JNIEnv *, jobject) {
    if (g_ctx) {
        llama_memory_clear(llama_get_memory(g_ctx), false);
    }
    g_current_pos = 0;
    g_cached_token_chars.clear();
    g_kv_tokens.clear();
    g_system_prompt_end = 0;
    LOGI("Context reset (kv_tokens cleared)");
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_agent_aios_LlamaBridge_nativeIsModelLoaded(
        JNIEnv *, jobject) {
    return (g_model != nullptr && g_ctx != nullptr) ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_agent_aios_LlamaBridge_nativeGetModelInfo(
        JNIEnv *env, jobject) {
    if (!g_model) return env->NewStringUTF("No model loaded");

    char info[512];
    snprintf(info, sizeof(info),
             "n_ctx_train=%d, n_embd=%d, n_layer=%d, threads=%d, ctx=%d",
             llama_model_n_ctx_train(g_model),
             llama_model_n_embd(g_model),
             llama_model_n_layer(g_model),
             g_n_threads, g_n_ctx);
    return env->NewStringUTF(info);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_agent_aios_LlamaBridge_nativeGetContextUsage(
        JNIEnv *env, jobject) {
    char usage[64];
    snprintf(usage, sizeof(usage), "%d/%d", (int)g_current_pos, g_n_ctx);
    return env->NewStringUTF(usage);
}

extern "C" JNIEXPORT void JNICALL
Java_com_agent_aios_LlamaBridge_nativeSetSamplingParams(
        JNIEnv *, jobject, jfloat temperature, jint top_k, jfloat top_p, jfloat repeat_penalty) {
    g_temperature = temperature;
    g_top_k = top_k;
    g_top_p = top_p;
    g_repeat_penalty = repeat_penalty;
}
