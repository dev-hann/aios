# AIOS - AGENTS.md

## 0. AI 작업 수칙 (MANDATORY)

1. **가능하면 병렬로 진행** — 독립적인 작업은 반드시 동시에 실행. 순차 실행 금지
2. **모든 테스트 실행** — 작업 완료 후 `flutter test` (단위 + 위젯) 실행. 실기기가 연결되어 있으면 `flutter test integration_test/` (통합 테스트) + 실기기 APK 설치 테스트까지 진행

---

## 1. 프로젝트 개요

- **Android 온디바이스 AI 에이전트** (Flutter/Dart + llama_cpp_dart)
- ReAct 에이전트 루프로 화면 제어, 앱 실행, 알림 읽기, SMS/전화 등 수행
- Privacy-first: 모든 LLM 추론은 온디바이스에서 실행 (네트워크 호출 없음)
- GitHub Releases 기반 in-app 자동 업데이트 시스템
- Riverpod DI + Clean Architecture + Flutter Widgets

아키텍처 상세 → [docs/architecture.md](docs/architecture.md)

---

## 2. 코딩 규약 (MUST FOLLOW)

### 2.1 Dart 규약

- **Dart 공식 스타일 가이드** 준수: https://dart.dev/guides/language/effective-dart/style
- **2-space 들여쓰기**, 최대 줄 길이 80자
- **Riverpod** 사용 (GetX, Bloc 등 사용 금지)
- **GoRouter** 사용 (Navigator 1.0 사용 금지)
- **Freezed** 사용하여 불변 모델 생성
- **Package by layer** 구조: `domain/`, `data/`, `presentation/`, `core/`

### 2.2 네이밍 규약

| 대상 | 규칙 | 예시 |
|------|------|------|
| Class | PascalCase | `ReactStrategy`, `ScreenActionTool` |
| Function | camelCase | `executeTool()`, `sendMessage()` |
| Variable | camelCase | `currentStrategy`, `toolContext` |
| Constant | lowerCamelCase (Dart 컨벤션) | `maxRetries`, `channelId` |
| Package import | 모두 소문자 | `import 'package:aios/domain/...'` |
| Tool name | snake_case | `screen_action`, `app_launcher` |
| File name | snake_case | `react_strategy.dart`, `screen_action_tool.dart` |
| Test file | `{name}_test.dart` | `react_strategy_test.dart` |
| Test function | `{method}_{scenario}_expectedResult` | `parseResponse_actionWithArgs()` |
| TAG (Logging) | `"AIOS-{Component}"` | `"AIOS-React"`, `"AIOS-LlmRepo"` |
| Widget 함수 | PascalCase | `ChatScreen()`, `InputBar()` |
| Private Widget | PascalCase, 접두사 `_` | `_TopBar()` |
| Provider | camelCase | `llmRepositoryProvider`, `chatScreenProvider` |

### 2.3 DI (Riverpod)

- **모든 Repository**는 `domain/repository/`에 인터페이스(abstract class), `data/`에 구현체
- **@Riverpod(keepAlive: true)**: 싱글톤 (Repository, DataSource, LlmEngine)
- **@riverpod**: 화면 스코프 상태 (Screen-scoped Provider)
- **AsyncNotifier**: 비동기 상태 로딩 (모델 로드, 데이터 조회 등)
- **Provider 참조**: `ref.read(provider)` (콜백 내), `ref.watch(provider)` (build 내)
- **Context 필요 시**: `ProviderScope`에서 `ref`를 통해 접근

### 2.4 State Management

- **UI State**: `freezed` 데이터 클래스 + Riverpod StateNotifier / AsyncNotifier
- **스트리밍 데이터**: `Stream<String>` + `ref.watch(streamProvider)`
- **상태 업데이트**: `state = state.copyWith(...)` 패턴
- **Widget에서 수집**: `ref.watch(provider)` (빌드 내), `ref.listen(provider, ...)` (사이드 이펙트)
- **불변 모델**: Freezed `@freezed` + `const factory` 생성자

### 2.5 Threading

- **CPU 집약 작업 (LLM 추론)**: `LlamaEngine`이 별도 Isolate에서 처리
- **Isolate**: `Isolate.run()` 또는 `compute()` for CPU-bound 작업
- **플랫폼 채널**: MethodChannel / EventChannel (Android 네이티브 연동)
- **UI 업데이트**: Main Isolate (기본값, 별도 처리 불필요)
- **에이전트 실행**: LlmEngine Isolate에서 실행, Stream으로 UI에 전달
- **취소**: 취소 플래그 + StreamController.close() 조합

