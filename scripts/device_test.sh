#!/bin/bash
set -euo pipefail

PKG="com.agent.aios"
ACTIVITY="${PKG}/.MainActivity"
UI_XML="/sdcard/ui.xml"
LOCAL_UI="/tmp/aios_ui.xml"
APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
LOG_TAG="AIOS-"

DEVICE=""
VERBOSE=0
SKIP_BUILD=0
TESTS=()

usage() {
  echo "Usage: $0 -d DEVICE [options] [test_names...]"
  echo ""
  echo "Options:"
  echo "  -d DEVICE    ADB device serial (required)"
  echo "  -s           Skip build & install"
  echo "  -v           Verbose output"
  echo "  -h           Show this help"
  echo ""
  echo "Available tests: onboarding model chat_hello chat_open_firefox chat_calculator all"
  echo "Default: all"
  exit 0
}

log() { echo "[$(date +%H:%M:%S)] $*"; }
warn() { echo "[$(date +%H:%M:%S)] WARN: $*" >&2; }
fail() { echo "[$(date +%H:%M:%S)] FAIL: $*" >&2; PASS=1; }

PASS=0

adb_cmd() {
  adb -s "$DEVICE" "$@"
}

# ─── UIAutomator helpers ───

dump_ui() {
  adb_cmd shell uiautomator dump "$UI_XML" 2>/dev/null || true
  adb_cmd pull "$UI_XML" "$LOCAL_UI" 2>/dev/null || true
  if [ "$VERBOSE" -eq 1 ]; then
    cat "$LOCAL_UI" 2>/dev/null || echo "(empty dump)"
  fi
}

find_element() {
  local attr="$1"
  local val="$2"
  grep -oP "<node[^>]*${attr}=\"${val}\"[^>]*>" "$LOCAL_UI" 2>/dev/null | head -1
}

get_center() {
  local bounds="$1"
  local coords
  coords=$(echo "$bounds" | grep -oP '\[\K[0-9]+,[0-9]+' | tr '\n' ' ')
  local x1 y1 x2 y2
  x1=$(echo "$coords" | awk '{print $1}' | cut -d, -f1)
  y1=$(echo "$coords" | awk '{print $1}' | cut -d, -f2)
  x2=$(echo "$coords" | awk '{print $2}' | cut -d, -f1)
  y2=$(echo "$coords" | awk '{print $2}' | cut -d, -f2)
  echo "$(( (x1 + x2) / 2 )) $(( (y1 + y2) / 2 ))"
}

tap_element() {
  local attr="$1"
  local val="$2"
  dump_ui
  local elem
  elem=$(find_element "$attr" "$val")
  if [ -z "$elem" ]; then
    local alt_attr
    case "$attr" in
      text) alt_attr="content-desc" ;;
      content-desc) alt_attr="text" ;;
      *) alt_attr="" ;;
    esac
    if [ -n "$alt_attr" ]; then
      elem=$(find_element "$alt_attr" "$val")
    fi
  fi
  if [ -z "$elem" ]; then
    warn "Element not found: $attr=$val"
    return 1
  fi
  local bounds
  bounds=$(echo "$elem" | grep -oP 'bounds="\K[^"]+')
  local center
  center=$(get_center "$bounds")
  local x y
  x=$(echo "$center" | awk '{print $1}')
  y=$(echo "$center" | awk '{print $2}')
  log "Tap: $attr=$val at ($x, $y)"
  adb_cmd shell input tap "$x" "$y"
  return 0
}

tap_coords() {
  local x="$1" y="$2"
  log "Tap: ($x, $y)"
  adb_cmd shell input tap "$x" "$y"
}

wait_for_text() {
  local text="$1"
  local timeout="${2:-10}"
  local elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    dump_ui
    if grep -q "$text" "$LOCAL_UI" 2>/dev/null; then
      log "Found: '$text' (${elapsed}s)"
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  warn "Timeout waiting for: '$text' (${timeout}s)"
  return 1
}

