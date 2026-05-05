# Model Delete Feature - Settings Screen

## TL;DR

> **Quick Summary**: ModelPicker 바텀시트에 모델 삭제 기능을 추가합니다. 앱 내부 저장소(filesDir/models/)의 모델만 삭제 가능하며, 현재 로드된 모델은 자동 release 후 삭제, 삭제 전 항상 확인 다이얼로그를 표시합니다.
> 
> **Deliverables**:
> - ModelRepository에 deleteModel() 메서드 추가 (인터페이스 + 구현)
> - ChatViewModel에 deleteModel() 비즈니스 로직 추가
> - ModelPicker 바텀시트에 삭제 아이콘 + 확인 다이얼로그 UI 추가
> - TDD: ModelRepositoryImplTest, ChatViewModelTest 신규 작성
> 
> **Estimated Effort**: Short
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Task 1 (Test) → Task 2 (Repo) → Task 3 (ViewModel) → Task 4 (ModelPicker) → Task 5 (SettingsScreen)

---

## Context

### Original Request
설정 화면에서 임포트된 모델을 삭제하는 기능이 없어서 추가 필요

### Interview Summary
**Key Discussions**:
- 삭제 버튼 위치: ModelPicker 바텀시트의 각 모델 행에 휴지통 아이콘
- 활성 모델 처리: 삭제 시 자동 release 후 삭제, 확인 다이얼로그 표시
- 확인 다이얼로그: 모든 삭제 시 항상 표시
- 삭제 범위: 앱 내부 모델(filesDir/models/)만 삭제, Downloads 모델은 삭제 불가
- 테스트: TDD 방식 (테스트 먼저 작성)

**Research Findings**:
- ModelRepositoryImpl: 모델 저장 = `context.filesDir/models/`, Downloads는 스캔만
- ModelPicker: ModalBottomSheet, models 리스트, onSelect/onImportFile/onDismiss 콜백
- ChatViewModel: refreshModels(), importModelFromUri() 있음, delete 없음
- LlmRepository: releaseModel() 메서드 존재
- SettingsRepository: lastModelPath 저장/로드, clearLastModelPath() 존재
- DI: RepositoryModule에서 ModelRepository 바인딩 (변경 불필요)
- 테스트: JUnit4 + MockK + Truth + kotlinx-coroutines-test

### Metis Review
**Identified Gaps** (addressed):
- 추론 중 삭제 방지: `isGenerating` 상태에서 삭제 아이콘 비활성화
- `canDelete` 판별: `canDelete: (ModelInfo) -> Boolean` 람다로 ViewModel에서 계산 (ModelInfo 수정 없음)
- `lastModelPath` 정리: 활성 모델 삭제 시 `clearLastModelPath()` 호출
- `isDeleting` 상태 불필요: Linux에서 File.delete()는 unlink로 즉시 완료
- 삭제 후 ModelPicker 유지: 삭제 후 리스트 갱신, 바텀시트는 열린 상태 유지
- AlertDialog 소유권: ModelPicker 내부에서 관리 (SettingsScreen 패턴 따름)

---

## Work Objectives

### Core Objective
ModelPicker에서 앱 내부 모델을 삭제할 수 있는 기능을 TDD로 구현합니다.

### Concrete Deliverables
- `domain/repository/ModelRepository.kt`에 `deleteModel(path: String): Boolean` 추가
- `data/model/ModelRepositoryImpl.kt`에 파일 삭제 로직 구현 (경로 검증 포함)
- `ui/viewmodel/ChatViewModel.kt`에 `deleteModel(model: ModelInfo)` 추가
- `ui/component/ModelPicker.kt`에 삭제 아이콘 + 확인 다이얼로그 추가
- `ui/screen/SettingsScreen.kt`에 onDelete/canDelete 콜백 전달
- `ModelRepositoryImplTest.kt` 신규 테스트 파일
- `ChatViewModelTest.kt` 신규 테스트 파일

