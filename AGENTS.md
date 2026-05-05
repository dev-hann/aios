# AIOS - AGENTS.md

## 알림 (Notification)

모든 작업을 완료한 후, 반드시 아래 명령을 실행하여 휴대폰으로 알림을 보냅니다:

```bash
./notify.sh "[작업 요약]"
```

---

## 1. 프로젝트 개요

- **Android 온디바이스 AI 에이전트** (Flutter/Dart + llama_cpp_dart)
- ReAct 에이전트 루프로 화면 제어, 앱 실행, 알림 읽기, SMS/전화 등 수행
- Privacy-first: 모든 LLM 추론은 온디바이스에서 실행 (네트워크 호출 없음)
- GitHub Releases 기반 in-app 자동 업데이트 시스템
- Riverpod DI + Clean Architecture + Flutter Widgets

### Kotlin → Flutter 마이그레이션 주요 변경

| 영역 | 기존 (Kotlin) | 변경 (Flutter) |
|------|---------------|----------------|
| DI | Hilt (@Binds, @Inject) | Riverpod (@riverpod, Provider) |
| 상태 관리 | StateFlow / SharedFlow | Riverpod StateNotifier / AsyncNotifier |
| UI | Jetpack Compose | Flutter Widgets |
| 라우팅 | Navigation Compose | GoRouter |
| LLM 추론 | llama.cpp JNI + C++ (~1500줄) | llama_cpp_dart 0.9.0-dev.6 (~20줄) |
| DB | JSON 파일 | Drift (SQLite) |
| 스레딩 | Coroutines + Foreground Service | Dart Isolate (LlamaEngine 처리) |
| 테스트 | JUnit + Espresso | flutter_test + integration_test |

---

## 2. Architecture

Clean Architecture + Riverpod DI. 계층 구조:

```
Presentation (Widgets) → Provider (Riverpod) → Repository (interface → impl) → DataSource/Native
                                                                        → AgentStrategy → Tools
```

### 디렉토리 구조

```
lib/
├── domain/           # entities, repositories (interfaces), usecases
├── data/             # repositories (impl), datasources, models, providers
├── presentation/     # screens, widgets, providers (Riverpod)
├── core/             # theme, constants, utils
└── main.dart

test/                 # 단위 테스트, 위젯 테스트
integration_test/     # 통합 테스트 (실기기 필요)
```