input_text() {
  local text="$1"
  local before=""
  local after="$text"
  while [[ "$after" == *" "* ]]; do
    before="${after%% *}"
    after="${after#* }"
    adb_cmd shell input text "$before"
    adb_cmd shell input keyevent 62
  done
  adb_cmd shell input text "$after"
}

press_enter() {
  adb_cmd shell input keyevent 66
}

press_back() {
  adb_cmd shell input keyevent 4
}

clear_logcat() {
  adb_cmd logcat -c
}

get_aios_logs() {
  adb_cmd logcat -d | grep "\[${LOG_TAG}" || true
}

wait_for_log() {
  local pattern="$1"
  local timeout="${2:-30}"
  local elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    if get_aios_logs | grep -q "$pattern"; then
      log "Log matched: '$pattern' (${elapsed}s)"
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  warn "Timeout waiting for log: '$pattern' (${timeout}s)"
  return 1
}

# ─── Test steps ───

do_build() {
  log "Building debug APK..."
  flutter build apk --debug 2>&1 | tail -3
  if [ ! -f "$APK_PATH" ]; then
    fail "APK not found: $APK_PATH"
    return 1
  fi
  log "Build OK"
}

do_install() {
  log "Uninstalling old version..."
  adb_cmd uninstall "$PKG" 2>/dev/null || true
  log "Installing APK..."
  adb_cmd install "$APK_PATH" 2>&1
  log "Install OK"
}

do_launch() {
  log "Launching app..."
  adb_cmd shell am start -n "$ACTIVITY"
  sleep 5
}

test_onboarding() {
  log "=== TEST: Onboarding ==="
  do_launch

  dump_ui
  if grep -q "Welcome to AIOS" "$LOCAL_UI" 2>/dev/null; then
    log "Onboarding detected, completing..."

    for i in 1 2 3 4; do
      if tap_element "content-desc" "Next"; then
        sleep 2
      elif tap_element "content-desc" "Get Started"; then
        sleep 2
      else
        warn "No Next/Get Started button found on page $i"
        dump_ui
        fail "Onboarding stuck on page $i"
        return 1
      fi
    done

    sleep 3
    dump_ui
    if grep -q "Welcome to AIOS" "$LOCAL_UI" 2>/dev/null; then
      fail "Onboarding did not complete"
      return 1
    fi
    log "Onboarding completed"
  else
    log "Onboarding already completed (skipped)"
  fi
}

