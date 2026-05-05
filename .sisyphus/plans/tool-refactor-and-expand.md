# Tool 전면 리팩토링 + 핵심 4개 신규 Tool 추가

## TL;DR

> **Quick Summary**: 기존 12개 Tool을 일관성 있게 리팩토링하고, 앱 제어 플로우(앱 실행 → 화면 조작)에 필수적인 4개 Tool(SmartWait, AppState, Clipboard, RecentApps)을 TDD로 새로 구현합니다.
>
> **Deliverables**:
> - 기존 12개 Tool 리팩토링 (TAG 로깅, description 개선, 에러 처리 일관화, 테스트 코드)
> - 신규 4개 ExtendedTool 구현 + 테스트
> - ReactStrategy 등록 + RiskClassifier 위험도 분류 추가
> - 전체 테스트 스위트 통과 (`./gradlew test`)
>
> **Estimated Effort**: Medium-Large
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Task 1 (specs) → Task 2-5 (refactor) + Task 6-9 (new tools) → Task 10 (integration) → F1-F4

---

## Context

### Original Request
"앱에서 할 수 있는 tool들을 작성하고 싶다. 앱 관리에 있어서 전반적으로 필요한 것들 추가. 기본적인 설치되어있는 앱 키는 것부터 해서. 유튜브 켜서 한동근 노래 틀어줘 같은 플로우가 동작하도록."

### Interview Summary
**Key Discussions**:
- 기존 Tool은 테스트 전 상태, 아직 실기기 검증 안 됨
- 작업 범위: 전면 리팩토링 + 새 Tool 추가 (기존 유지 X)
- 테스트 전략: TDD (테스트 먼저 작성)
- 신규 Tool: 스마트 대기, 앱 상태 조회, 클립보드, 최근 앱 관리 (핵심 4개)
- 제외: 볼륨/미디어, 화면 밝기, 네트워크 토글, 시스템 상태 상세

**Research Findings**:
- Tool 아키텍처: `AgentTool`(기본) / `ExtendedTool`(Context 필요) 이원화
- ToolContext: `appContext: Context` + `accessibilityService: () -> AIOSAccessibilityService?`
- 등록: `ReactStrategy.kt`의 `basicTools`/`extendedTools` Map
- 위험 분류: `RiskClassifier.classify()` → `ToolRisk` enum (SAFE/LOW/HIGH/CRITICAL)
- 기존 테스트: ReactStrategyTest.kt (794 lines, MockK + Robolectric) — 개별 Tool 테스트 파일은 없음
- 패턴 불일치: TAG/로깅 누락, ScreenFindTool이 ScreenReaderTool.kt에 포함, NotificationTool이 ToolContext 미사용

### Metis Review
**Identified Gaps** (addressed):
- 리팩토링 범위 구체화 필요 → per-tool scope를 Task에 명시
- 신규 Tool 상세 스펙 미정의 → Task 1에서 스펙 정의 후 구현
- Android 10+ 클립보드 제한 → ClipboardTool에 SecurityException 처리 명시
- SmartWait 폴링 구현 → AIOSAccessibilityService 기존 API(findNodesByText) 활용
- RiskClassifier 기존 테스트 회귀 → 각 Task에서 `./gradlew test` 전체 통과 확인

---

## Work Objectives

### Core Objective
기존 Tool의 코드 품질과 일관성을 높이고, 앱 제어 플로우(앱 실행 → 대기 → 화면 조작 → 결과 확인)에 필수적인 4개 Tool을 추가하여 에이전트가 실제로 안드로이드 폰을 제어할 수 있게 합니다.

### Concrete Deliverables
- 12개 기존 Tool 리팩토링 완료 (TAG, 로깅, description, 에러 처리, 테스트)
- `SmartWaitTool.kt` — 화면 요소 대기
- `AppStateTool.kt` — 현재 앱 상태 조회
- `ClipboardTool.kt` — 클립보드 읽기/쓰기
- `RecentAppsTool.kt` — 최근 앱 관리
- `ReactStrategy.kt` 업데이트 (신규 Tool 등록)
- `RiskClassifier.kt` 업데이트 (신규 Tool 위험도)
- 각 Tool별 테스트 파일 생성

### Definition of Done
- [ ] `cd android && ./gradlew test` 전체 통과
- [ ] 기존 ReactStrategyTest.kt 794 lines 모두 통과 (회귀 없음)
- [ ] 각 Tool 테스트 파일: happy path + missing param + unknown action + service unavailable
- [ ] RiskClassifier에 4개 신규 Tool 위험도 분류 추가
- [ ] `strategy.getToolManifest()`에 16개 Tool 모두 포함

### Must Have
- 모든 Tool에 `private val TAG = "AIOS-{ToolName}"` + 에러 시 `Log.e(TAG, ...)` 로깅
- 모든 에러는 `"Error: ..."` 문자열 반환 (예외 throw 금지)
- `action` 비교는 반드시 `.lowercase()` 적용
- 기존 Tool `name` 프로퍼티 변경 금지 (LLM 시스템 프롬프트에 하드코딩됨)
- TDD: 테스트 먼저 작성 → 구현 → 전체 통과 확인

### Must NOT Have (Guardrails)
- **Tool 인터페이스(AgentTool/ExtendedTool) 시그니처 변경 금지**
- **공통 유틸리티 클래스 추출 금지** (BaseTool, ToolHelper 등 — premature abstraction)
- **TimerTool의 Thread.sleep을 coroutine으로 변경 금지** (Dispatchers.IO에서 실행 + interrupt 메커니즘 의도적)
- **ScreenReaderTool과 ScreenFindTool 병합 금지** (별개 Tool, 다른 파일로 분리만)
- **`name` 프로퍼티 변경 금지** (`notification_reader`, `screen_action` 등은 KV cache에 묶여 있음)
- **네트워크 호출 추가 금지** (Privacy-first 원칙)

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** - ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (MockK, Robolectric, Turbine, Truth)
- **Automated tests**: TDD (RED → GREEN → REFACTOR)
- **Framework**: JUnit4 + MockK + Robolectric (기존과 동일)
- **Test runner**: `cd android && ./gradlew test`

### QA Policy
모든 Task는 agent-executed QA scenario를 포함합니다.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Tool 테스트**: `./gradlew test` — 각 Tool의 execute() 메서드 단위 테스트
- **RiskClassifier 테스트**: RiskClassifier().classify() 직접 호출
- **통합 테스트**: ReactStrategy.getToolManifest()에 16개 Tool 포함 확인

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Sequential — Foundation):
└── Task 1: 신규 Tool 스펙 정의 + 테스트 템플릿 작성 [unspecified-high]

Wave 2 (PARALLEL — 기존 Tool 리팩토링, Wave 1 완료 후):
├── Task 2: Basic Tools 리팩토링 (Calculator, Timer, DeviceInfo, NotePad) [unspecified-high]
├── Task 3: Screen Tools 리팩토링 (ScreenReader, ScreenFind 분리, ScreenAction) [unspecified-high]
├── Task 4: Communication Tools 리팩토링 (SmsSender, PhoneCaller, ContactSearch) [unspecified-high]
└── Task 5: System Tools 리팩토링 (AppLauncher, Notification) [unspecified-high]

