#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

UNIT_RESULT=0
INTG_RESULT=0
INTG_STATUS="skipped"
DART_DEFINES=""

_resolve_dart_defines() {
  local env_file="${1:-}"
  if [ ! -f "$env_file" ]; then
    echo -e "${YELLOW}[INFO]${NC} No .env.test found. LLM integration tests will be skipped."
    return
  fi

  local api_key model base_url provider_type
  api_key=""
  model=""
  base_url=""
  provider_type=""

  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    value="${value# }"
    case "$key" in
      TEST_API_KEY)       api_key="$value" ;;
      TEST_MODEL)         model="$value" ;;
      TEST_BASE_URL)      base_url="$value" ;;
      TEST_PROVIDER_TYPE) provider_type="$value" ;;
    esac
  done < "$env_file"

  if [ -z "$api_key" ]; then
    echo -e "${YELLOW}[INFO]${NC} TEST_API_KEY is empty. LLM integration tests will be skipped."
    return
  fi

  DART_DEFINES="--dart-define=TEST_API_KEY=$api_key"
  if [ -n "$model" ]; then
    DART_DEFINES="$DART_DEFINES --dart-define=TEST_MODEL=$model"
  fi
  if [ -n "$base_url" ]; then
    DART_DEFINES="$DART_DEFINES --dart-define=TEST_BASE_URL=$base_url"
  fi
  if [ -n "$provider_type" ]; then
    DART_DEFINES="$DART_DEFINES --dart-define=TEST_PROVIDER_TYPE=$provider_type"
  fi
  echo -e "${GREEN}[INFO]${NC} .env.test loaded (provider: ${provider_type:-default})"
}

echo "========================================="
echo " AIOS Test Runner"
echo "========================================="

echo ""
echo "--- Unit / Widget / Smoke Tests (flutter test) ---"
if flutter test; then
  UNIT_RESULT=0
  echo -e "${GREEN}[PASS]${NC} Unit tests passed"
else
  UNIT_RESULT=$?
  echo -e "${RED}[FAIL]${NC} Unit tests failed (exit: $UNIT_RESULT)"
fi

echo ""
echo "--- Checking for connected device ---"
DEVICE=""
if command -v adb &>/dev/null; then
  DEVICE=$(adb devices 2>/dev/null | grep -v 'List of devices' | grep 'device$' | head -1 | awk '{print $1}')
fi

if [ -z "$DEVICE" ]; then
  INTG_STATUS="skipped"
  echo -e "${YELLOW}[SKIP]${NC} No connected device found. Integration tests skipped."
  echo "       Connect a device and re-run to include integration tests."
else
  echo "Device found: $DEVICE"
  _resolve_dart_defines "${SCRIPT_DIR:-.}/.env.test"
  echo ""
  echo "--- Integration Tests (flutter test integration_test/) ---"
  if flutter test integration_test/ -d "$DEVICE" $DART_DEFINES; then
    INTG_RESULT=0
    INTG_STATUS="passed"
    echo -e "${GREEN}[PASS]${NC} Integration tests passed"
  else
    INTG_RESULT=$?
    INTG_STATUS="failed"
    echo -e "${RED}[FAIL]${NC} Integration tests failed (exit: $INTG_RESULT)"
  fi
fi

echo ""
echo "========================================="
echo " Summary"
echo "========================================="
if [ $UNIT_RESULT -eq 0 ]; then
  echo -e "  Unit tests:        ${GREEN}PASSED${NC}"
else
  echo -e "  Unit tests:        ${RED}FAILED${NC} (exit: $UNIT_RESULT)"
fi

case $INTG_STATUS in
  passed)  echo -e "  Integration tests: ${GREEN}PASSED${NC}" ;;
  failed)  echo -e "  Integration tests: ${RED}FAILED${NC} (exit: $INTG_RESULT)" ;;
  skipped) echo -e "  Integration tests: ${YELLOW}SKIPPED${NC} (no device)" ;;
esac

echo "========================================="

if [ $UNIT_RESULT -ne 0 ]; then
  exit $UNIT_RESULT
fi
if [ "$INTG_STATUS" = "failed" ]; then
  exit $INTG_RESULT
fi
exit 0