### 2.6 Error Handling

- **Tool 에러**: `"Error: ${e.toString()}"` 문자열 반환 (예외 throw 금지)
- **Repository 에러**: try-catch + 로그 출력 + 상태 업데이트
- **DataSource 에러**: try-catch + 예외를 도메인 예외로 변환
- **빈 catch 금지**: `catch (_) {}` 최소한 `log` 또는 `print` 출력 필요
- **Empty catch 허용**: 로드 실패 시 자동 복구 불가한 경우만 (예: auto-load model 실패)

### 2.7 Logging

TAG 형식: `"AIOS-{Component}"` (예: AIOS-React, AIOS-LlmRepo, AIOS-Bridge)

로그 레벨:
- **INFO (800)**: 정상 동작
- **WARNING (900)**: 경고/비정상
- **ERROR (1000)**: 에러 (error 포함)

`dart:developer` 사용: `developer.log("message", name: "AIOS-{Component}")`

### 2.8 Tool 개발

- **Basic Tool** (플랫폼 채널 불필요): `AgentTool` 인터페이스 구현 → `agent/tools/`에 추가
- **Extended Tool** (플랫폼 채널 필요): `ExtendedTool` 인터페이스 구현 → `agent/tools/`에 새 파일
- 기존 Tool 코드를 읽고 동일한 패턴으로 작성 (에러 처리, action 디스패치 등)

**Tool 추가 시 필수**:
1. Tool 클래스 구현 (AgentTool 또는 ExtendedTool)
2. `ReactStrategy`의 tools 맵에 등록
3. `RiskClassifier.classify()`에 위험도 분류 추가
4. 테스트 작성 → [TESTING.md](TESTING.md) §P3

**Tool 에러 규칙**:
- **모든 에러는 `"Error: ..."` 문자열 반환** (예외 throw 금지)
- **action은 lowercase 비교**: `json['action'].toString().toLowerCase()`
- **Unknown action**: `"Error: Unknown action '$action'. Use ..."`
- **매개변수 누락**: `"Error: 'param_name' required"`
- **서비스 미연결**: `"Error: Accessibility service not enabled"`

### 2.9 Flutter UI

- **커스텀 색상**: `core/theme/app_colors.dart`의 `AppColors` class 사용 (Material 기본색 직접 사용 지양)
- **Screen 함수**: public, `ConsumerWidget` 또는 `ConsumerStatefulWidget`
- **하위 Widget**: private (`_` 접두사), 파라미터로 데이터 전달
- **Navigation**: GoRouter 사용 (`context.go()`, `context.push()`)
- **상태 호이스팅**: Provider가 단일 상태 소스, Widget은 상태 없음
- **ConsumerWidget 우선**: Riverpod으로 상태 관리 가능하면 ConsumerWidget 사용 (StatefulWidget 사용 금지)

### 2.10 LLM 통합 (llama_cpp_dart)

- **LlamaEngine**: 별도 Isolate에서 실행 (UI 스레드 블로킹 방지)
- **LlmRepository**: LlamaEngine을 래핑하여 비즈니스 로직 제공
- **스트리밍**: `Stream<String>` 통해 토큰 단위 스트리밍
- **모델 관리**: 파일시스템에서 GGUF 파일 스캔
- **KV-cache 지속성**: `saveState` / `loadState`
- **Context shift**: `ContextShiftPolicy.auto`
- 패키지 버전은 `pubspec.yaml` 확인

### 2.11 Database (Drift)

- **Drift** (SQLite) 사용
- **테이블 정의**: `data/datasources/local/tables.dart`에 Dart 클래스로 정의
- **마이그레이션**: `data/datasources/local/database.dart`에서 버전 관리

---

## 3. AI 작업 가이드라인 (MANDATORY)

### 3.1 금지사항 (NEVER)

