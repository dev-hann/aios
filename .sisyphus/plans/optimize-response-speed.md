# Optimize Chat Response Speed

## TL;DR

> **Quick Summary**: Optimize first-token latency by reusing KV cache across agent loop iterations (eliminate full re-decode), adding batch token generation (reduce JNI overhead), and trimming system prompt verbosity. Add benchmark tests to measure improvement.
> 
> **Deliverables**:
> - KV cache reuse in ReactStrategy — subsequent iterations only process delta tokens
> - Batch token generation in native-lib.cpp — single JNI call for N tokens
> - System prompt optimization — reduced token count
> - Benchmark tests — first-token latency and tokens/second
> 
> **Estimated Effort**: Medium
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Task 1 (KV cache) → Task 3 (system prompt) → Task 4 (benchmarks); Task 2 (batch gen) parallel with Task 3

---

## Context

### Original Request
채팅 응답속도 최적화 — 첫 토큰 나올 때까지의 시간이 주요 불만. Qwen 1.5B (~1GB) 모델로 테스트.

### Interview Summary
**Key Discussions**:
- First-token latency is the main issue (not token generation speed)
- Testing with Qwen 1.5B (~1GB)
- User wants all three optimization levels: KV cache reuse + batch generation + system prompt
- Benchmark tests required for verification

**Research Findings**:
- `processPromptIncremental` in native-lib.cpp:348 calls `llama_memory_clear()` every agent iteration — wipes entire KV cache including system prompt pre-cached by `initSystemPrompt()`
- `processPrompt` (native-lib.cpp:131-156) already exists — appends to KV cache without clearing
- `generateOneToken()` per-token JNI overhead: 200 tokens = 200 JNI round trips + 200 mutex locks
- System prompt includes 12 tool descriptions (~200-500 tokens)
- `initSystemPrompt()` pre-caches system prompt but it's immediately destroyed by first `processPromptIncremental()` call

### Metis Review
**Identified Gaps** (addressed):
- Chat template delta formatting correctness: delta must use `formatChat()` with only new messages to ensure correct role tokens
- KV cache desync after trim: use existing `didTrim` flag + new `kvCacheValid` boolean to force full re-decode
- UTF-8 boundary errors in batch: reuse `g_cached_token_chars` logic
- Context overflow during batch: check position per token within batch loop
- Batch generation kills UI streaming during "Thinking...": acceptable tradeoff (agent step flow still works)
- Cancellation during batch: use JNI-accessible `g_cancelled` atomic flag in native code

---

## Work Objectives

### Core Objective
Reduce first-token latency by eliminating redundant KV cache re-processing and reducing JNI overhead in the token generation loop.

### Concrete Deliverables
- `PromptBuilder.buildDeltaPrompt(newMessages)` — formats only new messages with chat template
- `ReactStrategy.kvCacheValid` + `processedHistoryIndex` tracking — manages KV cache state
- `nativeGenerateTokensBatch(maxTokens)` in native-lib.cpp — batch token generation
- Corresponding LlmProvider/LlmService/LlamaBridge additions
- System prompt trimmed by ~30-50% token count
- Benchmark tests measuring first-token latency improvement

### Definition of Done
- [ ] `cd android && ./gradlew test` — all existing + new tests pass
- [ ] `cd android && ./gradlew assembleDebug` — builds successfully
- [ ] Benchmark test logs show second-iteration first-token latency <50% of first iteration
- [ ] All existing ReactStrategyTest tests pass without modification

### Must Have
- KV cache reuse across agent loop iterations (except after trim)
- Batch token generation with proper UTF-8 handling and cancellation support
- System prompt optimization without removing any tool
- Benchmark tests with measurable assertions
- `kvCacheValid` boolean in ReactStrategy — reset after trim, set after successful processPrompt
- `processedHistoryIndex` tracking in PromptBuilder — knows what's in KV cache