Wave 3 (PARALLEL — 신규 Tool 구현, Wave 1 완료 후, Wave 2와 독립):
├── Task 6: SmartWaitTool 구현 (TDD) [deep]
├── Task 7: AppStateTool 구현 (TDD) [deep]
├── Task 8: ClipboardTool 구현 (TDD) [unspecified-high]
└── Task 9: RecentAppsTool 구현 (TDD) [unspecified-high]

Wave 4 (Sequential — Integration, Wave 2+3 완료 후):
└── Task 10: ReactStrategy 등록 + RiskClassifier 업데이트 + 전체 테스트 검증 [deep]

Wave FINAL (PARALLEL — Verification, Wave 4 완료 후):
├── F1: Plan Compliance Audit [oracle]
├── F2: Code Quality Review [unspecified-high]
├── F3: Real QA — 테스트 실행 + 빌드 검증 [unspecified-high]
└── F4: Scope Fidelity Check [deep]

Critical Path: Task 1 → Task 2-5 / Task 6-9 → Task 10 → F1-F4
Parallel Speedup: ~60% (Wave 2의 4 Task + Wave 3의 4 Task 동시 실행)
Max Concurrent: 4
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 1 | - | 2,3,4,5,6,7,8,9 | 1 |
| 2 | 1 | 10 | 2 |
| 3 | 1 | 10 | 2 |
| 4 | 1 | 10 | 2 |
| 5 | 1 | 10 | 2 |
| 6 | 1 | 10 | 3 |
| 7 | 1 | 10 | 3 |
| 8 | 1 | 10 | 3 |
| 9 | 1 | 10 | 3 |
| 10 | 2,3,4,5,6,7,8,9 | F1-F4 | 4 |

### Agent Dispatch Summary

- **Wave 1**: 1 task — T1 → `unspecified-high`
- **Wave 2**: 4 tasks — T2-T5 → `unspecified-high`
- **Wave 3**: 4 tasks — T6,T7 → `deep`, T8,T9 → `unspecified-high`
- **Wave 4**: 1 task — T10 → `deep`
- **FINAL**: 4 tasks — F1 → `oracle`, F2-F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

- [ ] 1. 신규 Tool 스펙 정의 + 테스트 템플릿 + 리팩토링 가이드 작성

  **What to do**:
  - 4개 신규 Tool의 상세 스펙을 정의하는 문서를 작성합니다:
    - **SmartWaitTool** (`smart_wait`): `wait_for_text` (특정 텍스트 나올 때까지), `wait_for_idle` (화면 변화 없을 때까지), `wait_for_app` (특정 앱 포그라운드 될 때까지). 폴링 간격 500ms, 기본 타임아웃 10초. AIOSAccessibilityService의 `findNodesByText()`, `getScreenText()`, `getRootNode()` 활용.
    - **AppStateTool** (`app_state`): `current_app` (포그라운드 앱 패키지명+이름), `is_home` (홈 화면 여부), `is_running` (특정 앱 실행 중 여부). `AccessibilityService.getRootInActiveWindow()`의 packageName 활용.
    - **ClipboardTool** (`clipboard`): `copy` (클립보드에 텍스트 저장), `paste` (클립보드에서 읽어서 현재 포커스된 입력 필드에 입력), `read` (클립보드 내용 반환). Android 10+ 읽기 제한 처리 (SecurityException catch).
    - **RecentAppsTool** (`recent_apps`): `list` (최근 앱 목록 — AccessibilityService 전역 액션 "recents" 후 screen_reader로 파싱), `switch_to` (특정 앱으로 전환), `close` (최근 앱에서 swipe away). 전역 액션 + 접근성 서비스 조합.
  - Tool 테스트 템플릿 파일 생성: `android/app/src/test/java/com/agent/aios/tools/ToolTestTemplate.kt` (MockK + Robolectric 기반, 다른 Task에서 복사하여 사용)
  - 리팩토링 가이드 작성: 각 기존 Tool에 적용할 공통 리팩토링 항목 명시
    1. `private val TAG = "AIOS-{ToolName}"` 추가
    2. catch 블록에 `Log.e(TAG, "Error: ${e.message}", e)` 추가
    3. `description` 개선 — LLM이 이해하기 쉬운 명확한 설명 (단, `name`은 변경 금지)
    4. 필수 파라미터 누락 시 명확한 에러 메시지 (`"Error: 'param' required for X action"`)
    5. `action` 비교 시 `.lowercase()` 적용 확인
    6. unknown action 시 사용 가능한 action 목록 안내 (`"Error: Unknown action '$action'. Use X, Y, or Z."`)

  **Must NOT do**:
  - AgentTool/ExtendedTool 인터페이스 변경
  - 기존 Tool 소스 코드 수정 (이 Task는 스펙/템플릿만 생성)
  - 공통 유틸리티 클래스 추출

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 설계/문서화 작업이지만 정확한 스펙 정의가 중요
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (Sequential)
  - **Blocks**: Tasks 2,3,4,5,6,7,8,9
  - **Blocked By**: None

  **References**:
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/ExtendedTool.kt` — ExtendedTool 인터페이스 (execute 메서드 시그니처)
  - `android/app/src/main/kotlin/com/agent/aios/AgentTools.kt` — AgentTool 인터페이스 + Basic Tool 예시
  - `android/app/src/main/kotlin/com/agent/aios/domain/ToolContext.kt` — ToolContext 구조 (appContext, accessibilityService)
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/ScreenActionTool.kt` — 가장 복잡한 ExtendedTool 예시 (canonical pattern)
  - `android/app/src/test/java/com/agent/aios/ReactStrategyTest.kt:1-50` — 기존 테스트 패턴 (MockK, Robolectric, setup/teardown)
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/ScreenReaderTool.kt` — ScreenReaderTool + ScreenFindTool (두 클래스가 한 파일에 있음)
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/AppLauncherTool.kt` — action dispatch 패턴 (when + private handler methods)
  - `android/app/src/main/kotlin/com/agent/aios/domain/agent/RiskClassifier.kt` — 위험 분류 패턴 (tool name → when → action → ToolRisk)
  - `TESTING.md` — TDD 워크플로우, 테스트 범위(P3: Tools), 커버리지 요구사항

  **Acceptance Criteria**:
  - [ ] `.sisyphus/drafts/new-tool-specs.md` 생성 — 4개 Tool의 name, description, parameters, actions, risk levels 정의
  - [ ] `.sisyphus/drafts/tool-test-template.kt` 생성 — 복사하여 사용할 수 있는 테스트 템플릿
  - [ ] `.sisyphus/drafts/refactoring-guide.md` 생성 — per-tool 리팩토링 체크리스트

  **QA Scenarios**:

  ```
  Scenario: 스펙 문서 completeness check
    Tool: Bash
    Preconditions: Task 1 완료
    Steps:
      1. cat .sisyphus/drafts/new-tool-specs.md — 파일 존재 확인
      2. grep -c "smart_wait\|app_state\|clipboard\|recent_apps" — 4개 Tool 모두 정의되었는지 확인 (expected: 4+)
      3. cat .sisyphus/drafts/tool-test-template.kt — 템플릿 파일 존재 확인
      4. cat .sisyphus/drafts/refactoring-guide.md — 가이드 파일 존재 확인
    Expected Result: 3개 파일 모두 존재, 각 파일에 예상 내용 포함
    Evidence: .sisyphus/evidence/task-1-specs-check.txt
  ```

  **Commit**: YES
  - Message: `refactor(tools): define specs and test templates for tool refactoring`
  - Files: `.sisyphus/drafts/new-tool-specs.md`, `.sisyphus/drafts/tool-test-template.kt`, `.sisyphus/drafts/refactoring-guide.md`