| 항목 | 설명 |
|------|------|
| `as` 캐스트 (타입 체크 없이) | 타입 안전성 위반. `is` 체크 후 캐스트 또는 올바른 타입 설계 |
| `// ignore:` | 근본 원인 해결 없이 경고 숨기기 금지 |
| 테스트 삭제 | 실패하는 테스트를 삭제해서 통과시키기 금지 |
| 빈 catch 블록 | 최소한 `log` 출력 필요 |
| Tool에서 예외 throw | 반드시 `"Error: ..."` 문자열 반환 |
| StatefulWidget (불필요한 경우) | Riverpod으로 상태 관리 가능하면 ConsumerWidget 사용 |
| GetX, Bloc 등 | Riverpod만 사용 |
| pubspec.yaml 외 의존성 | 의존성 추가 전 반드시 pubspec.yaml 확인 |
| AGENTS.md 무시 변경 | 이 문서의 규칙 위반하는 코드 작성 금지 |

### 3.2 코드 수정 전 체크리스트

- [ ] 수정 대상 파일과 같은 디렉토리의 기존 파일 2-3개 읽어서 패턴 파악
- [ ] DI 구조 파악 (Riverpod Provider, @riverpod, keepAlive)
- [ ] 관련 테스트 파일 확인
- [ ] 수정이 다른 모듈에 미치는 영향 분석
- [ ] 테스트 먼저 작성 (TDD) → [TESTING.md](TESTING.md)

### 3.3 새 파일 생성 규칙

새 파일은 **반드시** 기존 디렉토리 구조를 따름:

| 생성 대상 | 위치 | 예시 |
|-----------|------|------|
| Repository 인터페이스 | `domain/repositories/` | `llm_repository.dart` |
| Repository 구현 | `data/repositories/` | `llm_repository_impl.dart` |
| Domain entity | `domain/entities/` | `agent_models.dart` |
| Agent 전략/로직 | `domain/agent/` | `response_parser.dart` |
| Tool | `agent/tools/` | `screen_action_tool.dart` |
| Screen | `presentation/screens/` | `chat_screen.dart` |
| Widget | `presentation/widgets/` | `input_bar.dart` |
| Provider | `presentation/providers/` | `chat_provider.dart` |
| DataSource | `data/datasources/` | `llm_data_source.dart` |
| Engine Provider | `data/providers/` | `llama_engine_provider.dart` |
| Theme | `core/theme/` | `app_colors.dart` |

### 3.4 코드 리뷰 기준

모든 PR/커밋은 다음 기준을 만족해야 함:

1. **빌드**: `flutter build apk --debug` 성공
2. **분석**: `flutter analyze` 경고 없음
3. **테스트**: `flutter test` (단위 + 위젯) 전체 통과 → [TESTING.md](TESTING.md)
   - 실기기 연결 시: `flutter test integration_test/` (통합 테스트) + APK 설치 후 UI/모델 로드 확인
4. **아키텍처**: [docs/architecture.md](docs/architecture.md) 디렉토리 구조와 Riverpod DI 패턴 준수
5. **에러 처리**: Tool은 문자열 반환, Repository는 try-catch + 상태 업데이트
6. **네이밍**: §2.2 네이밍 규약 준수
7. **실기 테스트**: 에뮬레이터/실기기에서 APK 설치 후 런치·UI·모델 로드 정상 확인

---

## 4. Key Principles

- **LLM is Runtime, not UI** — 모델은 한 번 로드되어 여러 상호작용에 재사용
- **Queue-based sequential inference** — 한 번에 하나의 추론만 실행
- **2-layer architecture** — Dart (UI + logic) → llama_cpp_dart (inference via Isolate)
- **Privacy-first** — 추론을 위한 네트워크 호출 없음, 모든 처리 온디바이스
- **Phone control via Accessibility APIs** — 루트 권한 불필요 (플랫폼 채널 활용)
- **Risk-aware execution** — HIGH/CRITICAL 툴은 사용자 승인 필수
- **Test-Driven Development** — 테스트 먼저 작성 → [TESTING.md](TESTING.md)
- **Clean Architecture** — domain/data/presentation 분리, Riverpod DI

---

## 참고 문서

- **[docs/architecture.md](docs/architecture.md)** — 시스템 아키텍처, 모듈 구조, 데이터 흐름, Agent 시스템, 설계 결정
- **[TESTING.md](TESTING.md)** — TDD 워크플로우, 테스트 범위, 커버리지 요구사항
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — 빌드/개발 명령어, 환경 설정, PR 규칙, 릴리즈