### Definition of Done
- [ ] `./gradlew test` 전체 통과
- [ ] `./gradlew assembleDebug` 성공
- [ ] ModelRepositoryImplTest ≥ 3개 테스트 통과
- [ ] ChatViewModelTest ≥ 3개 테스트 통과

### Must Have
- 앱 내부 모델(filesDir/models/)만 삭제 가능
- 삭제 전 항상 확인 AlertDialog 표시
- 활성 모델 삭제 시 자동 release → lastModelPath clear → 삭제 → 리스트 갱신
- 추론 중(isGenerating) 삭제 아이콘 비활성화
- Downloads 경로 모델은 삭제 아이콘 숨김
- TDD: 테스트 먼저 작성 후 구현

### Must NOT Have (Guardrails)
- ModelInfo 데이터 클래스 수정 금지 (isDeletable 필드 추가 등)
- RepositoryModule.kt 수정 금지 (DI 변경 불필요)
- LlmRepository.kt 인터페이스 수정 금지
- ChatUiState에 isDeleting 필드 추가 금지 (불필요)
- 일괄 삭제 / 전체 삭제 기능 금지
- 삭제 undo / 휴지통 기능 금지
- 별도 UseCase 클래스 생성 금지 (ChatViewModel에 직접 구현)
- 스낵바 / 토스트 피드백 금지 (리스트 갱신으로 충분)

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** - ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (JUnit4 + MockK + Truth)
- **Automated tests**: TDD (테스트 먼저 작성)
- **Framework**: JUnit4 + MockK + Truth + kotlinx-coroutines-test

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **단위 테스트**: `./gradlew test` 로 검증
- **빌드**: `./gradlew assembleDebug` 로 검증
- **린트**: `./gradlew ktlintCheck` 로 검증

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately - TDD 테스트 작성):
├── Task 1: ModelRepositoryImplTest 작성 (TDD RED) [quick]
└── Task 2: ChatViewModelTest 작성 (TDD RED) [quick]

Wave 2 (After Wave 1 - Repository + ViewModel 구현):
├── Task 3: ModelRepository 인터페이스 + 구현체에 deleteModel() 추가 [quick]
└── Task 4: ChatViewModel에 deleteModel() 추가 [quick]

Wave 3 (After Wave 2 - UI):
├── Task 5: ModelPicker에 삭제 UI 추가 (아이콘 + 다이얼로그) [visual-engineering]
└── Task 6: SettingsScreen에 onDelete/canDelete 콜백 연결 [quick]

Wave FINAL (After ALL tasks):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real manual QA (unspecified-high)
└── Task F4: Scope fidelity check (deep)
→ Present results → Get explicit user okay

Critical Path: Task 1 → Task 3 → Task 4 → Task 5 → Task 6 → F1-F4
Parallel Speedup: Wave 1 병렬 (2 tasks), Wave 2 병렬 (2 tasks)
Max Concurrent: 2
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 1 | - | 3 | 1 |
| 2 | - | 4 | 1 |
| 3 | 1 | 5 | 2 |
| 4 | 2, 3 | 5 | 2 |
| 5 | 3, 4 | 6 | 3 |
| 6 | 5 | F1-F4 | 3 |
| F1-F4 | 6 | - | FINAL |

### Agent Dispatch Summary

- **Wave 1**: **2** - T1 → `quick`, T2 → `quick`
- **Wave 2**: **2** - T3 → `quick`, T4 → `quick`
- **Wave 3**: **2** - T5 → `visual-engineering`, T6 → `quick`
- **FINAL**: **4** - F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