- [ ] 2. Basic Tools 리팩토링 (CalculatorTool, TimerTool, DeviceInfoTool, NotePadTool)

  **What to do**:
  - RED: 테스트 파일 생성 `android/app/src/test/java/com/agent/aios/tools/BasicToolsTest.kt`
    - CalculatorTool: `execute_validExpression_returnsResult()`, `execute_emptyExpression_returnsError()`, `execute_invalidChars_returnsError()`, `execute_divisionByZero_returnsInfinity()`
    - TimerTool: `execute_validSeconds_returnsCompleted()`, `execute_zeroSeconds_returnsError()`, `execute_overMaxSeconds_returnsError()`, `execute_interrupted_returnsCancelled()`
    - DeviceInfoTool: `execute_returnsJsonWithRequiredFields()`, `execute_jsonContainsDeviceAndVersion()`
    - NotePadTool: `execute_saveAndGet_notePersisted()`, `execute_list_showsAllNotes()`, `execute_delete_removesNote()`, `execute_unknownAction_returnsError()`, `execute_missingKey_returnsError()`
  - GREEN: 기존 Tool 코드 리팩토링
    - 모든 Tool에 TAG 추가 + catch 블록에 Log.e 추가
    - description 개선 (명확한 action/param 설명)
    - 필수 파라미터 누락 시 명확한 에러 메시지
    - unknown action 시 가능한 action 목록 안내
  - REFACTOR: 코드 정리
  - `cd android && ./gradlew test` 전체 통과 확인

  **Must NOT do**:
  - Tool `name` 변경 (calculator, timer, device_info, notepad 유지)
  - CalculatorTool의 커스텀 expression evaluator를 외부 라이브러리로 교체
  - TimerTool의 Thread.sleep을 coroutine으로 변경
  - 공통 유틸리티 클래스 추출

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 리팩토링 + TDD, 순수 로직이라 복잡하지 않지만 철저한 테스트 필요
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 4, 5)
  - **Blocks**: Task 10
  - **Blocked By**: Task 1

  **References**:
  - `android/app/src/main/kotlin/com/agent/aios/AgentTools.kt` — 리팩토링 대상 (4개 Basic Tool)
  - `android/app/src/test/java/com/agent/aios/ReactStrategyTest.kt:1-50` — 테스트 setup 패턴 (mockkStatic Log, Robolectric)
  - `.sisyphus/drafts/refactoring-guide.md` — 리팩토링 체크리스트 (Task 1에서 생성)
  - `.sisyphus/drafts/tool-test-template.kt` — 테스트 템플릿 (Task 1에서 생성)
  - `TESTING.md:§4` — 커버리지 요구사항 (happy path 1, edge case 1, error path 1 per function)

  **Acceptance Criteria**:
  - [ ] `android/app/src/test/java/com/agent/aios/tools/BasicToolsTest.kt` 존재
  - [ ] `cd android && ./gradlew test` → PASS (기존 + 신규 테스트 모두)
  - [ ] CalculatorTool, TimerTool, DeviceInfoTool, NotePadTool에 TAG + Log.e 추가됨

  **QA Scenarios**:

  ```
  Scenario: Basic Tools 테스트 실행
    Tool: Bash
    Preconditions: Task 2 완료
    Steps:
      1. cd android && ./gradlew test --tests "com.agent.aios.tools.BasicToolsTest" 2>&1 | tail -5
    Expected Result: "BUILD SUCCESSFUL" 또는 "Test run: X tests, X passed, 0 failed"
    Failure Indicators: "BUILD FAILED" 또는 "X failed"
    Evidence: .sisyphus/evidence/task-2-basic-tools-test.txt

  Scenario: TAG 로깅 추가 확인
    Tool: Bash (grep)
    Preconditions: Task 2 완료
    Steps:
      1. grep -n 'private val TAG' android/app/src/main/kotlin/com/agent/aios/AgentTools.kt
    Expected Result: 최소 4개 TAG 정의 (CalculatorTool, TimerTool, DeviceInfoTool, NotePadTool 각각)
    Failure Indicators: TAG가 없는 Tool이 있음
    Evidence: .sisyphus/evidence/task-2-tag-check.txt
  ```

  **Commit**: YES
  - Message: `refactor(tools): add tests and improve basic tools (calculator, timer, device_info, notepad)`
  - Files: `android/app/src/main/kotlin/com/agent/aios/AgentTools.kt`, `android/app/src/test/java/com/agent/aios/tools/BasicToolsTest.kt`
  - Pre-commit: `cd android && ./gradlew test`

