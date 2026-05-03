# AIOS Testing Policy

## 1. Principles

- All **public functions** must have at least one unit test
- **State-changing** ViewModel functions must verify state transitions
- **Async/concurrent** code must be tested with coroutine test scenarios
- Bug fixes must include a **regression test** that reproduces the original bug
- Tests are written **before or alongside** the feature, never after-the-fact only

## 2. Test Scope

### P0: Core Logic (Mandatory)

| Module | File | What to Test |
|--------|------|-------------|
| AgentEngine | `AgentEngine.kt` | parseResponse, riskClassification, confirmationFlow, cancellation, threadInterruption |
| ChatViewModel | `ChatViewModel.kt` | sendMessage, cancelGeneration, loadModel, importModel, stateConsistency |
| LlmService | `LlmService.kt` | model lifecycle, concurrent access, callback swap, context reset |

### P1: State Management (Mandatory)

| Module | File | What to Test |
|--------|------|-------------|
| AIOSApp | `AIOSApp.kt` | service binding, agent lifecycle, cancelInference, state transitions |
| SettingsViewModel | `SettingsViewModel.kt` | settings read/write, defaults |
| UpdateViewModel | `UpdateViewModel.kt` | check/download/install flow, error states |

### P2: UI (Mandatory)

| Screen | File | What to Test |
|--------|------|-------------|
| ChatScreen | `ChatScreen.kt` | send message, stop button, input bar visibility, empty state |
| SettingsScreen | `SettingsScreen.kt` | permission rows, advanced toggle, overlay service switch |
| ConfirmationDialog | `ChatScreen.kt` | countdown, auto-deny, allow/deny actions |
| UpdateScreen | `UpdateScreen.kt` | state transitions, download progress |

### P3: Tools (Mandatory)

| Module | File | What to Test |
|--------|------|-------------|
| Basic Tools | `AgentTools.kt` | calculator, timer, notepad, device_info — all actions |
| Screen Tools | `ScreenReaderTool.kt`, `ScreenActionTool.kt` | action parsing, validation |
| App Launcher | `AppLauncherTool.kt` | open_app, open_url |
| Notification | `NotificationTool.kt` | read notifications |

### P4: Native (Separate Plan)

| Module | File | What to Test |
|--------|------|-------------|
| JNI Bridge | `native-lib.cpp` | load/infer/release lifecycle, null model guards, concurrent access |
| CTest framework in `native/tests/` | Thread safety via TSan/ASan |

## 3. Test Categories

```
test/           → Unit tests (MockK, Turbine, coroutines-test)
androidTest/    → Integration tests (real Context, Compose UI tests)
native/tests/   → C++ unit tests (CTest)
```

## 4. Coverage Requirements

### Per Function
- **Happy path**: 1 test (normal input → expected output)
- **Edge case**: 1 test minimum (null, empty, boundary values)
- **Error path**: 1 test for each known failure mode

### Per Concurrency Scenario
- **Cancel during execution**: 1 test
- **Race condition**: 1 test per identified race
- **Timeout**: 1 test

### Per UI Screen
- **Initial render**: 1 test
- **Key interaction**: 1 test per user action
- **State transition**: 1 test per visible state change

## 5. Regression Test Rule

When a bug is reported:
1. Write a test that **reproduces the bug** (must fail)
2. Fix the bug
3. Verify the test **passes**
4. Commit test + fix together

## 6. Naming Conventions

```
Class:     {ModuleName}Test.kt
Function:  {method}_{scenario}_expectedResult()

Examples:
  sendMessage_whenGenerating_doesNotSend()
  cancelGeneration_duringAgentRun_resetsState()
  parseResponse_withActionAndArgs_returnsActionMap()
  ConfirmationDialog_countdownExpires_autoDenies()
```

## 7. Required Dependencies

```kotlin
testImplementation("io.mockk:mockk:1.13.8")
testImplementation("app.cash.turbine:turbine:1.0.0")
testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
testImplementation("com.google.truth:truth:1.1.5")
testImplementation(kotlin("test"))

androidTestImplementation("io.mockk:mockk-android:1.13.8")
androidTestImplementation("androidx.compose.ui:ui-test-junit4")
androidTestImplementation("androidx.test.ext:junit:1.1.5")
androidTestImplementation("androidx.test:runner:1.5.2")
androidTestImplementation("androidx.test:rules:1.5.0")
```

## 8. Local Development & Verification

- 모든 테스트는 로컬에서 실행: `cd android && ./gradlew test`
- pre-commit: ktlint 코드 스타일 검사 자동 실행 (`.githooks/pre-commit`)
- pre-push: 릴리즈 빌드 + GitHub Release 자동 생성 (`.githooks/pre-push`)
- 테스트 실패 시 작업 중단, 다음 단계로 넘어가지 않음