### Must NOT Have (Guardrails)
- Do NOT change `generateOneToken()` — keep for backward compatibility
- Do NOT modify `initSystemPrompt()` flow
- Do NOT change chat template logic or model loading params (n_gpu_layers, use_mmap, n_ctx)
- Do NOT modify `trimIfNeeded()` algorithm — only react to its result
- Do NOT remove any tool from the manifest
- Do NOT change tool execution, risk classification, or confirmation gate logic
- Do NOT add GPU layer support, flash attention, or other llama.cpp features
- Do NOT require device/emulator for benchmark tests — unit tests only (Robolectric + MockK)
- Do NOT break existing ReactStrategyTest tests
- AI slop: no excessive comments, no premature abstraction, no generic names

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES
- **Automated tests**: TDD — tests written before implementation
- **Framework**: JUnit + MockK (existing project setup)

### QA Policy
Every task includes agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately — core logic):
├── Task 1: KV cache reuse — PromptBuilder + ReactStrategy [deep]
├── Task 2: Batch token generation — native + Kotlin bridge [deep]
└── Task 3: System prompt optimization — PromptBuilder [quick]

Wave 2 (After Wave 1 — benchmarks + integration):
├── Task 4: Benchmark tests [unspecified-high]
└── Task 5: Integration verification — build + all tests + emulator QA [unspecified-high]

Wave FINAL (After ALL tasks):
├── F1: Plan compliance audit (oracle)
├── F2: Code quality review (unspecified-high)
├── F3: Real manual QA — emulator chat test (unspecified-high)
└── F4: Scope fidelity check (deep)
-> Present results -> Get explicit user okay

Critical Path: Task 1 → Task 4 → Task 5 → FINAL
Parallel Speedup: Tasks 1, 2, 3 run in parallel
Max Concurrent: 3 (Wave 1)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 1 | — | 4, 5 | 1 |
| 2 | — | 4, 5 | 1 |
| 3 | — | 5 | 1 |
| 4 | 1, 2 | 5 | 2 |
| 5 | 1, 2, 3 | F1-F4 | 2 |
| F1-F4 | 5 | — | FINAL |

### Agent Dispatch Summary

- **Wave 1**: 3 — T1 → `deep`, T2 → `deep`, T3 → `quick`
- **Wave 2**: 2 — T4 → `unspecified-high`, T5 → `unspecified-high`
- **FINAL**: 4 — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