- [ ] 3. Screen Tools 리팩토링 (ScreenReader, ScreenFind 분리, ScreenAction)

  **What to do**:
  - RED: 테스트 파일 생성
    - `android/app/src/test/java/com/agent/aios/tools/ScreenReaderToolTest.kt`
      - `execute_serviceAvailable_returnsScreenText()`, `execute_serviceNull_returnsError()`, `execute_emptyScreen_returnsMessage()`
    - `android/app/src/test/java/com/agent/aios/tools/ScreenFindToolTest.kt`
      - `execute_withText_returnsMatchingNodes()`, `execute_emptyText_returnsError()`, `execute_noMatch_returnsMessage()`, `execute_serviceNull_returnsError()`
    - `android/app/src/test/java/com/agent/aios/tools/ScreenActionToolTest.kt`
      - `execute_tapWithText_tapsElement()`, `execute_tapWithCoordinates_tapsAtPosition()`, `execute_tapWithoutParams_returnsError()`
      - `execute_typeWithContent_typesText()`, `execute_typeWithoutContent_returnsError()`
      - `execute_scrollWithDirection_scrolls()`, `execute_swipeWithDirection_swipes()`
      - `execute_globalAction_performsAction()`, `execute_unknownAction_returnsError()`
      - `execute_serviceNull_returnsError()` (모든 action에서)
  - GREEN: 리팩토링
    - **ScreenFindTool을 ScreenReaderTool.kt에서 분리** → `android/app/src/main/kotlin/com/agent/aios/agent/tools/ScreenFindTool.kt` 신규 파일 생성
    - ScreenReaderTool.kt에서 ScreenFindTool class 제거
    - 모든 Tool에 TAG + Log.e 추가 (ScreenActionTool은 이미 TAG 있음, ScreenReaderTool/ScreenFindTool에 추가)
    - description 개선
    - unknown action 에러 메시지 개선
  - REFACTOR: 코드 정리
  - `cd android && ./gradlew test` 전체 통과 확인

  **Must NOT do**:
  - Tool `name` 변경 (screen_reader, screen_find, screen_action 유지)
  - ScreenReaderTool과 ScreenFindTool을 하나로 병합
  - ScreenActionTool의 action handler들을 별도 클래스로 분리
  - AIOSAccessibilityService의 메서드 시그니처 변경

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 파일 분리 + 리팩토링 + TDD, 접근성 서비스 mocking 필요
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 2, 4, 5)
  - **Blocks**: Task 10
  - **Blocked By**: Task 1

  **References**:
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/ScreenReaderTool.kt` — 리팩토링 대상 (ScreenReaderTool + ScreenFindTool 분리 필요)
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/ScreenActionTool.kt` — 리팩토링 대상 (가장 복잡, 179 lines)
  - `android/app/src/main/kotlin/com/agent/aios/domain/ToolContext.kt` — ToolContext 구조
  - `android/app/src/test/java/com/agent/aios/ReactStrategyTest.kt:1-50` — 테스트 setup 패턴 (MockK, Robolectric)
  - `.sisyphus/drafts/refactoring-guide.md` — 리팩토링 체크리스트
  - `.sisyphus/drafts/tool-test-template.kt` — 테스트 템플릿

  **Acceptance Criteria**:
  - [ ] `ScreenFindTool.kt`이 별도 파일로 존재
  - [ ] `ScreenReaderTool.kt`에 ScreenFindTool class 없음
  - [ ] 3개 테스트 파일 존재 (ScreenReaderToolTest, ScreenFindToolTest, ScreenActionToolTest)
  - [ ] `cd android && ./gradlew test` → PASS

  **QA Scenarios**:

  ```
  Scenario: ScreenFindTool 파일 분리 확인
    Tool: Bash
    Preconditions: Task 3 완료
    Steps:
      1. ls -la android/app/src/main/kotlin/com/agent/aios/agent/tools/ScreenFindTool.kt
      2. grep "class ScreenFindTool" android/app/src/main/kotlin/com/agent/aios/agent/tools/ScreenReaderTool.kt
    Expected Result: ScreenFindTool.kt 파일 존재, ScreenReaderTool.kt에 ScreenFindTool class 없음
    Failure Indicators: 파일이 없거나 여전히 ScreenReaderTool.kt에 class가 있음
    Evidence: .sisyphus/evidence/task-3-file-split.txt

  Scenario: Screen Tools 테스트 실행
    Tool: Bash
    Preconditions: Task 3 완료
    Steps:
      1. cd android && ./gradlew test --tests "com.agent.aios.tools.Screen*Test" 2>&1 | tail -5
    Expected Result: "BUILD SUCCESSFUL"
    Evidence: .sisyphus/evidence/task-3-screen-tools-test.txt
  ```

  **Commit**: YES
  - Message: `refactor(tools): add tests and improve screen tools (screen_reader, screen_find, screen_action)`
  - Files: `ScreenReaderTool.kt`, `ScreenFindTool.kt` (new), `ScreenActionTool.kt`, 3 test files
  - Pre-commit: `cd android && ./gradlew test`