## 9. Android Runtime Constraint Tests (Mandatory)

Unit tests (Robolectric/MockK)은 Android 프레임워크 제약을 검증할 수 없습니다.
다음 케이스는 **Instrumented Test (androidTest)** 로만 검증 가능하며, 필수입니다.

### P0-Runtime: Framework Restrictions

| ID | Constraint | Test Location | What to Verify |
|----|-----------|---------------|----------------|
| R-1 | `ForegroundServiceStartNotAllowedException` (Android 12+) | `androidTest/` | Service는 Activity 포그라운드 상태에서만 시작 가능 |
| R-2 | `Application.onCreate()`에서 포그라운드 서비스 시작 금지 | `androidTest/` | AIOSApp.onCreate()가 startForegroundService()를 직접 호출하지 않음 |
| R-3 | `Context.startForegroundService()` → `Service.onStartCommand()` 5초 내 `startForeground()` 필수 | `androidTest/` | LlmService가 ANR 없이 5초 내 알림 게시 |
| R-4 | 권한 거부 시 서비스 바인딩 graceful degradation | `androidTest/` | 예외 발생 시 DISCONNECTED 상태 전이, 크래시 없음 |
| R-5 | Android 16 (SDK 36) 백그라운드 제한 | `androidTest/` | Activity 없이 서비스 시작 시 예외 catch됨 |

### 규칙

1. **Application.lifecycle vs Activity.lifecycle 구분 필수**
   - `Application.onCreate()`: 크래시 로거, Settings 저장소 등 프레임워크 독립적 초기화만
   - `Activity.onCreate()`: 포그라운드 서비스, 권한 요청 등 UI 컨텍스트 필요 작업
2. **서비스 시작은 항상 try-catch로 보호**
   - `startForegroundService()` / `bindService()` 호출부는 반드시 예외 처리
3. **새 Android 버전 릴리즈 시 회귀 테스트 업데이트**
   - targetSdkVersion 변경 시 R-x 테스트 케이스 재검증

## 10. Known Crash Regression Tests

The following crashes identified in analysis must have regression tests:

| ID | Crash | Test Required |
|----|-------|---------------|
| P0-1 | Native global state no thread safety (SIGSEGV) | Native mutex test |
| P0-2 | JNI callback without ExceptionCheck | Native callback test |
| P0-3 | tokenize() with null g_vocab | Native null guard test |
| P0-4 | agentEngine not @Volatile | LlmService concurrency test |
| P1-1 | onServiceConnected unsafe cast | AIOSApp binding test |
| P1-2 | llmService!! force unwrap | AIOSApp null safety test |
| P1-3 | loadModel leaks old model | LlmService lifecycle test |
| P1-4 | collectStream callback not restored on cancel | AgentEngine cancel test |
| P1-5 | notes map concurrent access | AgentEngine concurrency test |

## 11. TDD Workflow

### 개발 사이클

| Phase | 작업 | 검증 |
|-------|------|------|
| RED | 테스트 케이스 작성 (§4 기준) | `cd android && ./gradlew test` → 실패 확인 |
| GREEN | 최소 구현 코드 작성 | `cd android && ./gradlew test` → 전체 통과 |
| REFACTOR | 코드 품질 개선 | `cd android && ./gradlew test` → 여전히 통과 |

### 기능별 TDD 체크리스트

**새 Tool 추가 시:**
1. [ ] `execute()` 입력/출력 테스트 작성
2. [ ] `classifyRisk()` 테스트 추가 (§P3)
3. [ ] `buildSystemPrompt()` 매니페스트 포함 테스트
4. [ ] Tool 구현 코드 작성
5. [ ] `cd android && ./gradlew test` 전체 통과 확인

**ViewModel 수정 시:**
1. [ ] 상태 전이 테스트 작성 (초기 → 변경 → 결과)
2. [ ] 에러/엣지케이스 테스트 작성
3. [ ] ViewModel 코드 수정
4. [ ] `cd android && ./gradlew test` 전체 통과 확인

**Bug fix 시 (§5 준수):**
1. [ ] 버그 재현 테스트 작성 (반드시 실패해야 함)
2. [ ] 버그 수정 코드 작성
3. [ ] 테스트 통과 확인
4. [ ] 기존 테스트 여전히 통과 확인

### 코드 스타일 검증

```bash
# ktlint 체크
cd android && ./gradlew ktlintCheck

# ktlint 자동 수정
cd android && ./gradlew ktlintFormat
```
