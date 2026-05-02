#!/bin/bash
set -e

MODEL_DIR="$(cd "$(dirname "$0")" && pwd)/models"
mkdir -p "$MODEL_DIR"

MODEL_FILE="$MODEL_DIR/qwen2.5-0.5b-instruct-q2_k.gguf"
MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q2_k.gguf"

if [ -f "$MODEL_FILE" ]; then
    SIZE=$(stat -c%s "$MODEL_FILE" 2>/dev/null || stat -f%z "$MODEL_FILE" 2>/dev/null)
    if [ "$SIZE" -gt 100000000 ]; then
        echo "Test model already exists: $MODEL_FILE ($(echo "scale=0; $SIZE/1048576" | bc)MB)"
        exit 0
    fi
    echo "Existing file too small, re-downloading..."
    rm -f "$MODEL_FILE"
fi

echo "Downloading Qwen2.5-0.5B-Instruct Q2_K (~396MB)..."
echo "  URL: $MODEL_URL"
echo "  Target: $MODEL_FILE"

wget --progress=bar:force:noscroll -O "$MODEL_FILE" "$MODEL_URL"

echo ""
echo "Download complete: $(echo "scale=0; $(stat -c%s "$MODEL_FILE")/1048576" | bc)MB"
echo ""
echo "Run tests:"
echo "  cd native/tests && mkdir -p build && cd build"
echo "  cmake .. && make -j\$(nproc) test_jni_logic"
echo "  ./test_jni_logic ../models/qwen2.5-0.5b-instruct-q2_k.gguf"