- [ ] 1. KV Cache Reuse — PromptBuilder + ReactStrategy

  **What to do**:
  - Add `buildDeltaPrompt(newMessages: List<Pair<String, String>>)` to `PromptBuilder.kt` — formats only new messages with `formatChat()` for continuation
  - Add `processedHistoryIndex: Int` tracking to `PromptBuilder.kt` — tracks how many history entries are in KV cache
  - Add `kvCacheValid: Boolean` to `ReactStrategy.kt` — tracks whether KV cache can be reused
  - Modify `ReactStrategy.runInternal()`:
    - First iteration: `processPromptIncremental(full prompt)` + `setSystemPromptPosition()` (current behavior)
    - Subsequent iterations (kvCacheValid=true): `processPrompt(delta)` with only new messages
    - After `trimIfNeeded()` returns true: reset `kvCacheValid=false`, reset `processedHistoryIndex=0`
  - Write TDD tests first:
    - `PromptBuilderTest.buildDeltaPrompt_onlyFormatsNewMessages()`
    - `PromptBuilderTest.processedHistoryIndex_tracksCorrectly()`
    - `ReactStrategyTest.kvCacheReuse_secondIteration_usesProcessPrompt()`
    - `ReactStrategyTest.kvCacheReuse_afterTrim_fallsBackToIncremental()`
    - `ReactStrategyTest.kvCacheReuse_firstIteration_alwaysUsesIncremental()`

  **Must NOT do**:
  - Do NOT modify native-lib.cpp
  - Do NOT change `initSystemPrompt()` flow
  - Do NOT change `trimIfNeeded()` algorithm
  - Do NOT modify `generateOneToken()` or token generation

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Complex state management across PromptBuilder + ReactStrategy, requires understanding of KV cache semantics
  - **Skills**: [`git-master`]
    - `git-master`: For tracking changes across multiple files

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Tasks 4, 5
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `android/app/src/main/kotlin/com/agent/aios/domain/agent/ReactStrategy.kt:87-247` — `runInternal()` method — THE core loop to modify. Lines 120 (didTrim), 127-133 (processPromptIncremental call), 134-137 (setSystemPromptPosition conditional)
  - `android/app/src/main/kotlin/com/agent/aios/PromptBuilder.kt:39-44` — `buildPromptForInfer()` — current full-prompt formatting, understand how formatChat is called
  - `android/app/src/main/kotlin/com/agent/aios/PromptBuilder.kt:65-92` — `trimIfNeeded()` — calls `resetContext()` at line 87, which invalidates KV cache

  **API/Type References**:
  - `android/app/src/main/kotlin/com/agent/aios/domain/LlmProvider.kt` — `LlmProvider` interface with `processPrompt()`, `processPromptIncremental()`, `formatChat()`, `setSystemPromptPosition()`
  - `android/app/src/main/cpp/native-lib.cpp:131-156` — `processPromptInternal()` — appends to KV cache (does NOT clear). This is what `processPrompt()` calls via JNI. Key: uses `g_current_pos` as start position, appends tokens.
  - `android/app/src/main/cpp/native-lib.cpp:338-366` — `nativeProcessPromptIncremental()` — CLEARS KV cache. This is what we want to AVOID on subsequent iterations.

  **Test References**:
  - `android/app/src/test/java/com/agent/aios/domain/agent/ReactStrategyTest.kt` — existing tests with MockK, `responseQueue` pattern for multi-step mocking
  - `android/app/src/test/java/com/agent/aios/PromptBuilderTest.kt` — if exists, for test patterns

  **WHY Each Reference Matters**:
  - `ReactStrategy.runInternal()` — the exact function to modify. Must understand the iteration loop, didTrim flag, and where processPromptIncremental is called
  - `PromptBuilder.buildPromptForInfer()` — understand how it formats the full conversation to know how to create the delta equivalent
  - `native-lib.cpp processPromptInternal` — confirms it APPENDS to KV (no clear), safe for reuse
  - `native-lib.cpp nativeProcessPromptIncremental` — confirms it CLEARS KV, must be avoided on subsequent iterations
  - `ReactStrategyTest` — test patterns for mocking LlmProvider calls

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Second iteration uses processPrompt (KV cache reuse)
    Tool: Bash (unit test)
    Preconditions: ReactStrategy with mocked LlmProvider
    Steps:
      1. Configure mock: processPromptIncremental returns 0, generateOneToken returns "Action: calculator" then "Args: {\"expr\":\"1+1\"}" then null (EOG)
      2. Second iteration mock: processPrompt returns 0, generateOneToken returns "Answer: 2" then null
      3. Execute agent with prompt "1+1"
      4. Verify: processPromptIncremental called exactly ONCE (first iteration)
      5. Verify: processPrompt called for second iteration with shorter string (delta only)
    Expected Result: processPromptIncremental callCount=1, processPrompt callCount>=1
    Failure Indicators: processPromptIncremental called more than once, or processPrompt not called
    Evidence: .sisyphus/evidence/task-1-kv-reuse-test.txt

  Scenario: After trim, falls back to processPromptIncremental
    Tool: Bash (unit test)
    Preconditions: ReactStrategy with mocked LlmProvider, context usage >80%
    Steps:
      1. Configure mock to return high context usage (>80%)
      2. Execute agent
      3. After trim, verify processPromptIncremental is called again (full re-decode)
    Expected Result: kvCacheValid reset to false after trim, processPromptIncremental called again
    Failure Indicators: processPrompt called after trim (should use incremental instead)
    Evidence: .sisyphus/evidence/task-1-trim-fallback-test.txt
  ```

  **Commit**: YES
  - Message: `feat(agent): reuse KV cache across agent loop iterations`
  - Files: `PromptBuilder.kt`, `ReactStrategy.kt`, `PromptBuilderTest.kt`, `ReactStrategyTest.kt`
  - Pre-commit: `cd android && ./gradlew test`

---

- [ ] 2. Batch Token Generation — native + Kotlin bridge

  **What to do**:
  - Add `nativeGenerateTokensBatch(maxTokens: Int): String?` to `native-lib.cpp`:
    - Holds `g_mutex` for entire batch
    - Per token: check `g_cancelled` atomic flag, check EOG, check context overflow (`shift_context`), decode, accumulate with UTF-8 handling
    - Reuse `g_cached_token_chars` for UTF-8 boundary handling
    - Return full accumulated string (null if cancelled or error)
  - Add `g_cancelled` atomic bool to native-lib.cpp — set by a new `nativeCancelGeneration()` JNI function
  - Add corresponding `external fun` declaration to `LlamaBridge.kt`
  - Add `generateTokensBatch(maxTokens: Int): String?` to `LlmProvider` interface
  - Implement in `LlmService.kt` — calls bridge, emits tokens via callback if desired
  - Modify `ReactStrategy.generateTokens()` to use `llmProvider.generateTokensBatch()` instead of per-token loop
  - Write tests:
    - `LlmServiceTest.generateTokensBatch_returnsFullString()`
    - `ReactStrategyTest.batchGeneration_usedInGenerateTokens()`

  **Must NOT do**:
  - Do NOT remove or modify existing `generateOneToken()`
  - Do NOT change `generateOneToken()` behavior
  - Do NOT modify LlmProvider interface methods that already exist

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Requires C++ (native) + Kotlin (bridge + service + strategy) changes across 5 files, careful mutex and UTF-8 handling
  - **Skills**: [`git-master`]
    - `git-master`: For multi-file change tracking

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Tasks 4, 5
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `android/app/src/main/cpp/native-lib.cpp:368-407` — `nativeGenerateOneToken()` — THE function to model batch version after. Key patterns: mutex lock (370), context overflow check (375), sampling (377), EOG check (379-382), batch decode (384-390), UTF-8 handling via `g_cached_token_chars` (396-406)
  - `android/app/src/main/cpp/native-lib.cpp:102-110` — `create_sampler()` — sampler chain for reference
  - `android/app/src/main/cpp/native-lib.cpp:60-70` — `shift_context()` — context overflow handling, must be called per token in batch

  **API/Type References**:
  - `android/app/src/main/kotlin/com/agent/aios/LlamaBridge.kt` — existing JNI external declarations, add new `external fun nativeGenerateTokensBatch(maxTokens: Int): String?`
  - `android/app/src/main/kotlin/com/agent/aios/domain/LlmProvider.kt` — interface, add `generateTokensBatch(maxTokens: Int): String?`
  - `android/app/src/main/kotlin/com/agent/aios/LlmService.kt:101-114` — existing `generateOneToken()` implementation with token callback, model the batch version similarly
  - `android/app/src/main/kotlin/com/agent/aios/domain/agent/ReactStrategy.kt:249-262` — `generateTokens()` — the function to modify to use batch generation

  **Test References**:
  - `android/app/src/test/java/com/agent/aios/domain/agent/ReactStrategyTest.kt` — existing test patterns

  **WHY Each Reference Matters**:
  - `nativeGenerateOneToken()` — must replicate its logic (mutex, overflow, EOG, UTF-8) in the batch version, but loop internally instead of returning per token
  - `shift_context()` — must call this per token inside batch loop when position approaches context limit
  - `LlmService.generateOneToken()` — shows token callback pattern; batch version should emit accumulated text
  - `ReactStrategy.generateTokens()` — the Kotlin loop to replace; currently calls `generateOneToken()` N times

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Batch generation produces concatenated tokens
    Tool: Bash (unit test)
    Preconditions: MockK LlmProvider with generateTokensBatch returning "Hello World"
    Steps:
      1. Create ReactStrategy with mocked provider
      2. Call generateTokens(100) internally via agent run
      3. Verify returned string matches batch output
    Expected Result: generateTokens returns "Hello World"
    Failure Indicators: Empty string, null, or partial string
    Evidence: .sisyphus/evidence/task-2-batch-gen-test.txt

  Scenario: Cancellation stops batch generation
    Tool: Bash (unit test)
    Preconditions: Mock that simulates long generation
    Steps:
      1. Start agent run in one thread
      2. Cancel after 100ms
      3. Verify generation stopped and partial result returned
    Expected Result: Agent run completes with partial or no response, no hang
    Failure Indicators: Agent run hangs beyond 5s
    Evidence: .sisyphus/evidence/task-2-cancel-test.txt
  ```

  **Commit**: YES
  - Message: `feat(native): add batch token generation to reduce JNI overhead`
  - Files: `native-lib.cpp`, `LlamaBridge.kt`, `LlmProvider.kt`, `LlmService.kt`, `ReactStrategy.kt`
  - Pre-commit: `cd android && ./gradlew test`

