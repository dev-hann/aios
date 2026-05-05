# Fix: Model Loading Freeze Regression

## TL;DR

> **Quick Summary**: v1.9.7에서 추가한 진행률 폴링이 모델 크기와 무관하게 앱 멈춤을 유발. 폴링 루프를 제거하고 정적 스피너로 교체.
> 
> **Deliverables**:
> - 폴링 루프 제거된 LlmRepositoryImpl
> - 정적 스피너로 교체된 ModelLoadingView
> - 수정된 ChatScreenTest 3개
> 
> **Estimated Effort**: Quick
> **Parallel Execution**: NO - sequential (3 tasks, each depends on previous)
> **Critical Path**: Task 1 → Task 2 → Task 3 → Final Verification

---

## Context

### Original Request
작은 모델(Qwen 2.5 1.5B)로도 앱이 멈춤. MVP 시절에는 멈춤이 없었음.

### Interview Summary
**Key Discussions**:
- MVP에는 폴링이 없었고, v1.9.7에서 진행률 바 기능 추가 시 들어감
- 작은 모델도 멈춤 → 메모리 압박이 아니라 폴링 자체가 원인
- 500ms마다 Main 스레드에서 Compose 재구성 트리거가 GC pause 유발

**Root Cause** (확정):
```
Every 500ms during model loading:
1. appScope.launch (Main) → withContext(IO) → 2 JNI calls
2. _loadProgress.value = ..., _loadStage.value = ... 
3. 5 collectors in ChatViewModel init fire on Main thread
4. Each: _uiState.value = _uiState.value.copy(...) → new object allocation
5. Compose recomposition on Main thread
6. Under ANY memory load → GC pause → freeze
```

### Metis Review
**Identified Gaps** (addressed):
- `pollJob` leak on exception: `svc.loadModel()`이 예외 throw하면 `pollJob.cancel()` 실행 안 됨 → 무한 폴링 (해결: 폴링 자체 제거로 moot)
- 3개 ChatScreenTest 수정 필요: 진행률 바 → 정적 스피너 변경 시
- Option A 권장: `loadProgress`/`loadStage` 필드 유지, 폴링만 제거 (최소 변경)

---

## Work Objectives

### Core Objective
MVP 시절의 깔끔한 로딩 경험 복원 — 모델 로딩 중 앱 멈춤 제거

### Concrete Deliverables
- `LlmRepositoryImpl.kt`: 폴링 루프 제거, 로딩 완료 후 1회만 진행률 읽기
- `ChatScreen.kt`: `ModelLoadingView`를 정적 스피너로 단순화 (progress bar 제거, stage label 제거)
- `ChatScreenTest.kt`: 3개 테스트 재작성

### Definition of Done
- [ ] `./gradlew assembleDebug` 성공
- [ ] `./gradlew test` 통과
- [ ] 에뮬레이터에서 모델 로딩 시 멈춤 없음
- [ ] `grep -n "while (isActive)" LlmRepositoryImpl.kt` 결과 없음
- [ ] `grep -n "pollJob" LlmRepositoryImpl.kt` 결과 없음

### Must Have
- 폴링 루프 완전 제거
- 정적 로딩 스피너 (animated icon + "Loading model..." 텍스트)
- `modelSizeWarning` 배너 유지
- `madvise(MADV_DONTNEED)` 유지
- 기존 `loadProgress`/`loadStage` 인터페이스/필드 유지 (Option A)
- ChatScreenTest 3개 재작성

### Must NOT Have (Guardrails)
- `native-lib.cpp` 수정 금지 (madvise, atomic progress 유지)
- `LlamaBridge.kt` 수정 금지
- `LlmService.kt` 수정 금지
- `LlmRepository.kt` (인터페이스) 수정 금지
- `loadProgress`/`loadStage`를 ChatUiState나 인터페이스에서 제거 금지
- `NativeInferenceTest.kt` 수정 금지
- 새로운 StateFlow, Repository, 아키텍처 변경 추가 금지
- AI slop: 과도한 주석, 불필요한 추상화, generic 네이밍

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** - ALL verification is agent-executed.

### Test Decision
- **Infrastructure exists**: YES
- **Automated tests**: YES (Tests-after)
- **Framework**: bun test / JUnit (Android Gradle)
- **Unit tests**: Existing test suite must pass
- **Instrumented tests**: Existing suite must pass (pre-existing failures in UpdateViewModelTest, testLoadModel_validModel OK to ignore)

### QA Policy
Every task includes agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Sequential — fix core issue):
├── Task 1: Remove polling loop from LlmRepositoryImpl [quick]

Wave 2 (After Task 1 — UI update):
├── Task 2: Replace ModelLoadingView with static spinner [quick]

Wave 3 (After Task 2 — fix tests):
├── Task 3: Rewrite 3 ChatScreenTest tests [quick]