- [ ] 1. ModelRepositoryImplTest 작성 (TDD RED)

  **What to do**:
  - `android/app/src/test/java/com/agent/aios/ModelRepositoryImplTest.kt` 신규 생성
  - 테스트 케이스 작성:
    1. `deleteModel_internalModel_deletesFile()` — filesDir/models/ 경로의 파일 삭제 성공
    2. `deleteModel_downloadsModel_returnsFalse()` — Downloads 경로 파일은 삭제 거부
    3. `deleteModel_nonExistentFile_returnsFalse()` — 존재하지 않는 파일 처리
    4. `deleteModel_invalidPath_returnsFalse()` — filesDir/models/ 외부 경로 거부
  - 테스트 패턴: `LlmRepositoryImplTest.kt` 참고 (MockK, Truth, mockkStatic Log)
  - `@Before`에서 임시 디렉토리 생성 + mock Context 설정
  - `@After`에서 임시 디렉토리 정리
  - **이 시점에서는 ModelRepositoryImpl에 deleteModel()이 없으므로 컴파일 에러가 나는 것이 정상 (TDD RED)**

  **Must NOT do**:
  - 구현 코드를 먼저 작성하지 않기
  - 통과하는 테스트를 작성하지 않기 (RED 상태여야 함)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 테스트 파일 하나 작성, 패턴이 명확함
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: UI 없음

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 2)
  - **Blocks**: Task 3
  - **Blocked By**: None

  **References**:

  **Pattern References** (existing code to follow):
  - `android/app/src/test/java/com/agent/aios/LlmRepositoryImplTest.kt:1-40` — 테스트 셋업 패턴 (MockK, Truth, StandardTestDispatcher, mockkStatic Log)
  - `android/app/src/test/java/com/agent/aios/ui/viewmodel/UpdateViewModelTest.kt` — ViewModel 테스트 패턴

  **API/Type References**:
  - `android/app/src/main/kotlin/com/agent/aios/domain/repository/ModelRepository.kt` — deleteModel()을 추가할 인터페이스
  - `android/app/src/main/kotlin/com/agent/aios/data/model/ModelRepositoryImpl.kt` — 테스트 대상 클래스
  - `android/app/src/main/kotlin/com/agent/aios/domain/model/Models.kt:ModelInfo` — ModelInfo(name, size, path)

  **WHY Each Reference Matters**:
  - `LlmRepositoryImplTest`: MockK + Truth + Log 모킹 패턴을 그대로 따라야 함
  - `ModelRepositoryImpl`: filesDir/models/ 경로와 Downloads 경로를 어떻게 구분하는지 이해 필요

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: TDD RED 상태 확인
    Tool: Bash
    Preconditions: 테스트 파일만 생성됨 (구현 없음)
    Steps:
      1. ls android/app/src/test/java/com/agent/aios/ModelRepositoryImplTest.kt
      2. 파일 존재 확인
      3. grep -c "@Test" android/app/src/test/java/com/agent/aios/ModelRepositoryImplTest.kt
    Expected Result: 파일 존재 + @Test 어노테이션 ≥ 3개
    Failure Indicators: 파일 없음, @Test < 3
    Evidence: .sisyphus/evidence/task-1-test-file-exists.txt
  ```

  **Commit**: YES (groups with Task 2)
  - Message: `test(model): add deleteModel tests (TDD RED)`
  - Files: `ModelRepositoryImplTest.kt`, `ChatViewModelTest.kt`

- [ ] 2. ChatViewModelTest 작성 (TDD RED)

  **What to do**:
  - `android/app/src/test/java/com/agent/aios/ui/viewmodel/ChatViewModelTest.kt` 신규 생성
  - 테스트 케이스 작성:
    1. `deleteModel_activeModel_releasesAndDeletes()` — 활성 모델 삭제 시 releaseModel + clearLastModelPath + deleteModel 호출 검증
    2. `deleteModel_inactiveModel_deletesWithoutRelease()` — 비활성 모델은 releaseModel 호출 없이 삭제
    3. `deleteModel_duringGeneration_blockedOrHandled()` — isGenerating 중 삭제 시나리오
  - Mock 의존성: LlmRepository, ModelRepository, ConversationRepository, SettingsRepository
  - 테스트 패턴: `UpdateViewModelTest.kt` + `LlmRepositoryImplTest.kt` 패턴
  - **이 시점에서는 ChatViewModel에 deleteModel()이 없으므로 컴파일 에러가 나는 것이 정상 (TDD RED)**

  **Must NOT do**:
  - 구현 코드를 먼저 작성하지 않기
  - ChatUiState를 수정하지 않기

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 테스트 파일 하나 작성, 기존 패턴 따름
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: UI 없음

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1)
  - **Blocks**: Task 4
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `android/app/src/test/java/com/agent/aios/ui/viewmodel/UpdateViewModelTest.kt` — ViewModel 테스트 패턴
  - `android/app/src/test/java/com/agent/aios/LlmRepositoryImplTest.kt:1-40` — MockK 셋업 패턴

  **API/Type References**:
  - `android/app/src/main/kotlin/com/agent/aios/ui/viewmodel/ChatViewModel.kt` — 테스트 대상 ViewModel
  - `android/app/src/main/kotlin/com/agent/aios/domain/repository/SettingsRepository.kt` — lastModelPath, clearLastModelPath() 모킹 필요

  **WHY Each Reference Matters**:
  - `ChatViewModel`: 생성자 파라미터(Context, LlmRepository, ModelRepository, ConversationRepository, SettingsRepository) 파악
  - `SettingsRepository`: lastModelPath Flow와 clearLastModelPath() 시그니처 파악

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: TDD RED 상태 확인
    Tool: Bash
    Preconditions: 테스트 파일만 생성됨 (구현 없음)
    Steps:
      1. ls android/app/src/test/java/com/agent/aios/ui/viewmodel/ChatViewModelTest.kt
      2. 파일 존재 확인
      3. grep -c "@Test" android/app/src/test/java/com/agent/aios/ui/viewmodel/ChatViewModelTest.kt
    Expected Result: 파일 존재 + @Test 어노테이션 ≥ 3개
    Failure Indicators: 파일 없음, @Test < 3
    Evidence: .sisyphus/evidence/task-2-test-file-exists.txt
  ```

  **Commit**: YES (groups with Task 1)
  - Message: `test(model): add deleteModel tests (TDD RED)`
  - Files: `ModelRepositoryImplTest.kt`, `ChatViewModelTest.kt`