---

- [ ] 3. System Prompt Optimization

  **What to do**:
  - Review `PromptBuilder.buildSystemPrompt()` — identify redundant/verbose instructions
  - Reduce system prompt token count by 30-50% without removing any tool or changing tool descriptions
  - Focus on: removing redundant rules, shortening verbose instructions, eliminating duplicate guidance
  - Verify agent still correctly selects and uses all 12 tools after changes
  - Write test: `PromptBuilderTest.systemPrompt_containsAllTools()`
  - Write test: `PromptBuilderTest.systemPrompt_isShorterThanBaseline()` — verify token count reduction

  **Must NOT do**:
  - Do NOT remove any tool from the manifest
  - Do NOT change tool descriptions (they affect tool selection accuracy)
  - Do NOT add new rules or capabilities
  - Do NOT change the "OUTPUT FORMAT" section structure (model depends on it)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single file change, text optimization, no complex logic
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Task 5
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `android/app/src/main/kotlin/com/agent/aios/PromptBuilder.kt:11-31` — `buildSystemPrompt()` — the exact function to optimize. Contains system prompt text with tool manifest, output format rules, and important rules.

  **API/Type References**:
  - `android/app/src/main/kotlin/com/agent/aios/domain/agent/ReactStrategy.kt:322-326` — `getToolManifest()` — generates tool list, do NOT change

  **WHY Each Reference Matters**:
  - `buildSystemPrompt()` — the text to optimize; understand each section's purpose before trimming

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: System prompt contains all tools after optimization
    Tool: Bash (unit test)
    Preconditions: PromptBuilder with mocked LlmProvider
    Steps:
      1. Call buildSystemPrompt() with tool manifest from ReactStrategy
      2. Check that all 12 tool names appear: calculator, timer, device_info, notepad, screen_reader, screen_find, screen_action, app_launcher, notification, contact_search, sms_sender, phone_caller
    Expected Result: All 12 tool names present in prompt
    Failure Indicators: Any tool name missing
    Evidence: .sisyphus/evidence/task-3-tool-presence-test.txt

  Scenario: System prompt is shorter than baseline
    Tool: Bash (unit test)
    Steps:
      1. Build system prompt
      2. Count character length
      3. Verify length < original length (before optimization)
    Expected Result: Prompt is measurably shorter
    Evidence: .sisyphus/evidence/task-3-prompt-length-test.txt
  ```

  **Commit**: YES
  - Message: `perf(agent): reduce system prompt token count`
  - Files: `PromptBuilder.kt`, `PromptBuilderTest.kt`
  - Pre-commit: `cd android && ./gradlew test`

---

- [ ] 4. Benchmark Tests

  **What to do**:
  - Create benchmark test class that measures:
    1. First-token latency: time from `processPromptIncremental` call to first `generateOneToken()` return
    2. Second-iteration prompt processing time (should be <50% of first due to KV reuse)
    3. Tokens/second over 100 tokens
  - Use MockK with timing — mock `processPromptIncremental` to record timestamp, mock `generateOneToken` to return tokens with controlled delay
  - Log results via `Log.i("AIOS-Benchmark", ...)`
  - Assert second-iteration processing <50% of first iteration (validates KV reuse)
  - Assert batch generation is faster than N single calls (validates batch optimization)

  **Must NOT do**:
  - Do NOT require device/emulator — unit tests only (Robolectric + MockK)
  - Do NOT modify production code

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Requires understanding of both KV cache optimization (Task 1) and batch generation (Task 2) to write meaningful benchmarks
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 5
  - **Blocked By**: Tasks 1, 2 (must know final interfaces)

  **References**:

  **Pattern References**:
  - `android/app/src/test/java/com/agent/aios/domain/agent/ReactStrategyTest.kt` — existing test patterns with MockK, response queue
  - `android/app/src/main/kotlin/com/agent/aios/domain/agent/ReactStrategy.kt:87-247` — agent loop to benchmark

  **API/Type References**:
  - Task 1 output: new `buildDeltaPrompt()`, `kvCacheValid`, `processedHistoryIndex`
  - Task 2 output: `generateTokensBatch(maxTokens)`, `nativeGenerateTokensBatch`

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Benchmark validates KV cache reuse improvement
    Tool: Bash (unit test)
    Steps:
      1. Mock processPromptIncremental to record start time and simulate 500ms delay
      2. Mock processPrompt to record start time and simulate 100ms delay
      3. Run agent with tool-use scenario (2 iterations)
      4. Assert second-iteration prompt time < 50% of first
    Expected Result: processPrompt (delta) is significantly faster than processPromptIncremental (full)
    Evidence: .sisyphus/evidence/task-4-benchmark-kv.txt

  Scenario: Benchmark validates batch generation improvement
    Tool: Bash (unit test)
    Steps:
      1. Measure time for 100x generateOneToken() calls vs 1x generateTokensBatch(100)
      2. Assert batch is faster (even with mock overhead)
    Expected Result: Batch call count assertion passes
    Evidence: .sisyphus/evidence/task-4-benchmark-batch.txt
  ```

  **Commit**: YES
  - Message: `test(agent): add benchmark tests for response speed optimization`
  - Files: new test file(s)
  - Pre-commit: `cd android && ./gradlew test`