test_model_load() {
  log "=== TEST: Model Load ==="

  dump_ui
  if get_aios_logs | grep -q "Model loaded"; then
    log "Model already loaded (skipped)"
    return 0
  fi

  log "Granting storage permissions..."
  adb_cmd shell pm grant "$PKG" android.permission.READ_EXTERNAL_STORAGE 2>/dev/null || true
  adb_cmd shell appops set "$PKG" MANAGE_EXTERNAL_STORAGE allow 2>/dev/null || true

  log "Navigating to settings..."
  if ! tap_element "content-desc" "Settings"; then
    dump_ui
    warn "Settings button not found in UI, trying AppBar position"
    tap_coords 1017 168
    sleep 2
  fi

  sleep 2
  dump_ui

  if ! grep -q 'content-desc="Load"' "$LOCAL_UI" 2>/dev/null; then
    if grep -q 'content-desc="Scan"' "$LOCAL_UI" 2>/dev/null; then
      log "No models imported yet, opening Import dialog..."
      tap_element "content-desc" "Import"
      sleep 3
      dump_ui

      local import_btn
      import_btn=$(grep -oP '<node[^>]*content-desc="[^"]*\n[^\"]*MB[^"]*"[^>]*clickable="false"[^>]*>' "$LOCAL_UI" | head -1)
      if [ -z "$import_btn" ]; then
        import_btn=$(grep -oP '<node[^>]*content-desc="[^"]*\.gguf[^"]*"[^>]*>' "$LOCAL_UI" | grep 'clickable="false"' | head -1)
      fi

      if [ -n "$import_btn" ]; then
        local model_bounds
        model_bounds=$(echo "$import_btn" | grep -oP 'bounds="\K[^"]+')
        local model_center
        model_center=$(get_center "$model_bounds")
        local model_y
        model_y=$(echo "$model_center" | awk '{print $2}')

        local import_btn_in_model
        import_btn_in_model=$(grep -oP "<node[^>]*content-desc=\"Import\"[^>]*bounds=\"\[[0-9]+,${model_y:-0}" "$LOCAL_UI" | head -1)
        if [ -n "$import_btn_in_model" ]; then
          local ib_bounds
          ib_bounds=$(echo "$import_btn_in_model" | grep -oP 'bounds="\K[^"]+')
          local ib_center
          ib_center=$(get_center "$ib_bounds")
          local ib_x ib_y
          ib_x=$(echo "$ib_center" | awk '{print $1}')
          ib_y=$(echo "$ib_center" | awk '{print $2}')
          log "Importing first model at ($ib_x, $ib_y)..."
          tap_coords "$ib_x" "$ib_y"
          sleep 8

          dump_ui
        fi
      fi

      log "Closing import dialog..."
      tap_element "content-desc" "Close" || tap_element "content-desc" "Dismiss"
      sleep 2
      dump_ui
    fi
  fi

  log "Looking for Load button..."
  if ! tap_element "content-desc" "Load"; then
    dump_ui
    warn "Load button not found. Available content-desc:"
    grep -oP 'content-desc="[^"]*"' "$LOCAL_UI" 2>/dev/null | sort -u | head -20
    fail "Cannot find model Load button"
    return 1
  fi

  log "Waiting for model to load..."
  if wait_for_log "Model loaded" 40; then
    log "Model loaded successfully"
  else
    get_aios_logs | tail -10
    fail "Model did not load"
    return 1
  fi

  press_back
  sleep 2
}

test_chat() {
  local name="$1"
  local input="$2"
  local expect_log="$3"

  log "=== TEST: Chat '$name' ==="
  clear_logcat

  log "Input: '$input'"
  input_text "$input"
  press_enter

  log "Waiting for agent response..."
  if wait_for_log "$expect_log" 45; then
    log "PASS: '$name'"
  else
    warn "Agent logs for '$name':"
    get_aios_logs | tail -20
    fail "FAIL: '$name' — expected log '$expect_log' not found"
  fi

  sleep 3
}

# ─── Main ───

while getopts "d:svh" opt; do
  case $opt in
    d) DEVICE="$OPTARG" ;;
    s) SKIP_BUILD=1 ;;
    v) VERBOSE=1 ;;
    h) usage ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

if [ -z "$DEVICE" ]; then
  echo "ERROR: -d DEVICE is required"
  usage
fi

log "Device: $DEVICE"

if [ "$SKIP_BUILD" -eq 0 ]; then
  do_build
  do_install
fi

TESTS=("$@")
if [ ${#TESTS[@]} -eq 0 ]; then
  TESTS=("onboarding" "model" "chat_hello" "chat_open_firefox" "chat_calculator")
fi

for t in "${TESTS[@]}"; do
  case $t in
    onboarding) test_onboarding ;;
    model) test_model_load ;;
    chat_hello) test_chat "hello" "hello" "Phase0: CONVERSATION\|Answer:" ;;
    chat_open_firefox) test_chat "open firefox" "open firefox" "Phase0: TASK\|app_launcher" ;;
    chat_calculator) test_chat "2+2" "2+2" "Phase0: TASK\|calculator" ;;
    all)
      test_onboarding
      test_model_load
      test_chat "hello" "hello" "Phase0: CONVERSATION\|Answer:"
      test_chat "open firefox" "open firefox" "Phase0: TASK\|app_launcher"
      test_chat "2+2" "2+2" "Phase0: TASK\|calculator"
      ;;
    *)
      warn "Unknown test: $t"
      ;;
  esac
done

log "================================"
if [ "$PASS" -eq 0 ]; then
  log "ALL TESTS PASSED"
  exit 0
else
  log "SOME TESTS FAILED"
  exit 1
fi
