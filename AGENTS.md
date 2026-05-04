# AIOS - AGENTS.md

## 알림 (Notification)

모든 작업을 완료한 후, 반드시 아래 명령을 실행하여 휴대폰으로 알림을 보냅니다:

```bash
./notify.sh "[작업 요약]"
```

---

## 1. 프로젝트 개요

- **Android 온디바이스 AI 에이전트** (Kotlin + C++/llama.cpp)
- ReAct 에이전트 루프로 화면 제어, 앱 실행, 알림 읽기, SMS/전화 등 수행
- Privacy-first: 모든 LLM 추론은 온디바이스에서 실행 (네트워크 호출 없음)
- GitHub Releases 기반 in-app 자동 업데이트 시스템
- Hilt DI + Clean Architecture + Compose UI

---

## 2. Architecture

Clean Architecture + Hilt DI. 계층 구조:

```
UI (Compose) → ViewModel (StateFlow) → Repository (interface → impl) → Service/Native
                                                                → AgentStrategy → Tools
```

- **domain/**: 비즈니스 로직, 인터페이스, 모델 (외부 의존성 없음)
- **data/**: Repository 구현체, 외부 API 통신
- **ui/**: Compose Screen, ViewModel, Theme
- **service/**: Android Foreground Service, AccessibilityService, NotificationListener
- **agent/tools/**: Extended Tool 구현체 (Context/AccessibilityService 필요)
- **di/**: Hilt 모듈 (@Binds)

Agent 실행 흐름: `LlmRepositoryImpl` → `ReactStrategy` (ReAct 루프) → `ResponseParser` → `RiskClassifier` → `ConfirmationGate` → Tool 실행

Tool 2종류: `AgentTool` (Basic, Context 불필요) / `ExtendedTool` (Context+AccessibilityService 필요)

---

## 3. 코딩 규약 (MUST FOLLOW)

### 3.1 Kotlin 규약

- **Kotlin 공식 코딩 컨벤션** 준수: https://kotlinlang.org/docs/coding-conventions.html
- **4-space 들여쓰기**, 최대 줄 길이 120자
- **StateFlow/SharedFlow** 사용 (LiveData 사용 금지)
- **Coroutines** 사용 (RxJava 사용 금지)
- **Single Activity + Navigation Compose** 패턴
- **Package by layer** 구조: `domain/`, `data/`, `ui/`, `service/`, `agent/`

### 3.2 네이밍 규약

| 대상 | 규칙 | 예시 |
|------|------|------|
| Class | PascalCase | `ReactStrategy`, `ScreenActionTool` |
| Function | camelCase | `executeTool()`, `sendMessage()` |
| Variable | camelCase | `currentStrategy`, `toolContext` |
| Constant | private val, camelCase (프로젝트 컨벤션) | `maxRetries`, `CHANNEL_ID` |
| Package | 모두 소문자, 점으로 구분 | `com.agent.aios.domain.agent` |
| Tool name | snake_case | `screen_action`, `app_launcher` |
| File name | PascalCase, 클래스명과 일치 | `ReactStrategy.kt` |
| Test file | `{ClassName}Test.kt` | `ReactStrategyTest.kt` |
| Test function | `{method}_{scenario}_expectedResult()` | `parseResponse_actionWithArgs()` |
| TAG (Logging) | `"AIOS-{Component}"` | `"AIOS-React"`, `"AIOS-LlmRepo"` |
| Compose 함수 | PascalCase | `ChatScreen()`, `InputBar()` |
| Private Compose | PascalCase, private | `private fun TopBar()` |

### 3.3 DI (Hilt)

- **모든 Repository**는 `domain/repository/`에 인터페이스, `data/` 또는 `settings/`에 구현체
- **Hilt @Binds**로 `di/RepositoryModule.kt`에 바인딩
- **ViewModel**은 `@HiltViewModel` + `@Inject constructor`
- **Singleton**은 `@Singleton` + `@Inject constructor`
- **Context** 필요 시 `@ApplicationContext` 한정자 사용

### 3.4 State Management

- **UI State**: `data class` + `MutableStateFlow` + `val uiState: StateFlow<T> = _uiState.asStateFlow()`
- **스트리밍 데이터**: `MutableSharedFlow` (extraBufferCapacity 설정)
- **상태 업데이트**: `_uiState.value = _uiState.value.copy(...)` 패턴
- **ViewModel에서 수집**: `viewModelScope.launch { flow.collect { } }`
- **Compose에서 수집**: `val uiState by vm.uiState.collectAsState()`

### 3.5 Threading

- **CPU/IO 작업**: `withContext(Dispatchers.IO) { }`
- **공유 가변 상태**: `@Volatile` 또는 `synchronized` 블록
- **UI 업데이트**: Main 디스패처 (기본값)
- **에이전트 실행**: `Dispatchers.IO`에서 실행, `onStep` 콜백으로 UI에 전달
- **취소**: `@Volatile onCancel` 플래그 + `Thread.interrupt()` 조합
- **동기화 대기**: `CountDownLatch` (ConfirmationGate에서 사용)

### 3.6 Error Handling

- **Tool 에러**: `"Error: ${e.message}"` 문자열 반환 (예외 throw 금지)
- **Repository 에러**: try-catch + Log.e + 상태(StateFlow) 업데이트
- **Service 바인딩**: try-catch로 감싸고 DISCONNECTED 상태 전이
- **빈 catch 금지**: `catch (_: Exception) {}` 최소한 Log 출력 필요
- **Empty catch 허용**: 로드 실패 시 자동 복구 불가한 경우만 (예: auto-load model 실패)

### 3.7 Logging

```kotlin
private val TAG = "AIOS-{Component}"

Log.i(TAG, "Service connected")                    // 정상 동작
Log.w(TAG, "Agent timed out after ${elapsed}ms")    // 경고/비정상
Log.e(TAG, "loadModel failed", e)                   // 에러 (exception 포함)
```

TAG 형식: `"AIOS-{Component}"` (예: AIOS-React, AIOS-LlmRepo, AIOS-Bridge)

### 3.8 Tool 개발

- **Basic Tool** (Context 불필요): `AgentTool` 인터페이스 구현 → `AgentTools.kt`에 추가
- **Extended Tool** (Context/AccessibilityService 필요): `ExtendedTool` 인터페이스 구현 → `agent/tools/`에 새 파일
- 기존 Tool 코드를 읽고 동일한 패턴으로 작성 (에러 처리, action 디스패치 등)

#### Tool 추가 시 필수
1. Tool 클래스 구현
2. `ReactStrategy.kt`의 tools 맵에 등록
3. `RiskClassifier.classify()`에 위험도 분류 추가
4. 테스트 작성 (→ [TESTING.md](TESTING.md) §P3)

#### Tool 에러 규칙
- **모든 에러는 `"Error: ..."` 문자열 반환** (예외 throw 금지)
- **action은 lowercase 비교**: `json.optString("action", "").lowercase()`
- **Unknown action**: `"Error: Unknown action '$action'. Use ..."`
- **매개변수 누락**: `"Error: 'param_name' required"`
- **서비스 미연결**: `"Error: Accessibility service not enabled"`

### 3.9 Compose UI

- **커스텀 색상**: `ui/theme/Color.kt`의 `AIOSColors` object 사용 (Material 기본색 금지)
- **Screen 함수**: public, `@Composable`, ViewModel 파라미터
- **하위 컴포넌트**: private, `@Composable`, 파라미터로 데이터 전달
- **Navigation**: `hiltViewModel()`로 ViewModel 획득
- **상태 호이스팅**: ViewModel이 단일 상태 소스, UI는 상태 없음
- **Modifier 파라미터**: 최상위 Composable은 `modifier: Modifier = Modifier` 가질 것

### 3.10 Native Code (C++)

- `native-lib.cpp`에 모든 JNI 함수
- llama.cpp API 직접 사용 (래퍼 금지)
- **전역 상태**: `static` 변수 (g_model, g_ctx, g_vocab 등)
- **JNI 함수명**: `Java_com_agent_aios_LlamaBridge_native{Method}` 형식
- **에러 처리**: null 체크 후 `return JNI_FALSE` 또는 `return nullptr`
- **메모리 해제**: 항상 이전 모델/샘플러/배치 해제 후 새로 할당
- **로깅**: `LOGI`, `LOGW`, `LOGE` 매크로 사용
- **스레드 수**: `sysconf(_SC_NPROCESSORS_ONLN) - 2`, min 2, max 4

---

## 4. AI 작업 가이드라인 (MANDATORY)

### 4.1 금지사항 (NEVER)

| 항목 | 설명 |
|------|------|
| `as any` 캐스트 | 타입 안전성 위반. 올바른 타입 설계로 해결 |
| `@ts-ignore` / `@Suppress("UNCHECKED_CAST")` | 근본 원인 해결 없이 경고 숨기기 금지 |
| 테스트 삭제 | 실패하는 테스트를 삭제해서 통과시키기 금지 |
| 빈 catch 블록 | 최소한 `Log.e` 출력 필요 |
| Tool에서 예외 throw | 반드시 `"Error: ..."` 문자열 반환 |
| LiveData 사용 | StateFlow/SharedFlow 사용 |
| RxJava 사용 | Coroutines 사용 |
| Android 기본 색상 | `AIOSColors` 커스텀 색상 사용 |
| AGENTS.md 무시 변경 | 이 문서의 규칙 위반하는 코드 작성 금지 |

### 4.2 코드 수정 전 체크리스트

- [ ] 수정 대상 파일과 같은 패키지의 기존 파일 2-3개 읽어서 패턴 파악
- [ ] DI 구조 파악 (Hilt @Inject, @Binds, @Singleton)
- [ ] 관련 테스트 파일 확인
- [ ] 수정이 다른 모듈에 미치는 영향 분석
- [ ] 테스트 먼저 작성 (TDD)

### 4.3 Tool 추가 시 체크리스트

- [ ] Tool 클래스 구현 (AgentTool 또는 ExtendedTool)
- [ ] ReactStrategy의 tools 맵에 등록
- [ ] RiskClassifier에 위험도 분류 추가
- [ ] 테스트 작성: RiskClassifier + Tool 동작
- [ ] `cd android && ./gradlew test` 통과 확인

### 4.4 ViewModel 수정 시 체크리스트

- [ ] 상태 전이 테스트 작성 (초기 → 변경 → 결과)
- [ ] 에러/엣지케이스 테스트 작성
- [ ] ViewModel 코드 수정
- [ ] `cd android && ./gradlew test` 전체 통과 확인

### 4.5 Bug Fix 시 체크리스트

- [ ] 버그 재현 테스트 작성 (반드시 실패해야 함)
- [ ] 버그 수정 코드 작성
- [ ] 테스트 통과 확인
- [ ] 기존 테스트 여전히 통과 확인

### 4.6 새 파일 생성 규칙

새 파일은 **반드시** 기존 패키지 구조를 따름:

| 생성 대상 | 위치 | 예시 |
|-----------|------|------|
| Repository 인터페이스 | `domain/repository/` | `LlmRepository.kt` |
| Repository 구현 | `data/` | `LlmRepositoryImpl.kt` |
| Domain model | `domain/model/` | `AgentModels.kt` |
| Agent 전략/로직 | `domain/agent/` | `ResponseParser.kt` |
| Extended Tool | `agent/tools/` | `ScreenActionTool.kt` |
| Basic Tool | `AgentTools.kt`에 추가 | - |
| Compose Screen | `ui/screen/` | `ChatScreen.kt` |
| ViewModel | `ui/viewmodel/` | `ChatViewModel.kt` |
| Service | `service/` | `LlmService.kt` |
| Hilt Module | `di/` | `RepositoryModule.kt` |

### 4.7 코드 리뷰 기준

모든 PR/커밋은 다음 기준을 만족해야 함:

1. **빌드**: `./gradlew assembleDebug` 성공
2. **테스트**: `./gradlew test` 전체 통과
3. **린트**: `./gradlew ktlintCheck` 경고 없음
4. **아키텍처**: 위 패키지 구조와 DI 패턴 준수
5. **에러 처리**: Tool은 문자열 반환, Repository는 try-catch + 상태 업데이트
6. **네이밍**: 위 네이밍 규약 준수
7. **테스트**: TDD (테스트 먼저 작성)

---

## 5. Key Principles

- **LLM is Runtime, not UI** — 모델은 한 번 로드되어 여러 상호작용에 재사용
- **Queue-based sequential inference** — 한 번에 하나의 추론만 실행
- **2-layer architecture** — Kotlin (UI + services) → C++ (inference)
- **Privacy-first** — 추론을 위한 네트워크 호출 없음, 모든 처리 온디바이스
- **Phone control via Accessibility APIs** — 루트 권한 불필요
- **Risk-aware execution** — HIGH/CRITICAL 툴은 사용자 승인 필수
- **Test-Driven Development** — 테스트 먼저 작성 (→ [TESTING.md](TESTING.md))
- **Clean Architecture** — domain/data/ui 분리, Hilt DI

---

## 참고 문서

- **[TESTING.md](TESTING.md)** — TDD 워크플로우, 테스트 범위, 커버리지 요구사항
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — 빌드/개발 명령어, 환경 설정, PR 규칙, 릴리즈