- [ ] 4. Communication Tools 리팩토링 (SmsSenderTool, PhoneCallerTool, ContactSearchTool)

  **What to do**:
  - RED: 테스트 파일 생성
    - `android/app/src/test/java/com/agent/aios/tools/SmsSenderToolTest.kt`
      - `execute_send_validSms_returnsSent()` (SmsManager mock), `execute_sendMissingTo_returnsError()`, `execute_sendMissingBody_returnsError()`, `execute_sendNoPermission_returnsError()`, `execute_read_returnsMessages()` (ContentResolver mock), `execute_readNoPermission_returnsError()`, `execute_unknownAction_returnsError()`
    - `android/app/src/test/java/com/agent/aios/tools/PhoneCallerToolTest.kt`
      - `execute_call_withPermission_callsNumber()`, `execute_call_noPermission_returnsError()`, `execute_dial_opensDialer()`, `execute_missingNumber_returnsError()`, `execute_unknownAction_returnsError()`
    - `android/app/src/test/java/com/agent/aios/tools/ContactSearchToolTest.kt`
      - `execute_withQuery_returnsContacts()` (ContentResolver mock), `execute_emptyQuery_returnsError()`, `execute_noMatch_returnsMessage()`, `execute_noPermission_returnsError()`
  - GREEN: 리팩토링
    - 3개 Tool 모두 TAG + Log.e 추가 (현재 전부 누락)
    - description 개선 (LLM이 이해하기 쉽게)
    - unknown action 에러 메시지에 가능한 action 목록 안내
  - REFACTOR: 코드 정리
  - `cd android && ./gradlew test` 전체 통과 확인

  **Must NOT do**:
  - Tool `name` 변경 (sms_sender, phone_caller, contact_search 유지)
  - SmsManager/ContentResolver를 wrapping하는 추상화 레이어 추가
  - 권한 체크 로직 제거 또는 변경

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 안드로이드 프레임워크 mocking(SmsManager, ContentResolver) 필요
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 2, 3, 5)
  - **Blocks**: Task 10
  - **Blocked By**: Task 1

  **References**:
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/SmsSenderTool.kt` — 리팩토링 대상
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/PhoneCallerTool.kt` — 리팩토링 대상
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/ContactSearchTool.kt` — 리팩토링 대상
  - `android/app/src/test/java/com/agent/aios/ReactStrategyTest.kt:1-50` — 테스트 setup 패턴
  - `.sisyphus/drafts/refactoring-guide.md` — 리팩토링 체크리스트
  - `.sisyphus/drafts/tool-test-template.kt` — 테스트 템플릿

  **Acceptance Criteria**:
  - [ ] 3개 테스트 파일 존재 (SmsSenderToolTest, PhoneCallerToolTest, ContactSearchToolTest)
  - [ ] 3개 Tool 모두 TAG + Log.e 추가됨
  - [ ] `cd android && ./gradlew test` → PASS

  **QA Scenarios**:

  ```
  Scenario: Communication Tools 테스트 실행
    Tool: Bash
    Preconditions: Task 4 완료
    Steps:
      1. cd android && ./gradlew test --tests "com.agent.aios.tools.SmsSenderToolTest" 2>&1 | tail -5
      2. cd android && ./gradlew test --tests "com.agent.aios.tools.PhoneCallerToolTest" 2>&1 | tail -5
      3. cd android && ./gradlew test --tests "com.agent.aios.tools.ContactSearchToolTest" 2>&1 | tail -5
    Expected Result: 모두 "BUILD SUCCESSFUL"
    Evidence: .sisyphus/evidence/task-4-comm-tools-test.txt

  Scenario: TAG 로깅 추가 확인
    Tool: Bash
    Preconditions: Task 4 완료
    Steps:
      1. grep -c 'private val TAG' android/app/src/main/kotlin/com/agent/aios/agent/tools/SmsSenderTool.kt android/app/src/main/kotlin/com/agent/aios/agent/tools/PhoneCallerTool.kt android/app/src/main/kotlin/com/agent/aios/agent/tools/ContactSearchTool.kt
    Expected Result: 각 파일에서 1 이상
    Evidence: .sisyphus/evidence/task-4-tag-check.txt
  ```

  **Commit**: YES
  - Message: `refactor(tools): add tests and improve communication tools (sms, phone, contact)`
  - Files: `SmsSenderTool.kt`, `PhoneCallerTool.kt`, `ContactSearchTool.kt`, 3 test files
  - Pre-commit: `cd android && ./gradlew test`

- [ ] 5. System Tools 리팩토링 (AppLauncherTool, NotificationTool)

  **What to do**:
  - RED: 테스트 파일 생성
    - `android/app/src/test/java/com/agent/aios/tools/AppLauncherToolTest.kt`
      - `execute_openApp_validPackage_opensApp()`, `execute_openApp_missingPackage_returnsError()`, `execute_openApp_appNotFound_returnsError()`
      - `execute_openUrl_validUrl_opensBrowser()`, `execute_openUrl_missingUrl_returnsError()`
      - `execute_openSettings_validSetting_opensSettings()`, `execute_openSettings_unknownSetting_returnsError()`
      - `execute_listApps_returnsAppList()`, `execute_listAppsWithQuery_filtersResults()`, `execute_unknownAction_returnsError()`
    - `android/app/src/test/java/com/agent/aios/tools/NotificationToolTest.kt`
      - `execute_returnsNotifications()`, `execute_withMaxCount_limitsResults()`, `execute_noNotifications_returnsMessage()`
  - GREEN: 리팩토링
    - AppLauncherTool: TAG + Log.e 추가 (현재 누락)
    - NotificationTool: TAG + Log.e 추가. **현재 NotificationListener.getRecentNotifications()를 직접 호출하는 static 패턴을, ToolContext를 통해 간접 호출하도록 리팩토링 검토** — 만약 구조 변경이 복잡하면 TAG/로깅만 추가하고 static 패턴은 유지 (테스트는 NotificationListener mockkStatic으로 처리)
    - description 개선
  - REFACTOR: 코드 정리
  - `cd android && ./gradlew test` 전체 통과 확인

  **Must NOT do**:
  - Tool `name` 변경 (app_launcher, notification_reader 유지)
  - NotificationListener 전체 구조 변경 (이 Task 범위 밖)
  - PackageManager wrapping 추상화 레이어 추가

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: PackageManager/NotificationListener mocking 필요, NotificationTool 구조 개선 판단 필요
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 2, 3, 4)
  - **Blocks**: Task 10
  - **Blocked By**: Task 1

  **References**:
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/AppLauncherTool.kt` — 리팩토링 대상
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/NotificationTool.kt` — 리팩토링 대상 (static 패턴)
  - `android/app/src/main/kotlin/com/agent/aios/service/NotificationListener.kt` — NotificationListener 구조 (static companion method)
  - `android/app/src/test/java/com/agent/aios/ReactStrategyTest.kt:1-50` — 테스트 setup 패턴
  - `.sisyphus/drafts/refactoring-guide.md` — 리팩토링 체크리스트
  - `.sisyphus/drafts/tool-test-template.kt` — 테스트 템플릿

  **Acceptance Criteria**:
  - [ ] 2개 테스트 파일 존재 (AppLauncherToolTest, NotificationToolTest)
  - [ ] AppLauncherTool, NotificationTool에 TAG + Log.e 추가됨
  - [ ] `cd android && ./gradlew test` → PASS

  **QA Scenarios**:

  ```
  Scenario: System Tools 테스트 실행
    Tool: Bash
    Preconditions: Task 5 완료
    Steps:
      1. cd android && ./gradlew test --tests "com.agent.aios.tools.AppLauncherToolTest" 2>&1 | tail -5
      2. cd android && ./gradlew test --tests "com.agent.aios.tools.NotificationToolTest" 2>&1 | tail -5
    Expected Result: 모두 "BUILD SUCCESSFUL"
    Evidence: .sisyphus/evidence/task-5-system-tools-test.txt

  Scenario: TAG 로깅 추가 확인
    Tool: Bash
    Preconditions: Task 5 완료
    Steps:
      1. grep -c 'private val TAG' android/app/src/main/kotlin/com/agent/aios/agent/tools/AppLauncherTool.kt android/app/src/main/kotlin/com/agent/aios/agent/tools/NotificationTool.kt
    Expected Result: 각 파일에서 1 이상
    Evidence: .sisyphus/evidence/task-5-tag-check.txt
  ```

  **Commit**: YES
  - Message: `refactor(tools): add tests and improve system tools (app_launcher, notification)`
  - Files: `AppLauncherTool.kt`, `NotificationTool.kt`, 2 test files
  - Pre-commit: `cd android && ./gradlew test`

- [ ] 6. SmartWaitTool 구현 (TDD)

  **What to do**:
  - RED: 테스트 파일 생성 `android/app/src/test/java/com/agent/aios/tools/SmartWaitToolTest.kt`
    - `execute_waitForText_textAppears_returnsSuccess()` — mockService.findNodesByText()가 두 번째 호출에서 노드 반환
    - `execute_waitForText_timeout_returnsError()` — 타임아웃까지 텍스트 안 나타남
    - `execute_waitForText_missingParam_returnsError()` — 'text' 파라미터 누락
    - `execute_waitForIdle_screenStable_returnsSuccess()` — 연속 두 번 getScreenText() 동일
    - `execute_waitForIdle_timeout_returnsError()`
    - `execute_waitForApp_appAppears_returnsSuccess()` — mockService가 특정 packageName 반환
    - `execute_waitForApp_timeout_returnsError()`
    - `execute_unknownAction_returnsError()`
    - `execute_serviceNull_returnsError()`
    - `execute_customTimeout_respected()` — 타임아웃 2초로 설정 시 2초 초과하지 않음
  - GREEN: `android/app/src/main/kotlin/com/agent/aios/agent/tools/SmartWaitTool.kt` 구현
    - ExtendedTool 인터페이스 구현
    - name: `smart_wait`
    - actions: `wait_for_text`, `wait_for_idle`, `wait_for_app`
    - 내부 폴링 루프: 500ms 간격, 기본 타임아웃 10초 (사용자 지정 가능 via `timeout` param)
    - AIOSAccessibilityService의 기존 메서드 활용: `findNodesByText()`, `getScreenText()`, `getRootNode()`
    - TAG: `AIOS-SmartWait`
    - 모든 에러: `"Error: ..."` 문자열 반환
  - REFACTOR: 코드 정리
  - `cd android && ./gradlew test` 전체 통과 확인

  **Must NOT do**:
  - coroutine 도입 (Thread.sleep + interrupt 기반, TimerTool과 동일한 패턴)
  - AIOSAccessibilityService에 새 메서드 추가
  - `name`을 `smart_wait`가 아닌 다른 것으로 설정

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: 폴링 로직 설계, 타임아웃 처리, 인터럽트 처리 등 신중한 설계 필요
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 7, 8, 9)
  - **Blocks**: Task 10
  - **Blocked By**: Task 1

  **References**:
  - `.sisyphus/drafts/new-tool-specs.md` — SmartWaitTool 상세 스펙 (Task 1에서 생성)
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/ExtendedTool.kt` — ExtendedTool 인터페이스
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/ScreenActionTool.kt` — canonical ExtendedTool 패턴 (TAG, try-catch, service null check, action dispatch)
  - `android/app/src/main/kotlin/com/agent/aios/AgentTools.kt:88-109` — TimerTool 패턴 (Thread.sleep + interrupt)
  - `android/app/src/main/kotlin/com/agent/aios/service/AIOSAccessibilityService.kt` — findNodesByText(), getScreenText(), getRootNode() 메서드 확인
  - `android/app/src/main/kotlin/com/agent/aios/domain/ToolContext.kt` — ToolContext 구조

  **Acceptance Criteria**:
  - [ ] `SmartWaitTool.kt` 파일 존재, ExtendedTool 구현
  - [ ] `SmartWaitToolTest.kt` 파일 존재, 최소 8개 테스트
  - [ ] `cd android && ./gradlew test` → PASS (기존 테스트 포함)

  **QA Scenarios**:

  ```
  Scenario: SmartWaitTool 테스트 실행
    Tool: Bash
    Preconditions: Task 6 완료
    Steps:
      1. cd android && ./gradlew test --tests "com.agent.aios.tools.SmartWaitToolTest" 2>&1 | tail -5
    Expected Result: "BUILD SUCCESSFUL", 모든 테스트 통과
    Evidence: .sisyphus/evidence/task-6-smart-wait-test.txt

  Scenario: SmartWaitTool 코드 구조 확인
    Tool: Bash
    Preconditions: Task 6 완료
    Steps:
      1. grep "override val name" android/app/src/main/kotlin/com/agent/aios/agent/tools/SmartWaitTool.kt
      2. grep "private val TAG" android/app/src/main/kotlin/com/agent/aios/agent/tools/SmartWaitTool.kt
      3. grep "class SmartWaitTool" android/app/src/main/kotlin/com/agent/aios/agent/tools/SmartWaitTool.kt
    Expected Result: name = "smart_wait", TAG = "AIOS-SmartWait", "class SmartWaitTool : ExtendedTool"
    Evidence: .sisyphus/evidence/task-6-smart-wait-structure.txt
  ```

  **Commit**: YES
  - Message: `feat(tools): add smart_wait tool with TDD`
  - Files: `SmartWaitTool.kt` (new), `SmartWaitToolTest.kt` (new)
  - Pre-commit: `cd android && ./gradlew test`

- [ ] 7. AppStateTool 구현 (TDD)

  **What to do**:
  - RED: 테스트 파일 생성 `android/app/src/test/java/com/agent/aios/tools/AppStateToolTest.kt`
    - `execute_currentApp_returnsPackageAndName()` — mockService.getRootInActiveWindow()가 특정 packageName 반환
    - `execute_currentApp_noWindow_returnsError()`
    - `execute_isHome_homeScreen_returnsTrue()` — packageName이 launcher
    - `execute_isHome_notHome_returnsFalse()`
    - `execute_isRunning_targetAppRunning_returnsTrue()`
    - `execute_isRunning_targetAppNotRunning_returnsFalse()`
    - `execute_isRunning_missingPackage_returnsError()`
    - `execute_unknownAction_returnsError()`
    - `execute_serviceNull_returnsError()`
  - GREEN: `android/app/src/main/kotlin/com/agent/aios/agent/tools/AppStateTool.kt` 구현
    - ExtendedTool 인터페이스 구현
    - name: `app_state`
    - actions: `current_app`, `is_home`, `is_running`
    - `current_app`: AIOSAccessibilityService.getRootNode()의 packageName/activityName 읽기
    - `is_home`: packageName이 launcher인지 확인 (Intent.CATEGORY_HOME resolve)
    - `is_running`: UsageStatsManager 또는 AccessibilityService로 확인
    - TAG: `AIOS-AppState`
    - 모든 에러: `"Error: ..."` 문자열 반환
  - REFACTOR: 코드 정리
  - `cd android && ./gradlew test` 전체 통과 확인

  **Must NOT do**:
  - UsageStatsManager 권한 요청 추가 (이 Task 범위 밖)
  - AIOSAccessibilityService에 새 메서드 추가
  - `name` 변경

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: 안드로이드 Activity/Package 감지 로직 설계 필요, 접근성 서비스 API 이해 필요
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 6, 8, 9)
  - **Blocks**: Task 10
  - **Blocked By**: Task 1

  **References**:
  - `.sisyphus/drafts/new-tool-specs.md` — AppStateTool 상세 스펙
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/ExtendedTool.kt` — ExtendedTool 인터페이스
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/ScreenActionTool.kt` — canonical ExtendedTool 패턴
  - `android/app/src/main/kotlin/com/agent/aios/service/AIOSAccessibilityService.kt` — getRootNode(), getNodeInfo() 메서드
  - `android/app/src/main/kotlin/com/agent/aios/domain/ToolContext.kt` — ToolContext 구조

  **Acceptance Criteria**:
  - [ ] `AppStateTool.kt` 파일 존재, ExtendedTool 구현
  - [ ] `AppStateToolTest.kt` 파일 존재, 최소 8개 테스트
  - [ ] `cd android && ./gradlew test` → PASS

  **QA Scenarios**:

  ```
  Scenario: AppStateTool 테스트 실행
    Tool: Bash
    Preconditions: Task 7 완료
    Steps:
      1. cd android && ./gradlew test --tests "com.agent.aios.tools.AppStateToolTest" 2>&1 | tail -5
    Expected Result: "BUILD SUCCESSFUL"
    Evidence: .sisyphus/evidence/task-7-app-state-test.txt

  Scenario: AppStateTool 코드 구조 확인
    Tool: Bash
    Preconditions: Task 7 완료
    Steps:
      1. grep "override val name" android/app/src/main/kotlin/com/agent/aios/agent/tools/AppStateTool.kt
      2. grep "class AppStateTool" android/app/src/main/kotlin/com/agent/aios/agent/tools/AppStateTool.kt
    Expected Result: name = "app_state", "class AppStateTool : ExtendedTool"
    Evidence: .sisyphus/evidence/task-7-app-state-structure.txt
  ```

  **Commit**: YES
  - Message: `feat(tools): add app_state tool with TDD`
  - Files: `AppStateTool.kt` (new), `AppStateToolTest.kt` (new)
  - Pre-commit: `cd android && ./gradlew test`

- [ ] 8. ClipboardTool 구현 (TDD)

  **What to do**:
  - RED: 테스트 파일 생성 `android/app/src/test/java/com/agent/aios/tools/ClipboardToolTest.kt`
    - `execute_copy_validText_copiesToClipboard()` — ClipboardManager mock
    - `execute_copy_missingText_returnsError()`
    - `execute_read_hasContent_returnsContent()` — ClipboardManager mock
    - `execute_read_emptyClipboard_returnsMessage()`
    - `execute_read_securityException_returnsError()` — Android 10+ 제한 시뮬레이션
    - `execute_paste_success_pastesContent()` — type 액션으로 입력
    - `execute_paste_noFocusField_returnsError()`
    - `execute_unknownAction_returnsError()`
    - `execute_serviceNull_returnsError()` (paste 액션)
  - GREEN: `android/app/src/main/kotlin/com/agent/aios/agent/tools/ClipboardTool.kt` 구현
    - ExtendedTool 인터페이스 구현
    - name: `clipboard`
    - actions: `copy`, `read`, `paste`
    - `copy`: ClipboardManager.setPrimaryClip() — text 파라미터 필수
    - `read`: ClipboardManager.getPrimaryClip() — Android 10+ SecurityException catch하여 명확한 에러 메시지
    - `paste`: 클립보드 내용을 읽어서 현재 포커스된 EditText에 type (ScreenActionTool의 type 로직과 유사)
    - TAG: `AIOS-Clipboard`
    - 모든 에러: `"Error: ..."` 문자열 반환
  - REFACTOR: 코드 정리
  - `cd android && ./gradlew test` 전체 통과 확인

  **Must NOT do**:
  - Android 10+ 클립보드 제한을 우회하는 hack 추가
  - `name` 변경

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: ClipboardManager mocking, Android 버전 호환성 처리
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 6, 7, 9)
  - **Blocks**: Task 10
  - **Blocked By**: Task 1

  **References**:
  - `.sisyphus/drafts/new-tool-specs.md` — ClipboardTool 상세 스펙
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/ExtendedTool.kt` — ExtendedTool 인터페이스
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/ScreenActionTool.kt:80-108` — type 액션 패턴 (findFocusedEditable, typeText)
  - `android/app/src/main/kotlin/com/agent/aios/domain/ToolContext.kt` — ToolContext 구조 (appContext에서 ClipboardManager 획득)

  **Acceptance Criteria**:
  - [ ] `ClipboardTool.kt` 파일 존재, ExtendedTool 구현
  - [ ] `ClipboardToolTest.kt` 파일 존재, 최소 8개 테스트
  - [ ] `cd android && ./gradlew test` → PASS

  **QA Scenarios**:

  ```
  Scenario: ClipboardTool 테스트 실행
    Tool: Bash
    Preconditions: Task 8 완료
    Steps:
      1. cd android && ./gradlew test --tests "com.agent.aios.tools.ClipboardToolTest" 2>&1 | tail -5
    Expected Result: "BUILD SUCCESSFUL"
    Evidence: .sisyphus/evidence/task-8-clipboard-test.txt

  Scenario: ClipboardTool SecurityException 처리 확인
    Tool: Bash (grep)
    Preconditions: Task 8 완료
    Steps:
      1. grep -n "SecurityException" android/app/src/main/kotlin/com/agent/aios/agent/tools/ClipboardTool.kt
    Expected Result: SecurityException catch 블록 존재
    Evidence: .sisyphus/evidence/task-8-security-exception.txt
  ```

  **Commit**: YES
  - Message: `feat(tools): add clipboard tool with TDD`
  - Files: `ClipboardTool.kt` (new), `ClipboardToolTest.kt` (new)
  - Pre-commit: `cd android && ./gradlew test`

- [ ] 9. RecentAppsTool 구현 (TDD)

  **What to do**:
  - RED: 테스트 파일 생성 `android/app/src/test/java/com/agent/aios/tools/RecentAppsToolTest.kt`
    - `execute_list_returnsRecentApps()` — 전역 액션 "recents" + screen text 파싱 mock
    - `execute_list_emptyRecents_returnsMessage()`
    - `execute_switchTo_validApp_switchesApp()` — tap 액션 mock
    - `execute_switchTo_missingPackage_returnsError()`
    - `execute_close_closesRecentApp()` — swipe 액션 mock
    - `execute_unknownAction_returnsError()`
    - `execute_serviceNull_returnsError()`
  - GREEN: `android/app/src/main/kotlin/com/agent/aios/agent/tools/RecentAppsTool.kt` 구현
    - ExtendedTool 인터페이스 구현
    - name: `recent_apps`
    - actions: `list`, `switch_to`, `close`
    - `list`: AccessibilityService.performGlobalAction(GLOBAL_ACTION_RECENTS) → 대기 → getScreenText() 파싱
    - `switch_to`: 전역 액션 "recents" → 대기 → findNodesByText(packageName) → tap
    - `close`: 전역 액션 "recents" → 대기 → swipe up on target
    - TAG: `AIOS-RecentApps`
    - 모든 에러: `"Error: ..."` 문자열 반환
  - REFACTOR: 코드 정리
  - `cd android && ./gradlew test` 전체 통과 확인

  **Must NOT do**:
  - UsageStatsManager 사용 (AccessibilityService 기반으로 구현)
  - `name` 변경

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: AccessibilityService 전역 액션 + 화면 파싱 조합 로직
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 6, 7, 8)
  - **Blocks**: Task 10
  - **Blocked By**: Task 1

  **References**:
  - `.sisyphus/drafts/new-tool-specs.md` — RecentAppsTool 상세 스펙
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/ExtendedTool.kt` — ExtendedTool 인터페이스
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/ScreenActionTool.kt:42-65` — tap 액션 패턴 (findNodesByText, clickNode)
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/ScreenActionTool.kt:149-168` — swipe 액션 패턴
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/ScreenActionTool.kt:170-178` — global action 패턴 (performGlobalAction)
  - `android/app/src/main/kotlin/com/agent/aios/service/AIOSAccessibilityService.kt` — performGlobalAction(), getScreenText() 메서드

  **Acceptance Criteria**:
  - [ ] `RecentAppsTool.kt` 파일 존재, ExtendedTool 구현
  - [ ] `RecentAppsToolTest.kt` 파일 존재, 최소 6개 테스트
  - [ ] `cd android && ./gradlew test` → PASS

  **QA Scenarios**:

  ```
  Scenario: RecentAppsTool 테스트 실행
    Tool: Bash
    Preconditions: Task 9 완료
    Steps:
      1. cd android && ./gradlew test --tests "com.agent.aios.tools.RecentAppsToolTest" 2>&1 | tail -5
    Expected Result: "BUILD SUCCESSFUL"
    Evidence: .sisyphus/evidence/task-9-recent-apps-test.txt

  Scenario: RecentAppsTool 코드 구조 확인
    Tool: Bash
    Preconditions: Task 9 완료
    Steps:
      1. grep "override val name" android/app/src/main/kotlin/com/agent/aios/agent/tools/RecentAppsTool.kt
      2. grep "class RecentAppsTool" android/app/src/main/kotlin/com/agent/aios/agent/tools/RecentAppsTool.kt
    Expected Result: name = "recent_apps", "class RecentAppsTool : ExtendedTool"
    Evidence: .sisyphus/evidence/task-9-recent-apps-structure.txt
  ```

  **Commit**: YES
  - Message: `feat(tools): add recent_apps tool with TDD`
  - Files: `RecentAppsTool.kt` (new), `RecentAppsToolTest.kt` (new)
  - Pre-commit: `cd android && ./gradlew test`

- [ ] 10. ReactStrategy 등록 + RiskClassifier 업데이트 + 전체 테스트 검증

  **What to do**:
  - ReactStrategy.kt 업데이트:
    - `extendedTools` 맵에 4개 신규 Tool 추가: `SmartWaitTool()`, `AppStateTool()`, `ClipboardTool()`, `RecentAppsTool()`
    - import 문 추가
  - RiskClassifier.kt 업데이트:
    - `smart_wait` → `ToolRisk.LOW` (읽기 전용, 화면 변화 감지만)
    - `app_state` → `ToolRisk.SAFE` (읽기 전용, 상태 조회만)
    - `clipboard` → `when action: "copy" -> HIGH, "read" -> LOW, "paste" -> HIGH, else -> HIGH`
    - `recent_apps` → `when action: "list" -> LOW, "switch_to" -> HIGH, "close" -> HIGH, else -> HIGH`
    - 기존 `else -> ToolRisk.HIGH` 위에 추가
  - ReactStrategyTest.kt에 RiskClassifier 테스트 추가:
    - `classifyRisk_smartWait_isLow()`
    - `classifyRisk_appState_isSafe()`
    - `classifyRisk_clipboard_copy_isHigh()`
    - `classifyRisk_clipboard_read_isLow()`
    - `classifyRisk_clipboard_paste_isHigh()`
    - `classifyRisk_recentApps_list_isLow()`
    - `classifyRisk_recentApps_switchTo_isHigh()`
    - `classifyRisk_recentApps_close_isHigh()`
  - Tool manifest 테스트 추가:
    - `getToolManifest_containsAllSixteenTools()` — 16개 tool name 모두 포함 확인
  - `cd android && ./gradlew test` 전체 통과 확인 (기존 794-line suite 포함)
  - `cd android && ./gradlew assembleDebug` 빌드 성공 확인

  **Must NOT do**:
  - 기존 Tool의 RiskClassifier 분류 변경
  - ReactStrategy의 기존 Tool 등록 제거
  - AgentStrategy 인터페이스 변경

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: 통합 작업, 기존 794-line 테스트 스위트 회귀 없이 통과해야 함
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4 (Sequential)
  - **Blocks**: F1-F4
  - **Blocked By**: Tasks 2,3,4,5,6,7,8,9

  **References**:
  - `android/app/src/main/kotlin/com/agent/aios/domain/agent/ReactStrategy.kt:49-67` — Tool 등록 패턴 (basicTools, extendedTools 맵)
  - `android/app/src/main/kotlin/com/agent/aios/domain/agent/RiskClassifier.kt` — 위험 분류 패턴 (when toolName → when action → ToolRisk)
  - `android/app/src/test/java/com/agent/aios/ReactStrategyTest.kt:215-334` — 기존 RiskClassifier 테스트 (회귀 없어야 함)
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/SmartWaitTool.kt` — Task 6에서 생성
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/AppStateTool.kt` — Task 7에서 생성
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/ClipboardTool.kt` — Task 8에서 생성
  - `android/app/src/main/kotlin/com/agent/aios/agent/tools/RecentAppsTool.kt` — Task 9에서 생성

  **Acceptance Criteria**:
  - [ ] `cd android && ./gradlew test` → ALL TESTS PASS (0 failures)
  - [ ] `cd android && ./gradlew assembleDebug` → BUILD SUCCESSFUL
  - [ ] ReactStrategy.extendedTools에 4개 신규 Tool 등록됨 (기존 8개 + 4개 = 12개)
  - [ ] RiskClassifier에 4개 신규 Tool 분류 추가됨
  - [ ] 기존 ReactStrategyTest.kt 테스트 모두 통과 (회귀 없음)

  **QA Scenarios**:

  ```
  Scenario: 전체 테스트 스위트 실행
    Tool: Bash
    Preconditions: Task 10 완료
    Steps:
      1. cd android && ./gradlew test 2>&1 | tail -10
    Expected Result: "BUILD SUCCESSFUL", "0 failed"
    Failure Indicators: "BUILD FAILED", "N failed"
    Evidence: .sisyphus/evidence/task-10-full-test.txt

  Scenario: 빌드 성공 확인
    Tool: Bash
    Preconditions: Task 10 완료
    Steps:
      1. cd android && ./gradlew assembleDebug 2>&1 | tail -5
    Expected Result: "BUILD SUCCESSFUL"
    Evidence: .sisyphus/evidence/task-10-build.txt

  Scenario: Tool 등록 확인
    Tool: Bash (grep)
    Preconditions: Task 10 완료
    Steps:
      1. grep -c "SmartWaitTool\|AppStateTool\|ClipboardTool\|RecentAppsTool" android/app/src/main/kotlin/com/agent/aios/domain/agent/ReactStrategy.kt
    Expected Result: 4 이상 (import + 등록)
    Evidence: .sisyphus/evidence/task-10-registration.txt

  Scenario: RiskClassifier 업데이트 확인
    Tool: Bash (grep)
    Preconditions: Task 10 완료
    Steps:
      1. grep -E '"smart_wait"|"app_state"|"clipboard"|"recent_apps"' android/app/src/main/kotlin/com/agent/aios/domain/agent/RiskClassifier.kt
    Expected Result: 4개 Tool 모두 분류됨
    Evidence: .sisyphus/evidence/task-10-risk-classifier.txt
  ```

  **Commit**: YES
  - Message: `feat(agent): register new tools and update risk classifier`
  - Files: `ReactStrategy.kt`, `RiskClassifier.kt`, `ReactStrategyTest.kt`
  - Pre-commit: `cd android && ./gradlew test && cd android && ./gradlew assembleDebug`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, check test pass). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `cd android && ./gradlew ktlintCheck` + `cd android && ./gradlew test`. Review all changed files for: `@Suppress("UNCHECKED_CAST")`, empty catches, missing TAG, unused imports, missing Log.e in catch blocks. Check AI slop: excessive comments, over-abstraction, generic names.
  Output: `Build [PASS/FAIL] | Lint [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real QA** — `unspecified-high`
  Run `cd android && ./gradlew test` from clean state. Verify ALL tests pass (existing 794-line suite + new tool tests). Verify `cd android && ./gradlew assembleDebug` succeeds. Check RiskClassifier covers all 16 tools. Check ReactStrategy.getToolManifest() includes all 16 names.
  Output: `Tests [N/N pass] | Build [PASS/FAIL] | Tool count [16/16] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff. Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Verify no tool names were changed. Verify AgentTool/ExtendedTool interfaces unchanged.
  Output: `Tasks [N/N compliant] | Interface [UNCHANGED] | Names [UNCHANGED] | VERDICT`

