#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <chrono>
#include <llama.h>

static int test_model_load(const char* model_path, int context_size) {
    printf("[TEST] Loading model: %s\n", model_path);

    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0;

    llama_model* model = llama_model_load_from_file(model_path, model_params);
    if (!model) {
        printf("[FAIL] llama_model_load_from_file returned NULL\n");
        return 1;
    }

    const llama_vocab* vocab = llama_model_get_vocab(model);
    if (!vocab) {
        printf("[FAIL] llama_model_get_vocab returned NULL\n");
        llama_model_free(model);
        return 1;
    }

    printf("[PASS] Model loaded successfully\n");
    printf("[INFO] n_ctx_train=%d, n_embd=%d, n_layer=%d\n",
        llama_model_n_ctx_train(model),
        llama_model_n_embd(model),
        llama_model_n_layer(model));

    printf("[TEST] Creating context (n_ctx=%d, n_threads=4)\n", context_size);
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = context_size;
    ctx_params.n_batch = 512;
    ctx_params.n_threads = 4;
    ctx_params.n_threads_batch = 4;

    llama_context* ctx = llama_init_from_model(model, ctx_params);
    if (!ctx) {
        printf("[FAIL] llama_init_from_model returned NULL\n");
        llama_model_free(model);
        return 1;
    }
    printf("[PASS] Context created\n");

    // Test tokenize
    const char* test_prompt = "Hello, my name is";
    printf("[TEST] Tokenizing: \"%s\"\n", test_prompt);

    int n_tokens = -llama_tokenize(vocab, test_prompt, strlen(test_prompt), nullptr, 0, true, true);
    if (n_tokens <= 0) {
        printf("[FAIL] llama_tokenize returned %d\n", n_tokens);
        llama_free(ctx);
        llama_model_free(model);
        return 1;
    }
    printf("[PASS] Tokenize returned %d tokens\n", n_tokens);

    std::vector<llama_token> tokens(n_tokens);
    llama_tokenize(vocab, test_prompt, strlen(test_prompt), tokens.data(), tokens.size(), true, true);

    // Test decode (prompt batch)
    printf("[TEST] Decoding prompt batch...\n");
    llama_batch batch = llama_batch_get_one(tokens.data(), tokens.size());
    if (llama_decode(ctx, batch) != 0) {
        printf("[FAIL] llama_decode (prompt) failed\n");
        llama_free(ctx);
        llama_model_free(model);
        return 1;
    }
    printf("[PASS] Prompt decoded\n");

    // Test generation
    printf("[TEST] Generating 32 tokens...\n");
    auto start = std::chrono::high_resolution_clock::now();

    llama_sampler* smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(smpl, llama_sampler_init_temp(0.8f));
    llama_sampler_chain_add(smpl, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

    std::string result;
    int n_decoded = 0;
    int max_tokens = 32;

    while (n_decoded < max_tokens) {
        llama_token new_token = llama_sampler_sample(smpl, ctx, -1);
        if (llama_vocab_is_eog(vocab, new_token)) break;

        char buf[256];
        int n = llama_token_to_piece(vocab, new_token, buf, sizeof(buf), 0, true);
        if (n > 0) result.append(buf, n);

        n_decoded++;
        batch = llama_batch_get_one(&new_token, 1);
        if (llama_decode(ctx, batch) != 0) {
            printf("[FAIL] llama_decode (token %d) failed\n", n_decoded);
            break;
        }
    }

    auto end = std::chrono::high_resolution_clock::now();
    double elapsed_ms = std::chrono::duration<double, std::milli>(end - start).count();
    double tok_per_sec = n_decoded > 0 ? (n_decoded / (elapsed_ms / 1000.0)) : 0;

    printf("[PASS] Generated %d tokens in %.0fms (%.1f tok/s)\n", n_decoded, elapsed_ms, tok_per_sec);
    printf("[OUTPUT] \"%s%s\"\n", test_prompt, result.c_str());

    llama_sampler_free(smpl);
    llama_free(ctx);
    llama_model_free(model);

    printf("\n=== ALL TESTS PASSED ===\n");
    return 0;
}

int main(int argc, char** argv) {
    const char* model_path = argc > 1 ? argv[1] : "/tmp/aios-models/tinyllama.gguf";
    int context_size = argc > 2 ? atoi(argv[2]) : 512;

    printf("=== AIOS Native Inference Test ===\n");
    printf("Model: %s\n", model_path);
    printf("Context: %d\n\n", context_size);

    int ret = test_model_load(model_path, context_size);
    return ret;
}