- **domain/**: 비즈니스 로직, 인터페이스, 엔티티 (외부 의존성 없음)
- **data/**: Repository 구현체, DataSource, 외부 API 통신, 모델 변환
- **presentation/**: Flutter Screen, Widget, Riverpod Provider
- **core/**: 테마, 상수, 유틸리티

Agent 실행 흐름: `LlmRepositoryImpl` → `ReactStrategy` (ReAct 루프) → `ResponseParser` → `RiskClassifier` → `ConfirmationGate` → Tool 실행

Tool 2종류: `AgentTool` (Basic, Context 불필요) / `ExtendedTool` (플랫폼 채널 필요)

---

## 3. 코딩 규약 (MUST FOLLOW)

### 3.1 Dart 규약

- **Dart 공식 스타일 가이드** 준수: https://dart.dev/guides/language/effective-dart/style
- **2-space 들여쓰기**, 최대 줄 길이 80자
- **Riverpod** 사용 (GetX, Bloc 등 사용 금지)
- **GoRouter** 사용 (Navigator 1.0 사용 금지)
- **Freezed** 사용하여 불변 모델 생성
- **Package by layer** 구조: `domain/`, `data/`, `presentation/`, `core/`

### 3.2 네이밍 규약

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

### 3.3 DI (Riverpod)

- **모든 Repository**는 `domain/repository/`에 인터페이스(abstract class), `data/`에 구현체
- **@Riverpod(keepAlive: true)**: 싱글톤 (Repository, DataSource, LlmEngine)
- **@riverpod**: 화면 스코프 상태 (Screen-scoped Provider)
- **AsyncNotifier**: 비동기 상태 로딩 (모델 로드, 데이터 조회 등)
- **Provider 참조**: `ref.read(provider)` (콜백 내), `ref.watch(provider)` (build 내)
- **Context 필요 시**: `ProviderScope`에서 `ref`를 통해 접근

```dart
@Riverpod(keepAlive: true)
LlmRepository llmRepository(LlmRepositoryRef ref) {
  return LlmRepositoryImpl(ref.watch(llmDataSourceProvider));
}

@riverpod
class ChatScreen extends _$ChatScreen {
  @override
  Future<ChatState> build() async {
    return const ChatState.initial();
  }
}
```

### 3.4 State Management

- **UI State**: `freezed` 데이터 클래스 + Riverpod AsyncNotifier
- **스트리밍 데이터**: `Stream<GenerationEvent>` + `ref.watch(streamProvider)`
- **상태 업데이트**: `state = AsyncData(state.value!.copyWith(...))` 패턴
- **Widget에서 수집**: `ref.watch(provider)` (빌드 내), `ref.listen(provider, ...)` (사이드 이펙트)
- **불변 모델**: Freezed `@freezed` + `const factory` 생성자

```dart
@freezed
class ChatState with _$ChatState {
  const factory ChatState.initial() = _Initial;
  const factory ChatState.loading() = _Loading;
  const factory ChatState.loaded({
    required List<ChatMessage> messages,
  }) = _Loaded;
  const factory ChatState.error(String message) = _Error;
}
```

### 3.5 Threading

- **CPU 집약 작업 (LLM 추론)**: `LlamaEngine`이 별도 Isolate에서 처리
- **Isolate**: `Isolate.run()` 또는 `compute()` for CPU-bound 작업
- **플랫폼 채널**: MethodChannel / EventChannel (Android 네이티브 연동)
- **UI 업데이트**: Main Isolate (기본값, 별도 처리 불필요)
- **에이전트 실행**: LlmEngine Isolate에서 실행, Stream으로 UI에 전달
- **취소**: 취소 플래그 + StreamController.close() 조합

### 3.6 Error Handling

- **Tool 에러**: `"Error: ${e.toString()}"` 문자열 반환 (예외 throw 금지)
- **Repository 에러**: try-catch + 로그 출력 + 상태(AsyncError) 업데이트
- **DataSource 에러**: try-catch + 예외를 도메인 예외로 변환
- **빈 catch 금지**: `catch (_) {}` 최소한 `log` 또는 `print` 출력 필요
- **Empty catch 허용**: 로드 실패 시 자동 복구 불가한 경우만 (예: auto-load model 실패)

```dart
try {
  final result = await dataSource.someAction();
  state = AsyncData(result);
} catch (e, stackTrace) {
  log('AIOS-LlmRepo: someAction failed',
      error: e, stackTrace: stackTrace);
  state = AsyncError(e, stackTrace);
}
```

### 3.7 Logging

```dart
import 'dart:developer' as developer;

developer.log("Service connected", name: "AIOS-React");
developer.log("Agent timed out after ${elapsed}ms",
    name: "AIOS-React", level: 900);  // WARNING
developer.log("loadModel failed",
    name: "AIOS-LlmRepo", error: e, level: 1000);  // ERROR
```

TAG 형식: `"AIOS-{Component}"` (예: AIOS-React, AIOS-LlmRepo, AIOS-Bridge)

로그 레벨:
- **INFO (800)**: 정상 동작
- **WARNING (900)**: 경고/비정상
- **ERROR (1000)**: 에러 (error 포함)

### 3.8 Tool 개발

- **Basic Tool** (플랫폼 채널 불필요): `AgentTool` 인터페이스 구현 → `agent/tools/`에 추가
- **Extended Tool** (플랫폼 채널 필요): `ExtendedTool` 인터페이스 구현 → `agent/tools/`에 새 파일
- 기존 Tool 코드를 읽고 동일한 패턴으로 작성 (에러 처리, action 디스패치 등)

#### Tool 추가 시 필수
1. Tool 클래스 구현 (AgentTool 또는 ExtendedTool)
2. `ReactStrategy`의 tools 맵에 등록
3. `RiskClassifier.classify()`에 위험도 분류 추가
4. 테스트 작성 (→ [TESTING.md](TESTING.md) §P3)

#### Tool 에러 규칙
- **모든 에러는 `"Error: ..."` 문자열 반환** (예외 throw 금지)
- **action은 lowercase 비교**: `json['action'].toString().toLowerCase()`
- **Unknown action**: `"Error: Unknown action '$action'. Use ..."`
- **매개변수 누락**: `"Error: 'param_name' required"`
- **서비스 미연결**: `"Error: Accessibility service not enabled"`

### 3.9 Flutter UI

- **커스텀 색상**: `core/theme/app_colors.dart`의 `AppColors` class 사용 (Material 기본색 직접 사용 지양)
- **Screen 함수**: public, `ConsumerWidget` 또는 `ConsumerStatefulWidget`
- **하위 Widget**: private (`_` 접두사), 파라미터로 데이터 전달
- **Navigation**: GoRouter 사용 (`context.go()`, `context.push()`)
- **상태 호이스팅**: Provider가 단일 상태 소스, Widget은 상태 없음
- **ConsumerWidget 우선**: Riverpod으로 상태 관리 가능하면 `StatelessWidget` + Riverpod 사용 (`StatefulWidget` 사용 금지)

```dart
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatScreenProvider);
    return state.when(
      data: (data) => _ChatContent(messages: data.messages),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => _ErrorWidget(message: e.toString()),
    );
  }
}
```

### 3.10 LLM 통합 (llama_cpp_dart)

- **패키지**: `llama_cpp_dart: 0.9.0-dev.6`
- **LlamaEngine**: 별도 Isolate에서 실행 (UI 스레드 블로킹 방지)
- **LlmRepository**: LlamaEngine을 래핑하여 비즈니스 로직 제공
- **스트리밍**: `Stream<GenerationEvent>` 통해 토큰 단위 스트리밍
- **모델 관리**: 파일시스템에서 GGUF 파일 스캔
- **KV-cache 지속성**: `saveState` / `loadState`
- **Context shift**: `ContextShiftPolicy.auto`

```dart
@Riverpod(keepAlive: true)
class LlmEngine extends _$LlmEngine {
  @override
  Future<LlamaEngine> build() async {
    final engine = LlamaEngine();
    await engine.loadModel(modelPath);
    return engine;
  }
}
```

### 3.11 Database (Drift)

- **Drift** (SQLite) 사용
- **테이블 정의**: `data/datasources/tables/`에 Dart 클래스로 정의
- **DAO**: `data/datasources/daos/`에 쿼리 구현
- **마이그레이션**: `data/datasources/database.dart`에서 버전 관리

---

## 4. AI 작업 가이드라인 (MANDATORY)

### 4.1 금지사항 (NEVER)

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

### 4.2 코드 수정 전 체크리스트

- [ ] 수정 대상 파일과 같은 디렉토리의 기존 파일 2-3개 읽어서 패턴 파악
- [ ] DI 구조 파악 (Riverpod Provider, @riverpod, keepAlive)
- [ ] 관련 테스트 파일 확인
- [ ] 수정이 다른 모듈에 미치는 영향 분석
- [ ] 테스트 먼저 작성 (TDD)

### 4.3 Tool 추가 시 체크리스트

- [ ] Tool 클래스 구현 (AgentTool 또는 ExtendedTool)
- [ ] ReactStrategy의 tools 맵에 등록
- [ ] RiskClassifier에 위험도 분류 추가
- [ ] 테스트 작성: RiskClassifier + Tool 동작
- [ ] `flutter test` 통과 확인

### 4.4 Provider/Screen 수정 시 체크리스트

- [ ] 상태 전이 테스트 작성 (초기 → 변경 → 결과)
- [ ] 에러/엣지케이스 테스트 작성
- [ ] Provider/Screen 코드 수정
- [ ] `flutter test` 전체 통과 확인

### 4.5 Bug Fix 시 체크리스트

- [ ] 버그 재현 테스트 작성 (반드시 실패해야 함)
- [ ] 버그 수정 코드 작성
- [ ] 테스트 통과 확인
- [ ] 기존 테스트 여전히 통과 확인

### 4.6 새 파일 생성 규칙

새 파일은 **반드시** 기존 디렉토리 구조를 따름:

| 생성 대상 | 위치 | 예시 |
|-----------|------|------|
| Repository 인터페이스 | `domain/repository/` | `llm_repository.dart` |
| Repository 구현 | `data/repositories/` | `llm_repository_impl.dart` |
| Domain entity | `domain/entities/` | `agent_models.dart` |
| Agent 전략/로직 | `domain/agent/` | `response_parser.dart` |
| Extended Tool | `agent/tools/` | `screen_action_tool.dart` |
| Basic Tool | `agent/tools/`에 추가 | - |
| Screen | `presentation/screens/` | `chat_screen.dart` |
| Widget | `presentation/widgets/` | `input_bar.dart` |
| Provider | `presentation/providers/` | `chat_provider.dart` |
| DataSource | `data/datasources/` | `llm_data_source.dart` |
| Theme | `core/theme/` | `app_colors.dart` |

### 4.7 코드 리뷰 기준

모든 PR/커밋은 다음 기준을 만족해야 함:

1. **빌드**: `flutter build apk --debug` 성공
2. **분석**: `flutter analyze` 경고 없음
3. **테스트**: `flutter test` 전체 통과
4. **아키텍처**: 위 디렉토리 구조와 Riverpod DI 패턴 준수
5. **에러 처리**: Tool은 문자열 반환, Repository는 try-catch + 상태 업데이트
6. **네이밍**: 위 네이밍 규약 준수
7. **테스트**: TDD (테스트 먼저 작성)
8. **실기 테스트**: 에뮬레이터/실기기에서 APK 설치 후 런치·UI·모델 로드 정상 확인 (→ [CONTRIBUTING.md](CONTRIBUTING.md) §배포 전 필수 실기 테스트)

---

## 5. Key Principles

- **LLM is Runtime, not UI** — 모델은 한 번 로드되어 여러 상호작용에 재사용
- **Queue-based sequential inference** — 한 번에 하나의 추론만 실행
- **2-layer architecture** — Dart (UI + logic) → llama_cpp_dart (inference via Isolate)
- **Privacy-first** — 추론을 위한 네트워크 호출 없음, 모든 처리 온디바이스
- **Phone control via Accessibility APIs** — 루트 권한 불필요 (플랫폼 채널 활용)
- **Risk-aware execution** — HIGH/CRITICAL 툴은 사용자 승인 필수
- **Test-Driven Development** — 테스트 먼저 작성 (→ [TESTING.md](TESTING.md))
- **Clean Architecture** — domain/data/presentation 분리, Riverpod DI

---

## 참고 문서

- **[TESTING.md](TESTING.md)** — TDD 워크플로우, 테스트 범위, 커버리지 요구사항
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — 빌드/개발 명령어, 환경 설정, PR 규칙, 릴리즈
