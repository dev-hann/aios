#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <cassert>
#include <chrono>
#include <llama.h>
#include <ggml-backend.h>

static int g_tests_run = 0;
static int g_tests_passed = 0;
static int g_tests_failed = 0;

#define TEST(name) \
    do { \
        g_tests_run++; \
        printf("  [TEST] %s ... ", name); \
    } while(0)

#define PASS() \
    do { \
        g_tests_passed++; \
        printf("PASS\n"); \
    } while(0)

#define FAIL(msg) \
    do { \
        g_tests_failed++; \
        printf("FAIL: %s\n", msg); \
    } while(0)

#define ASSERT_TRUE(cond, msg) \
    do { if (!(cond)) { FAIL(msg); return; } } while(0)

#define ASSERT_EQ(a, b, msg) \
    do { if ((a) != (b)) { printf("FAIL: %s (got %d, expected %d)\n", msg, (int)(a), (int)(b)); g_tests_failed++; return; } } while(0)

// === Helper functions from native-lib.cpp ===

constexpr int BATCH_SIZE = 512;
constexpr int OVERFLOW_HEADROOM = 4;

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

static std::vector<llama_token> tokenize(const llama_vocab *vocab, const char *text, bool add_bos) {
    if (!vocab || !text || strlen(text) == 0) return {};
    const int n_tokens = -llama_tokenize(vocab, text, strlen(text), nullptr, 0, add_bos, true);
    if (n_tokens <= 0) return {};
    std::vector<llama_token> tokens(n_tokens);
    llama_tokenize(vocab, text, strlen(text), tokens.data(), tokens.size(), add_bos, true);
    return tokens;
}

struct TestState {
    llama_model *model = nullptr;
    llama_context *ctx = nullptr;
    const llama_vocab *vocab = nullptr;
    llama_batch batch = {};
    llama_sampler *sampler = nullptr;
    llama_pos current_pos = 0;
    int n_ctx = 0;
    std::string cached_token_chars;
};

static void batch_clear(llama_batch &b) { b.n_tokens = 0; }

static void batch_add(llama_batch &b, llama_token id, llama_pos pos, bool logits) {
    int i = b.n_tokens;
    b.token[i] = id;
    b.pos[i] = pos;
    b.n_seq_id[i] = 1;
    b.seq_id[i][0] = 0;
    b.logits[i] = logits;
    b.n_tokens++;
}

static void shift_context(llama_context *ctx, llama_pos &current_pos) {
    const int n_discard = current_pos / 2;
    if (n_discard <= 0) return;
    llama_memory_t mem = llama_get_memory(ctx);
    llama_memory_seq_rm(mem, 0, 0, n_discard);
    llama_memory_seq_add(mem, 0, n_discard, current_pos, -n_discard);
    current_pos -= n_discard;
}

static bool decode_tokens_in_batches(
        llama_context *ctx, llama_batch &batch,
        const std::vector<llama_token> &tokens,
        llama_pos &current_pos, int n_ctx) {
    if (tokens.empty()) return true;
    for (int i = 0; i < (int)tokens.size(); i += BATCH_SIZE) {
        int cur_size = std::min((int)tokens.size() - i, BATCH_SIZE);
        if (current_pos + cur_size >= n_ctx - OVERFLOW_HEADROOM) {
            shift_context(ctx, current_pos);
        }
        batch_clear(batch);
        for (int j = 0; j < cur_size; j++) {
            bool want_logit = (i + j == (int)tokens.size() - 1);
            batch_add(batch, tokens[i + j], current_pos + i + j, want_logit);
        }
        if (llama_decode(ctx, batch) != 0) return false;
    }
    return true;
}

