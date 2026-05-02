# Test Models

This directory stores GGUF model files used by C++ unit tests.

Files here are gitignored — use `download_test_model.sh` to fetch them.

## Quick Start

```bash
# 1. Download test model (~396MB, one-time)
cd native/tests
./download_test_model.sh

# 2. Build and run tests
mkdir -p build && cd build
cmake .. && make -j$(nproc) test_jni_logic
./test_jni_logic ../models/qwen2.5-0.5b-instruct-q2_k.gguf

# 3. Without model (pure logic tests only)
./test_jni_logic
```

## Model Info

| File | Source | Size | Purpose |
|------|--------|------|---------|
| qwen2.5-0.5b-instruct-q2_k.gguf | [Qwen2.5-0.5B-Instruct-GGUF](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF) | ~396MB | C++ inference tests |

## Tests Coverage

- Phase 1 (no model): is_valid_utf8, batch ops, sampler — 8 tests
- Phase 2 (with model): tokenize, decode, generate, context reset, pipeline, UTF-8 caching — 14 tests
