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
- GitHub Releases 기반 in-app 자동 업데이트 시스템 탑재

## Architecture

```
Compose UI -> ViewModel (StateFlow) -> AIOSApp -> LlmService -> JNI -> llama.cpp (C++)
                                                           -> AgentEngine -> Tools
                                                           -> AccessibilityService
                                                           -> NotificationListener
                                                           -> UpdateChecker -> GitHub API
```

### Key Modules

| Module | File | Responsibility |
|--------|------|---------------|
| Application | `AIOSApp.kt` | Service binding, state flows, model lifecycle, background update check |
| Agent Engine | `AgentEngine.kt` | ReAct loop: think -> act -> observe (max 5 iterations) |
| Native Bridge | `LlamaBridge.kt` + `native-lib.cpp` | JNI: model load, tokenize, streaming generation |
| LLM Service | `LlmService.kt` | Foreground service wrapping native inference |
| Basic Tools | `AgentTools.kt` | calculator, timer, device_info, notepad |
| Screen Tools | `agent/tools/ScreenReaderTool.kt`, `ScreenActionTool.kt` | screen_reader, screen_find, screen_action |
| App Launcher | `agent/tools/AppLauncherTool.kt` | app_launcher: open apps, URLs, settings |
| Notification | `agent/tools/NotificationTool.kt` | notification_reader |
| Update System | `update/GitHubReleaseApi.kt` | GitHub Releases API communication |
| Update Checker | `update/UpdateChecker.kt` | Version comparison, update availability |
| Update Downloader | `update/UpdateDownloader.kt` | APK download with progress tracking |
| APK Installer | `update/ApkInstaller.kt` | FileProvider-based APK installation |
| Update UI | `ui/screen/UpdateScreen.kt` | Update check, download, install UI |
| Update VM | `ui/viewmodel/UpdateViewModel.kt` | Update state management |
| Accessibility | `service/AIOSAccessibilityService.kt` | Screen text reading, element interaction |
| Notification Listener | `service/NotificationListener.kt` | System notification reader |
| Overlay | `service/OverlayService.kt` | Floating AI button |
| Chat UI | `ui/screen/ChatScreen.kt` | Chat + agent mode UI |
| ViewModel | `ui/viewmodel/ChatViewModel.kt` | Message state, generation lifecycle, model import |

## Build & Development Commands

