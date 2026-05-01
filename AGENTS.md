# AIOS - AGENTS.md

## 알림 (Notification)

모든 작업을 완료한 후, 반드시 아래 명령을 실행하여 휴대폰으로 알림을 보냅니다:

```bash
./notify.sh "[작업 요약]"
```

예시:
- `./notify.sh "bugfix: AgentEngine ReAct 루프 오류 수정 완료"`
- `./notify.sh "feature: ScreenActionTool에 swipe 기능 추가 완료"`
- `./notify.sh "refactor: ChatViewModel 상태 관리 리팩토링 완료"`

이 규칙은 모든 코딩 작업, 버그 수정, 리팩토링, 기능 추가 등에 적용됩니다.

## 프로젝트 개요

- Android 온디바이스 AI 에이전트 (Kotlin + C++/llama.cpp)
- ReAct 에이전트 루프로 화면 제어, 앱 실행, 알림 읽기 등 수행
- Privacy-first: 모든 추론은 온디바이스에서 실행

## Architecture

```
Compose UI -> ViewModel (StateFlow) -> AIOSApp -> LlmService -> JNI -> llama.cpp (C++)
                                                           -> AgentEngine -> Tools
                                                           -> AccessibilityService
                                                           -> NotificationListener
```

### Key Modules

| Module | File | Responsibility |
|--------|------|---------------|
| Application | `AIOSApp.kt` | Service binding, state flows, model lifecycle |
| Agent Engine | `AgentEngine.kt` | ReAct loop: think -> act -> observe (max 5 iterations) |
| Native Bridge | `LlamaBridge.kt` + `native-lib.cpp` | JNI: model load, tokenize, streaming generation |
| LLM Service | `LlmService.kt` | Foreground service wrapping native inference |
| Basic Tools | `AgentTools.kt` | calculator, timer, device_info, notepad |
| Screen Tools | `agent/tools/ScreenReaderTool.kt`, `ScreenActionTool.kt` | screen_reader, screen_find, screen_action |
| App Launcher | `agent/tools/AppLauncherTool.kt` | app_launcher: open apps, URLs, settings |
| Notification | `agent/tools/NotificationTool.kt` | notification_reader |
| Accessibility | `service/AIOSAccessibilityService.kt` | Screen text reading, element interaction |
| Notification Listener | `service/NotificationListener.kt` | System notification reader |
| Overlay | `service/OverlayService.kt` | Floating AI button |
| Chat UI | `ui/screen/ChatScreen.kt` | Chat + agent mode UI |
| ViewModel | `ui/viewmodel/ChatViewModel.kt` | Message state, generation lifecycle |

## Build & Development Commands

```bash
# Build (from android/ directory)
./gradlew assembleDebug

# Install on device
./gradlew installDebug

# Clean build
./gradlew clean assembleDebug

# Run tests
./gradlew test

# Android tests (requires device/emulator)
./gradlew connectedAndroidTest
```

### Native Build

The C++ layer builds automatically via CMake when building the Android project. To build standalone native tests:

```bash
cd native/tests
mkdir build && cd build
cmake .. -DLLAMA_CPP_DIR=../../native/llama.cpp
make
./test_inference
```

## Code Structure & Conventions

### Kotlin Conventions
- Follow [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html)
- Use StateFlow/SharedFlow for reactive state (no LiveData)
- Coroutines for all async work (no RxJava)
- Single Activity pattern with Navigation Compose
- Package by feature under `com.agent.aios`

### Tool Development

To add a new agent tool:

1. **Basic tool** (no Android framework access): Add to `AgentTools.kt`
   - Implement `AgentTool` interface
   - Register in `basicTools` map

2. **Extended tool** (needs Context/AccessibilityService): Create in `agent/tools/`
   - Implement `AgentEngine.ExtendedTool` interface
   - Register in `AgentEngine.extendedTools` map
   - Pass `context` and `accessibilityService` as constructor params

Tool interface:
```kotlin
interface AgentTool {
    val name: String
    val description: String
    fun execute(args: String): String
}
```

3. **Update the system prompt** in `AgentEngine.buildSystemPrompt()` to include the new tool in the manifest.

### Agent Response Format

The LLM outputs one of:
- `Action: <tool_name>\nArgs: <json>` — Execute a tool
- `Answer: <text>` — Final answer to user
- Plain text — Treated as direct answer

### Native Code (C++)

- `native-lib.cpp` contains all JNI functions
- Uses llama.cpp API directly (no wrapper)
- Sampling: temperature=0.7, top_k=40, top_p=0.9
- Chat template applied via `llama_chat_apply_template()`

## Key Principles

- **LLM is Runtime, not UI** — Model loaded once, reused across interactions
- **Queue-based sequential inference** — Single inference at a time
- **2-layer architecture** — Kotlin (UI + services) → C++ (inference)
- **Privacy-first** — No network calls, all processing on-device
- **Phone control via Accessibility APIs** — No root required

## Permissions Required

| Permission | Purpose |
|-----------|---------|
| `INTERNET` | (Future: model download) |
| `FOREGROUND_SERVICE` | LLM inference service |
| `SYSTEM_ALERT_WINDOW` | Floating overlay button |
| `BIND_ACCESSIBILITY_SERVICE` | Screen reading & interaction |
| `BIND_NOTIFICATION_LISTENER_SERVICE` | Read notifications |
| `POST_NOTIFICATIONS` | Foreground service notification |

## File Reference

| File | Key Lines | What to Look For |
|------|-----------|-----------------|
| `AIOSApp.kt` | `runAgent()`, `generateStream()` | Agent/chat entry points |
| `AgentEngine.kt` | `run()`, `executeTool()`, `buildSystemPrompt()` | Agent loop, tool dispatch, prompt |
| `ChatViewModel.kt` | `sendMessage()` | UI → engine bridge |
| `native-lib.cpp` | `nativeLoadModel()`, `nativeGenerateStream()` | JNI functions |
| `ScreenActionTool.kt` | `performAction()` | Tap/type/scroll/swipe dispatch |
| `AIOSAccessibilityService.kt` | `getRootInActiveWindow()` | Accessibility node tree access |