- [ ] 3. ModelRepository 인터페이스 + ModelRepositoryImpl에 deleteModel() 추가 (TDD GREEN)

  **What to do**:
  - `ModelRepository.kt` 인터페이스에 `fun deleteModel(path: String): Boolean` 추가
  - `ModelRepositoryImpl.kt`에 구현:
    1. `path`가 `File(context.filesDir, "models").absolutePath`로 시작하는지 검증
    2. 시작하지 않으면 return false (Downloads 등 외부 경로 거부)
    3. `File(path).delete()` 호출 후 결과 반환
    4. 삭제 성공 시 `Log.i(TAG, "Model deleted: $path")`
    5. 삭제 실패 시 `Log.w(TAG, "Failed to delete model: $path")`
  - 테스트 실행: `./gradlew test --tests "*ModelRepositoryImplTest*"` → 모든 테스트 GREEN

  **Must NOT do**:
  - Downloads 경로 파일 삭제하지 않기
  - filesDir/models/ 외부 경로 삭제하지 않기
  - RepositoryModule.kt 수정하지 않기

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 2개 파일에 각각 1-2줄 추가, 로직 단순
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 4)
  - **Blocks**: Task 5
  - **Blocked By**: Task 1

  **References**:

  **Pattern References**:
  - `android/app/src/main/kotlin/com/agent/aios/data/model/ModelRepositoryImpl.kt:22-38` — scanModels()의 filesDir 경로 패턴
  - `android/app/src/main/kotlin/com/agent/aios/data/model/ModelRepositoryImpl.kt:59-74` — importModelFromUri()의 파일 I/O 패턴

  **API/Type References**:
  - `android/app/src/main/kotlin/com/agent/aios/domain/repository/ModelRepository.kt` — 인터페이스 수정 대상

  **WHY Each Reference Matters**:
  - `scanModels()`: filesDir/models/ 경로 구성 방식 확인 (`File(context.filesDir, "models")`)
  - `importModelFromUri()`: 로깅 패턴, 에러 처리 방식 참고

  **Acceptance Criteria**:

  **If TDD (tests enabled):**
  - [ ] Test file exists: `ModelRepositoryImplTest.kt`
  - [ ] `cd android && ./gradlew test --tests "*ModelRepositoryImplTest*"` → PASS (≥4 tests, 0 failures)

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: 단위 테스트 통과 (Happy path)
    Tool: Bash
    Preconditions: Task 1의 테스트 파일 존재, deleteModel() 구현 완료
    Steps:
      1. cd android && ./gradlew test --tests "*ModelRepositoryImplTest*" 2>&1 | tail -20
    Expected Result: "Tests: X passed, 0 failed" 출력
    Failure Indicators: "FAILED", "0 passed", 컴파일 에러
    Evidence: .sisyphus/evidence/task-3-repo-tests-pass.txt

  Scenario: 전체 빌드 성공
    Tool: Bash
    Steps:
      1. cd android && ./gradlew assembleDebug 2>&1 | tail -5
    Expected Result: "BUILD SUCCESSFUL"
    Failure Indicators: "BUILD FAILED"
    Evidence: .sisyphus/evidence/task-3-build-success.txt
  ```

  **Commit**: YES (groups with Task 4)
  - Message: `feat(model): implement deleteModel in repository and viewmodel`
  - Files: `ModelRepository.kt`, `ModelRepositoryImpl.kt`, `ChatViewModel.kt`
  - Pre-commit: `cd android && ./gradlew test`

- [ ] 4. ChatViewModel에 deleteModel() 추가 (TDD GREEN)

  **What to do**:
  - `ChatViewModel.kt`에 `deleteModel(model: ModelInfo)` 함수 추가:
    1. `settingsRepository.lastModelPath.first()`로 현재 활성 모델 경로 확인
    2. 삭제할 모델의 path가 lastModelPath와 일치하면:
       - `llmRepository.releaseModel()` 호출 (모델 해제)
       - `settingsRepository.clearLastModelPath()` 호출
       - `_uiState.isModelLoaded = false` 설정
    3. `withContext(Dispatchers.IO) { modelRepository.deleteModel(model.path) }` 호출
    4. `refreshModels()` 호출하여 UI 갱신
  - `isGenerating` 중에는 삭제를 차단하는 로직 추가 (초기에 `if (_uiState.value.isGenerating) return`)
  - 테스트 실행: `./gradlew test --tests "*ChatViewModelTest*"` → 모든 테스트 GREEN

  **Must NOT do**:
  - ChatUiState에 isDeleting 필드 추가하지 않기
  - LlmRepository 인터페이스 수정하지 않기
  - 새로운 UseCase 클래스 만들지 않기

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: ViewModel에 함수 하나 추가, 기존 패턴 따름
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (Task 3이 먼저 끝나면 바로 시작)
  - **Parallel Group**: Wave 2 (with Task 3, but depends on Task 3's interface)
  - **Blocks**: Task 5
  - **Blocked By**: Task 2, Task 3 (ModelRepository.deleteModel() 인터페이스 필요)

  **References**:

  **Pattern References**:
  - `android/app/src/main/kotlin/com/agent/aios/ui/viewmodel/ChatViewModel.kt:334-349` — importModelFromUri() 패턴 (withContext(Dispatchers.IO), try-catch-finally, refreshModels)
  - `android/app/src/main/kotlin/com/agent/aios/ui/viewmodel/ChatViewModel.kt:186-205` — tryAutoLoadModel()의 lastModelPath 사용 패턴

  **API/Type References**:
  - `android/app/src/main/kotlin/com/agent/aios/domain/repository/SettingsRepository.kt` — lastModelPath Flow, clearLastModelPath()
  - `android/app/src/main/kotlin/com/agent/aios/domain/repository/LlmRepository.kt:24` — releaseModel()
  - `android/app/src/main/kotlin/com/agent/aios/domain/model/Models.kt:11-15` — ModelInfo(name, size, path)

  **WHY Each Reference Matters**:
  - `importModelFromUri()`: IO 디스패처 사용, 상태 관리, refreshModels() 호출 패턴을 동일하게 따라야 함
  - `tryAutoLoadModel()`: settingsRepository.lastModelPath.first() 사용 방식
  - `LlmRepository`: releaseModel() 시그니처

  **Acceptance Criteria**:

  **If TDD (tests enabled):**
  - [ ] Test file exists: `ChatViewModelTest.kt`
  - [ ] `cd android && ./gradlew test --tests "*ChatViewModelTest*"` → PASS (≥3 tests, 0 failures)

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: ViewModel 단위 테스트 통과
    Tool: Bash
    Preconditions: deleteModel() 구현 완료
    Steps:
      1. cd android && ./gradlew test --tests "*ChatViewModelTest*" 2>&1 | tail -20
    Expected Result: "Tests: X passed, 0 failed"
    Failure Indicators: "FAILED", "0 passed"
    Evidence: .sisyphus/evidence/task-4-vm-tests-pass.txt

  Scenario: 전체 테스트 통과
    Tool: Bash
    Steps:
      1. cd android && ./gradlew test 2>&1 | tail -20
    Expected Result: All tests pass, 0 failures
    Failure Indicators: Any test failure
    Evidence: .sisyphus/evidence/task-4-all-tests-pass.txt
  ```

  **Commit**: YES (groups with Task 3)
  - Message: `feat(model): implement deleteModel in repository and viewmodel`
  - Files: `ModelRepository.kt`, `ModelRepositoryImpl.kt`, `ChatViewModel.kt`
  - Pre-commit: `cd android && ./gradlew test`