---

## Commit Strategy

- **Task 1**: `refactor(tools): define specs and test templates for tool refactoring`
- **Task 2**: `refactor(tools): add tests and improve basic tools (calculator, timer, device_info, notepad)`
- **Task 3**: `refactor(tools): add tests and improve screen tools (screen_reader, screen_find, screen_action)`
- **Task 4**: `refactor(tools): add tests and improve communication tools (sms, phone, contact)`
- **Task 5**: `refactor(tools): add tests and improve system tools (app_launcher, notification)`
- **Task 6**: `feat(tools): add smart_wait tool with TDD`
- **Task 7**: `feat(tools): add app_state tool with TDD`
- **Task 8**: `feat(tools): add clipboard tool with TDD`
- **Task 9**: `feat(tools): add recent_apps tool with TDD`
- **Task 10**: `feat(agent): register new tools and update risk classifier`

---

## Success Criteria

### Verification Commands
```bash
cd android && ./gradlew test              # Expected: ALL TESTS PASS (0 failures)
cd android && ./gradlew assembleDebug      # Expected: BUILD SUCCESSFUL
cd android && ./gradlew ktlintCheck        # Expected: 0 violations
```

### Final Checklist
- [ ] All 12 existing tools refactored with consistent TAG, logging, error handling
- [ ] 4 new tools implemented: smart_wait, app_state, clipboard, recent_apps
- [ ] All 16 tools registered in ReactStrategy
- [ ] RiskClassifier covers all 16 tools with appropriate risk levels
- [ ] All tool names unchanged from originals
- [ ] AgentTool/ExtendedTool interfaces unchanged
- [ ] All existing ReactStrategyTest.kt tests still pass (zero regression)
- [ ] New tool test files created with TDD pattern
- [ ] `./gradlew test` passes with ALL tests
- [ ] `./gradlew assembleDebug` succeeds