Wave FINAL (After ALL tasks):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real manual QA on emulator (unspecified-high)
└── Task F4: Scope fidelity check (deep)
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|-----------|--------|
| 1 | None | 2, 3 |
| 2 | 1 | 3, F1-F4 |
| 3 | 2 | F1-F4 |
| F1-F4 | 3 | User OK |

### Agent Dispatch Summary

- **Wave 1**: T1 → `quick`
- **Wave 2**: T2 → `quick`
- **Wave 3**: T3 → `quick`
- **FINAL**: F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

- [ ] 1. Remove polling loop from LlmRepositoryImpl.loadModel()

  **What to do**:
  - `LlmRepositoryImpl.kt`에서 `appScope.launch { while(isActive) { ... } }` 폴링 블록 제거
  - `pollJob` 변수 및 `pollJob.cancel()` 제거
  - 로딩 완료 후 `withContext(IO)` 블록 마지막에 1회만 진행률 읽기:
    ```kotlin
    _loadProgress.value = svc.getLoadProgress()
    _loadStage.value = svc.getLoadStage()
    ```
  - `_loadProgress.value = if (success) 1f else 0f`는 기존 유지
  - `try/finally` 패턴으로 변경하여 예외 시에도 상태 정리 보장

  **Must NOT do**:
  - `native-lib.cpp` 수정
  - `loadProgress`/`loadStage` StateFlow 필드 제거
  - `LlmRepository` 인터페이스 변경
  - `delay(500)` 남기기

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (solo)
  - **Blocks**: Tasks 2, 3
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `LlmRepositoryImpl.kt:169-224` — 현재 loadModel() 전체 구현 (폴링 루프 포함)
  - MVP 구현 (git show 552320e:AIOSApp.kt) — 폴링 없는 깔끔한 loadModel 패턴:
    ```kotlin
    inferenceJob = appScope.launch {
        withContext(Dispatchers.IO) {
            svc.loadModel(path, ctxSize)
            engine.initSystemPrompt()
            onResult(success)
        }
    }
    ```

  **Acceptance Criteria**:

  - [ ] `grep -n "while (isActive)" LlmRepositoryImpl.kt` → no matches
  - [ ] `grep -n "pollJob" LlmRepositoryImpl.kt` → no matches
  - [ ] `grep -n "delay(500)" LlmRepositoryImpl.kt` → no matches
  - [ ] `./gradlew assembleDebug` → BUILD SUCCESSFUL

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Build succeeds after polling removal
    Tool: Bash
    Preconditions: Code changes saved
    Steps:
      1. Run `./gradlew assembleDebug`
    Expected Result: BUILD SUCCESSFUL
    Failure Indicators: Compilation error
    Evidence: .sisyphus/evidence/task-1-build.txt

  Scenario: Unit tests pass after polling removal
    Tool: Bash
    Preconditions: Build succeeds
    Steps:
      1. Run `./gradlew test`
    Expected Result: 124/125 pass (1 pre-existing failure in UpdateViewModelTest)
    Failure Indicators: New test failures beyond pre-existing
    Evidence: .sisyphus/evidence/task-1-tests.txt
  ```

  **Commit**: YES
  - Message: `fix: remove polling loop causing loading freeze regression`
  - Files: `LlmRepositoryImpl.kt`

---

- [ ] 2. Replace ModelLoadingView with static spinner

  **What to do**:
  - `ChatScreen.kt`의 `ModelLoadingView` 함수 수정:
    - `progress: Float` 파라미터 제거
    - `stage: Int` 파라미터 제거
    - `warning: String?` 파라미터 유지
    - 진행률 퍼센트 텍스트 제거 (`$progressPercent%`)
    - `LinearProgressIndicator` 제거
    - `stageLabel` 텍스트를 고정 "Loading model..." 으로 변경
    - animated icon (pulse 효과) 유지 — `EmptyState`와 동일한 패턴
    - `modelSizeWarning` 배너 유지 (Warning icon + 빨간 텍스트)
  - `ChatScreen.kt:125-129` 호출부 수정:
    - `ModelLoadingView(warning = uiState.modelSizeWarning)` 로 단순화
    - `progress`와 `stage` 전달 제거

  **Must NOT do**:
  - `loadProgress`/`loadStage`를 `ChatUiState`에서 제거
  - `ChatViewModel`의 collector 제거
  - `native-lib.cpp` 수정
  - `LlmRepository` 인터페이스 변경

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (solo)
  - **Blocks**: Task 3
  - **Blocked By**: Task 1

  **References**:

  **Pattern References**:
  - `ChatScreen.kt:260-333` (`EmptyState`) — animated icon + 텍스트 패턴 (동일한 `rememberInfiniteTransition` + `animateFloat` pulse)
  - `ChatScreen.kt:726-800` (현재 `ModelLoadingView`) — 제거할 진행률 바 + stage label

  **Acceptance Criteria**:

  - [ ] `grep -n "LinearProgressIndicator" ChatScreen.kt` → no matches
  - [ ] `grep -n "progressPercent" ChatScreen.kt` → no matches
  - [ ] `grep -n "stageLabel" ChatScreen.kt` → no matches
  - [ ] `ModelLoadingView`에 `warning` 파라미터만 있음
  - [ ] `./gradlew assembleDebug` → BUILD SUCCESSFUL

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Static spinner renders without progress bar
    Tool: Bash (adb)
    Preconditions: APK installed on emulator
    Steps:
      1. Force stop app: adb shell am force-stop com.agent.aios
      2. Start app: adb shell am start -n com.agent.aios/.MainActivity
      3. Wait 15s for auto-load to start
      4. Check logs: adb logcat -d -t 50 -s "AIOS-Native" "AIOS-LlmRepo"
    Expected Result: Model loads successfully without freeze, logs show normal loadModel flow
    Failure Indicators: App crash, ANR in logs, no "loadModel: done" log
    Evidence: .sisyphus/evidence/task-2-load-test.txt
  ```

  **Commit**: YES (groups with Task 3)
  - Message: `fix: replace progress bar with static spinner during model loading`
  - Files: `ChatScreen.kt`