---

- [ ] 5. Integration Verification — build + tests + emulator QA

  **What to do**:
  - Run `./gradlew assembleDebug` — verify build
  - Run `./gradlew test` — all tests pass (existing + new)
  - Install on emulator and test:
    1. Load Qwen 0.5B model
    2. Send "hello" — verify response appears
    3. Send "1+1은?" — verify tool use (calculator) or direct answer
    4. Check logcat for KV cache reuse messages
    5. Verify no crashes or errors

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (after Task 4)
  - **Blocks**: F1-F4
  - **Blocked By**: Tasks 1, 2, 3, 4

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: Build succeeds
    Tool: Bash
    Steps:
      1. cd android && ./gradlew assembleDebug
    Expected Result: BUILD SUCCESSFUL
    Evidence: .sisyphus/evidence/task-5-build.txt

  Scenario: All tests pass
    Tool: Bash
    Steps:
      1. cd android && ./gradlew test
    Expected Result: BUILD SUCCESSFUL, 0 failures
    Evidence: .sisyphus/evidence/task-5-tests.txt

  Scenario: Emulator chat works
    Tool: Bash (adb)
    Steps:
      1. Install APK on emulator
      2. Load model
      3. Send message, verify response in logcat
    Expected Result: Response generated, no crashes, KV cache reuse visible in logs
    Evidence: .sisyphus/evidence/task-5-emulator.txt
  ```

  **Commit**: NO (verification only)

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists. For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `tsc --noEmit` + linter + tests. Review all changed files for: `as any`/`@ts-ignore`, empty catches, console.log in prod, AI slop.
  Output: `Build [PASS/FAIL] | Lint [PASS/FAIL] | Tests [N pass/N fail] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Start from clean state. Execute EVERY QA scenario from EVERY task. Save evidence.
  Output: `Scenarios [N/N pass] | Integration [N/N] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff. Verify 1:1 — everything in spec was built, nothing beyond spec was built. Check "Must NOT do" compliance.
  Output: `Tasks [N/N compliant] | VERDICT`

---

## Commit Strategy

- **Task 1**: `feat(agent): reuse KV cache across agent loop iterations` — PromptBuilder.kt, ReactStrategy.kt, tests
- **Task 2**: `feat(native): add batch token generation to reduce JNI overhead` — native-lib.cpp, LlamaBridge.kt, LlmProvider.kt, LlmService.kt, ReactStrategy.kt
- **Task 3**: `perf(agent): reduce system prompt token count` — PromptBuilder.kt, PromptBuilderTest.kt
- **Task 4**: `test(agent): add benchmark tests for response speed optimization` — test files
- **Task 5**: No commit (verification only)

---

## Success Criteria

### Verification Commands
```bash
cd android && ./gradlew assembleDebug  # Expected: BUILD SUCCESSFUL
cd android && ./gradlew test           # Expected: BUILD SUCCESSFUL, 0 failures
adb logcat | grep "AIOS-Benchmark"     # Expected: benchmark results logged
```

### Final Checklist
- [ ] Second-iteration first-token latency <50% of first iteration
- [ ] All existing ReactStrategyTest tests pass without modification
- [ ] All 12 tools still present in system prompt
- [ ] `generateOneToken()` not modified (backward compatibility)
- [ ] No GPU/flash attention/advanced llama.cpp features added