```bash
# Build (from android/ directory)
./gradlew assembleDebug

# Build release (signed)
./gradlew assembleRelease

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

## Release & Deployment

### Git Hooks (자동 빌드+배포)

pre-push 훅이 버전 변경을 감지하여 자동으로 빌드 후 GitHub Release를 생성합니다.

```bash
# 최초 설정 (clone 후 1회)
git config core.hooksPath .githooks
```

**동작 시나리오:**

| 상황 | 동작 |
|------|------|
| 버전 변경 없이 `git push` | 훅 스킵, 일반 push |
| `versionName` 변경 후 `git push` | 자동 빌드 → 태그 생성 → GitHub Release 생성 |

### 수동 릴리즈

```bash
# 버전 업 + 빌드 + 태그 + 푸시 + 릴리즈 한 번에
./release.sh 1.1.0
```

스크립트가 수행하는 작업:
1. `build.gradle.kts` versionCode/versionName 자동 수정
2. `assembleRelease` 빌드
3. 커밋 + 태그(`v1.1.0`) 생성
4. `git push origin master --tags`
5. `gh release create` + APK 업로드

### In-App 자동 업데이트

- 앱 실행 시 `AIOSApp.onCreate()`에서 백그라운드로 GitHub Releases API 조회
- `SettingsScreen` UPDATE 섹션에서 수동 확인 가능
- 업데이트 있으면 `UpdateScreen`에서 다운로드 + 설치 진행
- APK 다운로드 후 FileProvider + `ACTION_VIEW` Intent로 설치

### 버전 관리 규칙

- `versionName`: semver 형식 (`MAJOR.MINOR.PATCH`, 예: `1.0.0`)
- `versionCode`: `MAJOR * 10000 + MINOR * 100 + PATCH` (예: `10100` for `1.1.0`)
- Release keystore: `android/aios-release.jks`

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
- CPU thread count: auto-detected via `_SC_NPROCESSORS_ONLN`, capped at 8

### Model Import

- Uses Storage Access Framework (SAF) to import GGUF files from any location
- `ChatViewModel.importModelFromUri()` copies selected file to internal `models/` directory
- No scoped storage permission needed — SAF handles file access

## TDD Workflow (필수)

이 프로젝트는 **Test-Driven Development**를 엄격히 따릅니다.

### Red → Green → Refactor

1. **RED** — 구현 전, 실패하는 테스트를 먼저 작성
   - TESTING.md §4 (Coverage Requirements)에 따라 테스트 케이스 식별
   - Happy path + Edge case + Error path 최소 3개
   - `cd android && ./gradlew test` 실행 → 테스트가 **실패**하는지 확인

2. **GREEN** — 테스트를 통과하는 최소 구현 코드 작성
   - 과도한 추상화 없이 테스트만 통과시킴
   - `cd android && ./gradlew test` 실행 → **전체 테스트 통과** 확인

3. **REFACTOR** — 코드 품질 개선
   - 중복 제거, 네이밍 정리, 구조 개선
   - `cd android && ./gradlew test` 재실행 → 여전히 통과 확인

### 필수 규칙

- **테스트 없는 구현 코드는 작성하지 않습니다**
- 모든 수정 후 반드시 `cd android && ./gradlew test` 실행
- 테스트 실패 시 다음 작업으로 넘어가지 않습니다
- 새 Tool 추가 → TESTING.md §P3 테스트 먼저
- ViewModel 수정 → TESTING.md §P1 테스트 먼저
- Bug fix → TESTING.md §5 Regression Test 먼저

## Key Principles

- **LLM is Runtime, not UI** — Model loaded once, reused across interactions
- **Queue-based sequential inference** — Single inference at a time
- **2-layer architecture** — Kotlin (UI + services) → C++ (inference)
- **Privacy-first** — No network calls for inference, all processing on-device
- **Phone control via Accessibility APIs** — No root required
- **OTA updates via GitHub Releases** — No Play Store dependency
- **Test-Driven Development** — 테스트 먼저 작성, Red → Green → Refactor

## Permissions Required

| Permission | Purpose |
|-----------|---------|
| `INTERNET` | GitHub Releases API (update check + APK download) |
| `ACCESS_NETWORK_STATE` | Network connectivity check |
| `FOREGROUND_SERVICE` | LLM inference service |
| `FOREGROUND_SERVICE_SPECIAL_USE` | Foreground service type declaration |
| `SYSTEM_ALERT_WINDOW` | Floating overlay button |
| `BIND_ACCESSIBILITY_SERVICE` | Screen reading & interaction |
| `BIND_NOTIFICATION_LISTENER_SERVICE` | Read notifications |
| `POST_NOTIFICATIONS` | Foreground service notification |
| `REQUEST_INSTALL_PACKAGES` | In-app APK update installation |
| `QUERY_ALL_PACKAGES` | List installed apps for launcher |

## Environment Setup

```bash
# Android SDK
export ANDROID_HOME=$HOME/Android/Sdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Git hooks (clone 후 1회)
git config core.hooksPath .githooks
```

## File Reference

| File | Key Lines | What to Look For |
|------|-----------|-----------------|
| `AIOSApp.kt` | `runAgent()`, `generateStream()`, `checkForUpdateBackground()` | Agent/chat/update entry points |
| `AgentEngine.kt` | `run()`, `executeTool()`, `buildSystemPrompt()` | Agent loop, tool dispatch, prompt |
| `ChatViewModel.kt` | `sendMessage()`, `importModelFromUri()` | UI → engine bridge, model import |
| `native-lib.cpp` | `nativeLoadModel()`, `nativeGenerateStream()` | JNI functions |
| `ScreenActionTool.kt` | `performAction()` | Tap/type/scroll/swipe dispatch |
| `AIOSAccessibilityService.kt` | `getRootInActiveWindow()` | Accessibility node tree access |
| `UpdateChecker.kt` | `checkForUpdate()` | Version comparison logic |
| `UpdateDownloader.kt` | `downloadApk()` | APK download with progress |
| `ApkInstaller.kt` | `installApk()` | FileProvider APK installation |
| `MainActivity.kt` | `modelImportLauncher` | SAF file picker registration |
| `.githooks/pre-push` | 전체 | Auto build+release on version change |
| `release.sh` | 전체 | Manual release script |