---

- [ ] 3. Rewrite 3 ChatScreenTest tests for static spinner

  **What to do**:
  - `ChatScreenTest.kt`의 3개 테스트 재작성:
    - `modelLoadingView_showsProgressWhenGenerating` → "Loading model..." 텍스트 + spinner 표시 확인
    - `modelLoadingView_showsPreparingWhenProgressZero` → "Loading model..." 텍스트 확인
    - `modelLoadingView_showsTemplateStage` → "Loading model..." 텍스트 확인
  - 각 테스트에서 진행률 바, 퍼센트, stage label assertion 제거
  - `warning` 배너 표시 테스트 유지 또는 추가

  **Must NOT do**:
  - 테스트 삭제
  - 테스트 스킵 (`@Ignore`)
  - 다른 테스트 파일 수정

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (solo)
  - **Blocks**: F1-F4
  - **Blocked By**: Task 2

  **References**:

  **Pattern References**:
  - `ChatScreenTest.kt` — 기존 3개 테스트 패턴
  - `ChatScreen.kt` — 수정된 `ModelLoadingView` 구조

  **Acceptance Criteria**:

  - [ ] `./gradlew connectedAndroidTest --tests "*.ChatScreenTest"` → all pass
  - [ ] 3개 테스트 모두 "Loading model..." 텍스트 확인

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: All ChatScreenTests pass
    Tool: Bash
    Preconditions: Tasks 1-2 complete
    Steps:
      1. Run `./gradlew connectedAndroidTest --tests "*.ChatScreenTest"`
    Expected Result: All tests pass (including rewritten 3)
    Failure Indicators: Any test failure
    Evidence: .sisyphus/evidence/task-3-chat-screen-tests.txt
  ```

  **Commit**: YES (groups with Task 2)
  - Message: `fix: rewrite ChatScreenTest for static spinner`
  - Files: `ChatScreenTest.kt`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `./gradlew assembleDebug` + `./gradlew test`. Review all changed files for: `as any`/`@ts-ignore`, empty catches, console.log in prod, commented-out code, unused imports. Check AI slop: excessive comments, over-abstraction, generic names.
  Output: `Build [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Start from clean state. Force stop app, restart, wait for auto-load. Verify: no freeze during loading, spinner shows, chat works after load. Load a model from settings. Verify no freeze.
  Output: `Loading [no freeze] | Spinner [visible] | Chat [works] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff (git log/diff). Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance.
  Output: `Tasks [N/N compliant] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

- **Task 1**: `fix: remove polling loop causing loading freeze regression` - LlmRepositoryImpl.kt
- **Tasks 2+3**: `fix: replace progress bar with static spinner during model loading` - ChatScreen.kt, ChatScreenTest.kt

---

## Success Criteria

### Verification Commands
```bash
grep -n "while (isActive)" android/app/src/main/kotlin/com/agent/aios/data/llm/LlmRepositoryImpl.kt  # Expected: no output
grep -n "pollJob" android/app/src/main/kotlin/com/agent/aios/data/llm/LlmRepositoryImpl.kt  # Expected: no output
grep -n "LinearProgressIndicator" android/app/src/main/kotlin/com/agent/aios/ui/screen/ChatScreen.kt  # Expected: no output
cd android && ./gradlew assembleDebug  # Expected: BUILD SUCCESSFUL
cd android && ./gradlew test  # Expected: 124/125 pass
```

### Final Checklist
- [ ] Polling loop removed from LlmRepositoryImpl
- [ ] Static spinner replaces progress bar in ChatScreen
- [ ] All 3 ChatScreenTest rewritten and passing
- [ ] madvise(MADV_DONTNEED) intact in native-lib.cpp
- [ ] modelSizeWarning intact in ChatViewModel
- [ ] loadProgress/loadStage fields kept in interface
- [ ] No freeze during model loading on emulator
