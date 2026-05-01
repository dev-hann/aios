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

## 8. CI Integration (Future)

- `./gradlew test` runs on every PR
- Test failure blocks merge
- Coverage report generated per build

## 9. Known Crash Regression Tests

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