static llama_sampler *create_sampler() {
    llama_sampler *smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(smpl, llama_sampler_init_temp(0.7f));
    llama_sampler_chain_add(smpl, llama_sampler_init_top_k(40));
    llama_sampler_chain_add(smpl, llama_sampler_init_top_p(0.9f, 1));
    llama_sampler_chain_add(smpl, llama_sampler_init_penalties(64, 0.0f, 1.1f, 0.0f));
    llama_sampler_chain_add(smpl, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
    return smpl;
}

static void cleanup(TestState &s) {
    if (s.sampler) { llama_sampler_free(s.sampler); s.sampler = nullptr; }
    if (s.batch.token) { llama_batch_free(s.batch); s.batch = {}; }
    if (s.ctx) { llama_free(s.ctx); s.ctx = nullptr; }
    if (s.model) { llama_model_free(s.model); s.model = nullptr; }
    s.vocab = nullptr;
    s.current_pos = 0;
}

static bool init_test_state(TestState &s, const char *model_path, int context_size) {
    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0;
    model_params.use_mmap = true;

    s.model = llama_model_load_from_file(model_path, model_params);
    if (!s.model) return false;

    s.vocab = llama_model_get_vocab(s.model);

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = context_size;
    ctx_params.n_batch = BATCH_SIZE;
    ctx_params.n_ubatch = BATCH_SIZE;
    ctx_params.n_threads = 4;
    ctx_params.n_threads_batch = 4;

    s.ctx = llama_init_from_model(s.model, ctx_params);
    if (!s.ctx) { cleanup(s); return false; }

    s.batch = llama_batch_init(BATCH_SIZE, 0, 1);
    s.n_ctx = context_size;
    s.sampler = create_sampler();
    return true;
}

// === Tests without model ===

static void test_is_valid_utf8_ascii() {
    TEST("is_valid_utf8: ASCII");
    ASSERT_TRUE(is_valid_utf8("Hello, world!"), "ASCII should be valid");
    PASS();
}

static void test_is_valid_utf8_korean() {
    TEST("is_valid_utf8: Korean");
    ASSERT_TRUE(is_valid_utf8("안녕하세요"), "Korean should be valid");
    PASS();
}

static void test_is_valid_utf8_emoji() {
    TEST("is_valid_utf8: emoji (4-byte)");
    ASSERT_TRUE(is_valid_utf8("🎉🚀"), "emoji should be valid");
    PASS();
}

static void test_is_valid_utf8_empty() {
    TEST("is_valid_utf8: empty string");
    ASSERT_TRUE(is_valid_utf8(""), "empty should be valid");
    PASS();
}

static void test_is_valid_utf8_null() {
    TEST("is_valid_utf8: null pointer");
    ASSERT_TRUE(is_valid_utf8(nullptr), "null should be valid");
    PASS();
}

static void test_is_valid_utf8_mixed() {
    TEST("is_valid_utf8: mixed scripts");
    ASSERT_TRUE(is_valid_utf8("Hello안녕🎉"), "mixed should be valid");
    PASS();
}

static void test_batch_init_and_add() {
    TEST("batch: init + add + clear");
    llama_batch b = llama_batch_init(64, 0, 1);
    ASSERT_TRUE(b.token != nullptr, "batch token array should be allocated");

    batch_clear(b);
    ASSERT_EQ(b.n_tokens, 0, "batch should be empty after clear");

    batch_add(b, 1, 0, false);
    batch_add(b, 2, 1, false);
    batch_add(b, 3, 2, true);
    ASSERT_EQ(b.n_tokens, 3, "batch should have 3 tokens");
    ASSERT_EQ(b.token[0], 1, "first token should be 1");
    ASSERT_EQ(b.token[2], 3, "third token should be 3");
    ASSERT_EQ(b.logits[2], true, "last token should have logits");
    ASSERT_EQ(b.logits[0], false, "first token should not have logits");

    batch_clear(b);
    ASSERT_EQ(b.n_tokens, 0, "batch should be empty after clear");

    llama_batch_free(b);
    PASS();
}

// === Tests with model ===

static void test_tokenize_basic(TestState &s) {
    TEST("tokenize: basic prompt");
    auto tokens = tokenize(s.vocab, "Hello, my name is", true);
    ASSERT_TRUE(!tokens.empty(), "should return tokens");
    ASSERT_TRUE(tokens.size() > 3, "should have multiple tokens");
    printf("PASS (%zu tokens)\n", tokens.size());
    g_tests_passed++;
}

static void test_tokenize_empty(TestState &s) {
    TEST("tokenize: empty string");
    auto tokens = tokenize(s.vocab, "", true);
    ASSERT_TRUE(tokens.empty(), "empty string should return no tokens");
    PASS();
}

static void test_tokenize_korean(TestState &s) {
    TEST("tokenize: Korean text");
    auto tokens = tokenize(s.vocab, "안녕하세요", true);
    ASSERT_TRUE(!tokens.empty(), "Korean should tokenize");
    printf("PASS (%zu tokens)\n", tokens.size());
    g_tests_passed++;
}

static void test_tokenize_no_bos(TestState &s) {
    TEST("tokenize: without BOS");
    auto with_bos = tokenize(s.vocab, "Hello", true);
    auto no_bos = tokenize(s.vocab, "Hello", false);
    ASSERT_TRUE(with_bos.size() >= no_bos.size(), "with BOS should have >= tokens");
    PASS();
}

static void test_decode_prompt(TestState &s) {
    TEST("decode: prompt in batches");
    auto tokens = tokenize(s.vocab, "Hello, world!", true);
    ASSERT_TRUE(!tokens.empty(), "tokenize should succeed");

    bool ok = decode_tokens_in_batches(s.ctx, s.batch, tokens, s.current_pos, s.n_ctx);
    ASSERT_TRUE(ok, "decode should succeed");

    s.current_pos += (llama_pos)tokens.size();
    ASSERT_TRUE(s.current_pos > 0, "position should advance");
    printf("PASS (pos=%d)\n", (int)s.current_pos);
    g_tests_passed++;
}

static void test_generate_one_token(TestState &s) {
    TEST("generate: one token");

    s.current_pos = 0;
    llama_memory_clear(llama_get_memory(s.ctx), false);
    if (s.sampler) llama_sampler_free(s.sampler);
    s.sampler = create_sampler();

    auto tokens = tokenize(s.vocab, "Say hello", true);
    bool ok = decode_tokens_in_batches(s.ctx, s.batch, tokens, s.current_pos, s.n_ctx);
    ASSERT_TRUE(ok, "decode prompt should succeed");
    s.current_pos += (llama_pos)tokens.size();

    llama_token new_token = llama_sampler_sample(s.sampler, s.ctx, -1);
    ASSERT_TRUE(!llama_vocab_is_eog(s.vocab, new_token), "should not be EOG immediately");

    char buf[256];
    int n = llama_token_to_piece(s.vocab, new_token, buf, sizeof(buf), 0, true);
    ASSERT_TRUE(n > 0, "token should convert to text");

    batch_clear(s.batch);
    batch_add(s.batch, new_token, s.current_pos, true);
    int dec_result = llama_decode(s.ctx, s.batch);
    ASSERT_EQ(dec_result, 0, "decode generated token should succeed");
    s.current_pos++;

    printf("PASS (token_id=%d, text='%.*s')\n", new_token, n, buf);
    g_tests_passed++;
}

static void test_generate_loop(TestState &s) {
    TEST("generate: loop until EOG or max_tokens");

    s.current_pos = 0;
    llama_memory_clear(llama_get_memory(s.ctx), false);
    if (s.sampler) llama_sampler_free(s.sampler);
    s.sampler = create_sampler();
    s.cached_token_chars.clear();

    auto tokens = tokenize(s.vocab, "Say hi", true);
    bool ok = decode_tokens_in_batches(s.ctx, s.batch, tokens, s.current_pos, s.n_ctx);
    ASSERT_TRUE(ok, "decode prompt should succeed");
    s.current_pos += (llama_pos)tokens.size();

    std::string result;
    int generated = 0;
    int max_tokens = 64;

    while (generated < max_tokens) {
        llama_token new_token = llama_sampler_sample(s.sampler, s.ctx, -1);
        if (llama_vocab_is_eog(s.vocab, new_token)) break;

        char buf[256];
        int n = llama_token_to_piece(s.vocab, new_token, buf, sizeof(buf), 0, true);
        if (n > 0) {
            std::string token_str(buf, n);
            s.cached_token_chars += token_str;

            if (is_valid_utf8(s.cached_token_chars.c_str())) {
                result += s.cached_token_chars;
                s.cached_token_chars.clear();
            }
        }

        batch_clear(s.batch);
        batch_add(s.batch, new_token, s.current_pos, true);
        if (llama_decode(s.ctx, s.batch) != 0) break;
        s.current_pos++;
        generated++;
    }

    ASSERT_TRUE(generated > 0, "should generate at least 1 token");
    ASSERT_TRUE(!result.empty(), "should produce text");
    printf("PASS (%d tokens, %zu chars: \"%s\")\n", generated, result.size(),
           result.substr(0, 60).c_str());
    g_tests_passed++;
}

static void test_processPrompt_then_generate(TestState &s) {
    TEST("full pipeline: processPrompt + generateOneToken loop");

    s.current_pos = 0;
    llama_memory_clear(llama_get_memory(s.ctx), false);
    if (s.sampler) llama_sampler_free(s.sampler);
    s.sampler = create_sampler();
    s.cached_token_chars.clear();

    // processPrompt
    auto tokens = tokenize(s.vocab, "What is 2+2? Answer briefly.", true);
    ASSERT_TRUE(!tokens.empty(), "tokenize should succeed");
    bool ok = decode_tokens_in_batches(s.ctx, s.batch, tokens, s.current_pos, s.n_ctx);
    ASSERT_TRUE(ok, "processPrompt should succeed");
    s.current_pos += (llama_pos)tokens.size();
    int pos_after_prompt = s.current_pos;

    // generateOneToken loop
    std::string result;
    int generated = 0;
    while (generated < 128) {
        if (s.current_pos >= s.n_ctx - OVERFLOW_HEADROOM) {
            shift_context(s.ctx, s.current_pos);
        }

        llama_token new_token = llama_sampler_sample(s.sampler, s.ctx, -1);
        if (llama_vocab_is_eog(s.vocab, new_token)) break;

        batch_clear(s.batch);
        batch_add(s.batch, new_token, s.current_pos, true);
        if (llama_decode(s.ctx, s.batch) != 0) break;
        s.current_pos++;

        char buf[256];
        int n = llama_token_to_piece(s.vocab, new_token, buf, sizeof(buf), 0, true);
        if (n > 0) result.append(buf, n);

        generated++;
    }

    ASSERT_TRUE(generated > 0, "should generate tokens");
    ASSERT_TRUE(s.current_pos > pos_after_prompt, "position should advance past prompt");
    printf("PASS (%d tokens, %zu chars)\n", generated, result.size());
    g_tests_passed++;
}

static void test_context_reset(TestState &s) {
    TEST("context reset: clears KV cache");

    auto tokens = tokenize(s.vocab, "Hello", true);
    decode_tokens_in_batches(s.ctx, s.batch, tokens, s.current_pos, s.n_ctx);
    s.current_pos += (llama_pos)tokens.size();
    ASSERT_TRUE(s.current_pos > 0, "position should be > 0 after decode");

    llama_memory_clear(llama_get_memory(s.ctx), false);
    s.current_pos = 0;
    ASSERT_EQ(s.current_pos, 0, "position should be 0 after reset");

    auto tokens2 = tokenize(s.vocab, "World", true);
    bool ok = decode_tokens_in_batches(s.ctx, s.batch, tokens2, s.current_pos, s.n_ctx);
    ASSERT_TRUE(ok, "should decode after reset");
    s.current_pos += (llama_pos)tokens2.size();

    printf("PASS (new pos=%d)\n", (int)s.current_pos);
    g_tests_passed++;
}

static void test_chat_template(TestState &s) {
    TEST("chat template: format messages");

    std::vector<llama_chat_message> messages = {
        {"system", "You are helpful."},
        {"user", "Hello"}
    };

    std::vector<char> buf(4096);
    int32_t res = llama_chat_apply_template(
        nullptr, messages.data(), (int32_t)messages.size(),
        true, buf.data(), (int32_t)buf.size());

    ASSERT_TRUE(res > 0, "template should produce output");
    std::string formatted(buf.data(), res);
    ASSERT_TRUE(!formatted.empty(), "formatted should not be empty");
    printf("PASS (%d chars)\n", res);
    g_tests_passed++;
}

static void test_sampler_creation() {
    TEST("sampler: create and free");
    llama_sampler *smpl = create_sampler();
    ASSERT_TRUE(smpl != nullptr, "sampler should be created");
    llama_sampler_free(smpl);
    PASS();
}

static void test_model_info(TestState &s) {
    TEST("model info: basic properties");
    ASSERT_TRUE(s.model != nullptr, "model should exist");
    int n_ctx_train = llama_model_n_ctx_train(s.model);
    int n_embd = llama_model_n_embd(s.model);
    int n_layer = llama_model_n_layer(s.model);
    ASSERT_TRUE(n_ctx_train > 0, "n_ctx_train should be > 0");
    ASSERT_TRUE(n_embd > 0, "n_embd should be > 0");
    ASSERT_TRUE(n_layer > 0, "n_layer should be > 0");
    printf("PASS (ctx_train=%d, embd=%d, layers=%d)\n", n_ctx_train, n_embd, n_layer);
    g_tests_passed++;
}

static void test_context_usage(TestState &s) {
    TEST("context usage: tracking");
    ASSERT_EQ(s.current_pos, 0, "should start at 0");

    auto tokens = tokenize(s.vocab, "Test prompt for context tracking", true);
    decode_tokens_in_batches(s.ctx, s.batch, tokens, s.current_pos, s.n_ctx);
    s.current_pos += (llama_pos)tokens.size();

    float ratio = (float)s.current_pos / (float)s.n_ctx;
    ASSERT_TRUE(ratio >= 0.0f && ratio <= 1.0f, "usage ratio should be 0..1");
    printf("PASS (%d/%d = %.1f%%)\n", (int)s.current_pos, s.n_ctx, ratio * 100);
    g_tests_passed++;
}

static void test_utf8_caching_during_generation(TestState &s) {
    TEST("UTF-8 caching: multi-byte chars during generation");

    s.current_pos = 0;
    llama_memory_clear(llama_get_memory(s.ctx), false);
    if (s.sampler) llama_sampler_free(s.sampler);
    s.sampler = create_sampler();
    s.cached_token_chars.clear();

    auto tokens = tokenize(s.vocab, "Say hello in Korean.", true);
    decode_tokens_in_batches(s.ctx, s.batch, tokens, s.current_pos, s.n_ctx);
    s.current_pos += (llama_pos)tokens.size();

    int valid_count = 0;
    int empty_cache_count = 0;
    int generated = 0;

    while (generated < 64) {
        llama_token new_token = llama_sampler_sample(s.sampler, s.ctx, -1);
        if (llama_vocab_is_eog(s.vocab, new_token)) break;

        char buf[256];
        int n = llama_token_to_piece(s.vocab, new_token, buf, sizeof(buf), 0, true);
        if (n > 0) {
            s.cached_token_chars += std::string(buf, n);
            if (is_valid_utf8(s.cached_token_chars.c_str())) {
                if (!s.cached_token_chars.empty()) valid_count++;
                s.cached_token_chars.clear();
            } else {
                empty_cache_count++;
            }
        }

        batch_clear(s.batch);
        batch_add(s.batch, new_token, s.current_pos, true);
        if (llama_decode(s.ctx, s.batch) != 0) break;
        s.current_pos++;
        generated++;
    }

    ASSERT_TRUE(s.cached_token_chars.empty(), "cache should be empty at end");
    printf("PASS (valid=%d, cached=%d, total=%d)\n", valid_count, empty_cache_count, generated);
    g_tests_passed++;
}

// === Main ===

int main(int argc, char **argv) {
    const char *model_path = argc > 1 ? argv[1] : nullptr;

    printf("=== AIOS JNI Logic Tests ===\n\n");

    // --- Tests without model ---
    printf("[Phase 1] Pure logic tests (no model)\n");
    test_is_valid_utf8_ascii();
    test_is_valid_utf8_korean();
    test_is_valid_utf8_emoji();
    test_is_valid_utf8_empty();
    test_is_valid_utf8_null();
    test_is_valid_utf8_mixed();
    test_batch_init_and_add();
    test_sampler_creation();

    if (!model_path) {
        printf("\n[SKIP] Model-dependent tests (no model path provided)\n");
        printf("  Usage: %s <model.gguf> [context_size]\n", argv[0]);
        printf("\n=== Results: %d/%d passed, %d failed, %d skipped ===\n",
               g_tests_passed, g_tests_run, g_tests_failed, 0);
        return g_tests_failed > 0 ? 1 : 0;
    }

    int context_size = argc > 2 ? atoi(argv[2]) : 512;
    printf("\n[Phase 2] Model-dependent tests (model=%s, ctx=%d)\n", model_path, context_size);

    llama_backend_init();

    // Model load test
    {
        TEST("model load");
        llama_model_params mp = llama_model_default_params();
        mp.n_gpu_layers = 0;
        llama_model *m = llama_model_load_from_file(model_path, mp);
        if (!m) { FAIL("failed to load model"); return 1; }
        llama_model_free(m);
        PASS();
    }

    TestState state;
    if (!init_test_state(state, model_path, context_size)) {
        FAIL("failed to init test state");
        return 1;
    }

    test_model_info(state);
    test_context_usage(state);
    test_tokenize_basic(state);
    test_tokenize_empty(state);
    test_tokenize_korean(state);
    test_tokenize_no_bos(state);
    test_chat_template(state);
    test_decode_prompt(state);
    test_generate_one_token(state);
    test_generate_loop(state);
    test_context_reset(state);
    test_processPrompt_then_generate(state);
    test_utf8_caching_during_generation(state);

    cleanup(state);
    llama_backend_free();

    printf("\n=== Results: %d/%d passed, %d failed ===\n",
           g_tests_passed, g_tests_run, g_tests_failed);

    return g_tests_failed > 0 ? 1 : 0;
}