- [ ] 5. ModelPicker에 삭제 UI 추가 (아이콘 + 확인 다이얼로그)

  **What to do**:
  - `ModelPicker.kt` 수정:
    1. 함수 시그니처에 새 파라미터 추가:
       - `onDelete: (ModelInfo) -> Unit = {}` — 삭제 실행 콜백
       - `canDelete: (ModelInfo) -> Boolean = { true }` — 삭제 가능 여부 판별 람다
       - `isGenerating: Boolean = false` — 추론 중 상태
    2. 각 모델 Row에 삭제 아이콘 추가:
       - `canDelete(model)`가 true일 때만 `Icons.Filled.Delete` 아이콘 표시
       - `isGenerating`이 true면 아이콘 비활성화 (alpha = 0.3f, clickable 없음)
       - 아이콘 색상: `AIOSColors.StatusError`
       - 위치: Row의 오른쪽, 활성 모델 표시(indicator) 앞
    3. 내부 상태로 확인 다이얼로그 관리:
       - `var showDeleteConfirm by remember { mutableStateOf<ModelInfo?>(null) }`
       - 삭제 아이콘 클릭 → `showDeleteConfirm = model`
       - AlertDialog 표시:
         - 제목: "Delete Model"
         - 내용: "Delete \"${model.name}\"? This cannot be undone."
         - 확인 버튼: "Delete" (AIOSColors.StatusError 색상)
         - 취소 버튼: "Cancel"
         - 확인 클릭 → `onDelete(model)`, `showDeleteConfirm = null`
         - containerColor: `AIOSColors.Surface` (SettingsScreen 패턴)
    4. 삭제 후 ModelPicker는 열린 상태 유지 (onDismiss 호출 안 함)

  **Must NOT do**:
  - ModelInfo 데이터 클래스 수정하지 않기
  - Context를 ModelPicker에 주입하지 않기 (canDelete 람다로 처리)
  - 별도 ConfirmDialog 컴포넌트 추출하지 않기 (인라인)
  - 스낵바/토스트 표시하지 않기

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Compose UI 컴포넌트 수정, 아이콘/다이얼로그/상태관리
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (sequential with Task 6)
  - **Blocks**: Task 6
  - **Blocked By**: Task 3, Task 4

  **References**:

  **Pattern References**:
  - `android/app/src/main/kotlin/com/agent/aios/ui/component/ModelPicker.kt:86-122` — 현재 모델 Row 레이아웃 (클릭, 활성 표시, 텍스트 배치)
  - `android/app/src/main/kotlin/com/agent/aios/ui/screen/SettingsScreen.kt:597-633` — AlertDialog 패턴 (containerColor, 버튼 스타일)
  - `android/app/src/main/kotlin/com/agent/aios/ui/theme/AIOSColors.kt` — AIOSColors.StatusError 색상

  **API/Type References**:
  - `android/app/src/main/kotlin/com/agent/aios/domain/model/Models.kt:11-15` — ModelInfo(name, size, path)

  **External References**:
  - Material Icons: `Icons.Filled.Delete` — `androidx.compose.material.icons.filled.Delete`

  **WHY Each Reference Matters**:
  - `ModelPicker.kt:86-122`: 기존 Row 레이아웃에 삭제 아이콘을 어떻게 끼워넣을지 파악
  - `SettingsScreen.kt:597-633`: AlertDialog의 정확한 스타일링 패턴 (containerColor, 버튼 배치)
  - `AIOSColors`: 프로젝트 커스텀 색상 규칙 준수

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: ModelPicker 빌드 성공 + 시그니처 확인
    Tool: Bash
    Preconditions: ModelPicker 수정 완료
    Steps:
      1. cd android && ./gradlew assembleDebug 2>&1 | tail -5
      2. grep "onDelete" android/app/src/main/kotlin/com/agent/aios/ui/component/ModelPicker.kt
      3. grep "canDelete" android/app/src/main/kotlin/com/agent/aios/ui/component/ModelPicker.kt
      4. grep "AlertDialog" android/app/src/main/kotlin/com/agent/aios/ui/component/ModelPicker.kt
      5. grep "Icons.Filled.Delete" android/app/src/main/kotlin/com/agent/aios/ui/component/ModelPicker.kt
    Expected Result: BUILD SUCCESSFUL + onDelete/canDelete/AlertDialog/Delete 아이콘 모두 존재
    Failure Indicators: BUILD FAILED, 키워드 누락
    Evidence: .sisyphus/evidence/task-5-modelpicker-ui.txt

  Scenario: ModelInfo 수정 없음 확인
    Tool: Bash
    Steps:
      1. grep "isDeletable\|canDelete\|source" android/app/src/main/kotlin/com/agent/aios/domain/model/Models.kt
    Expected Result: 검색 결과 없음 (ModelInfo 수정 안 됨)
    Failure Indicators: 새 필드 발견
    Evidence: .sisyphus/evidence/task-5-no-modelinfo-change.txt
  ```

  **Commit**: NO (groups with Task 6)
  - Files: `ModelPicker.kt`

- [ ] 6. SettingsScreen에 onDelete/canDelete 콜백 연결

  **What to do**:
  - `SettingsScreen.kt` 수정:
    1. ModelPicker 호출부(173-186행)에 새 파라미터 추가:
       ```kotlin
       onDelete = { model -> chatViewModel.deleteModel(model) },
       canDelete = { model ->
           // filesDir/models/ 경로의 모델만 삭제 가능
                           model.path.startsWith(appContext.filesDir.absolutePath)
       },
       isGenerating = uiState.isGenerating,
       ```
    2. `appContext`는 이미 `val context = LocalContext.current`에서 얻을 수 있으므로 별도 주입 불필요
    3. `context.filesDir.absolutePath`를 사용하여 내부 저장소 경로 확인

  **Must NOT do**:
  - ModelPicker의 기존 동작(onSelect, onImportFile, onDismiss) 변경하지 않기
  - 새로운 상태 변수 추가하지 않기
  - SettingsScreen의 다른 섹션 수정하지 않기

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 기존 함수 호출에 파라미터 3개 추가하는 단순 작업
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (after Task 5)
  - **Blocks**: F1-F4
  - **Blocked By**: Task 5

  **References**:

  **Pattern References**:
  - `android/app/src/main/kotlin/com/agent/aios/ui/screen/SettingsScreen.kt:172-187` — 현재 ModelPicker 호출부
  - `android/app/src/main/kotlin/com/agent/aios/ui/screen/SettingsScreen.kt:100` — `val context = LocalContext.current`

  **API/Type References**:
  - `android/app/src/main/kotlin/com/agent/aios/ui/viewmodel/ChatViewModel.kt` — deleteModel(model: ModelInfo) 시그니처

  **WHY Each Reference Matters**:
  - ModelPicker 호출부: 어떤 파라미터를 어디에 추가할지 정확한 위치
  - context: filesDir 경로를 얻기 위한 Context 접근 방식

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: 전체 빌드 + 테스트 통과
    Tool: Bash
    Preconditions: 모든 구현 완료
    Steps:
      1. cd android && ./gradlew assembleDebug 2>&1 | tail -5
      2. cd android && ./gradlew test 2>&1 | tail -20
    Expected Result: BUILD SUCCESSFUL + All tests pass
    Failure Indicators: BUILD FAILED, test failures
    Evidence: .sisyphus/evidence/task-6-final-build.txt

  Scenario: RepositoryModule 미변경 확인
    Tool: Bash
    Steps:
      1. git diff HEAD -- android/app/src/main/kotlin/com/agent/aios/di/RepositoryModule.kt
    Expected Result: 빈 출력 (변경 없음)
    Failure Indicators: 변경 내용 출력
    Evidence: .sisyphus/evidence/task-6-no-di-change.txt

  Scenario: LlmRepository 인터페이스 미변경 확인
    Tool: Bash
    Steps:
      1. git diff HEAD -- android/app/src/main/kotlin/com/agent/aios/domain/repository/LlmRepository.kt
    Expected Result: 빈 출력 (변경 없음)
    Failure Indicators: 변경 내용 출력
    Evidence: .sisyphus/evidence/task-6-no-llm-repo-change.txt
  ```

  **Commit**: YES (groups with Task 5)
  - Message: `feat(ui): add model delete button to ModelPicker`
  - Files: `ModelPicker.kt`, `SettingsScreen.kt`
  - Pre-commit: `cd android && ./gradlew test && ./gradlew assembleDebug`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `./gradlew assembleDebug` + `./gradlew test` + `./gradlew ktlintCheck`. Review all changed files for: `as any`, empty catches, console.log, unused imports. Check AI slop: excessive comments, over-abstraction, generic names. Verify TDD: tests exist for ModelRepositoryImpl.deleteModel() and ChatViewModel.deleteModel().
  Output: `Build [PASS/FAIL] | Tests [N pass/N fail] | Lint [PASS/FAIL] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Start from clean state. Execute EVERY QA scenario from EVERY task — follow exact steps, capture evidence. Test cross-task integration. Test edge cases: empty state, deleting active model, deleting during generation. Save to `.sisyphus/evidence/final-qa/`.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff. Verify 1:1 — everything in spec was built, nothing beyond spec. Check "Must NOT do" compliance. Detect cross-task contamination. Flag unaccounted changes. Specifically verify: ModelInfo NOT modified, RepositoryModule NOT modified, LlmRepository NOT modified, ChatUiState isDeleting NOT added.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

- **Wave 1**: `test(model): add deleteModel tests (TDD RED)` - ModelRepositoryImplTest.kt, ChatViewModelTest.kt
- **Wave 2**: `feat(model): implement deleteModel in repository and viewmodel` - ModelRepository.kt, ModelRepositoryImpl.kt, ChatViewModel.kt
- **Wave 3**: `feat(ui): add model delete button to ModelPicker` - ModelPicker.kt, SettingsScreen.kt

---

## Success Criteria

### Verification Commands
```bash
cd android && ./gradlew test                                          # Expected: All tests pass
cd android && ./gradlew test --tests "*ModelRepositoryImplTest*"      # Expected: ≥3 tests pass
cd android && ./gradlew test --tests "*ChatViewModelTest*"            # Expected: ≥3 tests pass
cd android && ./gradlew assembleDebug                                  # Expected: BUILD SUCCESSFUL
cd android && ./gradlew ktlintCheck                                    # Expected: No violations
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All tests pass
- [ ] TDD verified: tests written before implementation
