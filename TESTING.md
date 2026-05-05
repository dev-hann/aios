# AIOS Testing Policy

## 1. Principles

- 모든 **public 함수**는 최소 1개 이상의 단위 테스트를 가져야 함
- **상태 변경** Notifier 함수는 상태 전이를 반드시 검증
- 버그 수정 시 원본 버그를 재현하는 **회귀 테스트** 포함 필수
- 테스트는 기능 구현 **이전에 작성** (TDD)

## 2. Test Scope

### P0: Core Logic (필수)

| Module | File | Test 항목 |
|--------|------|-----------|
| LlmRepositoryImpl | `lib/data/repositories/llm_repository_impl.dart` | llama_cpp_dart 래핑, 모델 로드/해제, 추론 호출, 에러 처리 |
| ChatNotifier | `lib/presentation/providers/chat_notifier.dart` | sendMessage, stopGeneration, loadModel, state 일관성 |
| Model Lifecycle | `lib/data/repositories/llm_repository_impl.dart` | 모델 로드→추론→해제 전체 주기, 동시 접근, Isolate 정리 |

### P1: State Management (필수)

| Module | File | Test 항목 |
|--------|------|-----------|
| SettingsNotifier | `lib/presentation/providers/settings_notifier.dart` | 설정 읽기/쓰기, 기본값, 영속성 |
| UpdateNotifier | `lib/presentation/providers/update_notifier.dart` | check/download/install 흐름, 에러 상태 |

### P2: UI (필수)

| Screen | File | Test 항목 |
|--------|------|-----------|
| ChatScreen | `lib/presentation/screens/chat/chat_screen.dart` | 메시지 전송, 정지 버튼, 입력바 가시성, 빈 상태 |
| SettingsScreen | `lib/presentation/screens/settings/settings_screen.dart` | 권한 설정, 고급 옵션 토글, 오버레이 서비스 스위치 |
| UpdateScreen | `lib/presentation/screens/update/update_screen.dart` | 상태 전이, 다운로드 진행률 |

### P3: Domain (필수, 향후 Agent 시스템)

| Module | File | Test 항목 |
|--------|------|-----------|
| ResponseParser | `lib/domain/response_parser.dart` | Action/Thought/Answer 파싱, malformed 입력 |
| RiskClassifier | `lib/domain/risk_classifier.dart` | 위험도 분류 (LOW/MEDIUM/HIGH/CRITICAL) |
| LoopDetector | `lib/domain/loop_detector.dart` | 반복 감지, 임계값 초과 |

### P4: Integration (별도 계획)

| Module | What to Test |
|--------|--------------|
| llama_cpp_dart on-device | 실제 GGUF 모델 로드→추론→해제 |
| Full Chat Flow | 메시지 전송→스트리밍→완료 전체 흐름 |
| Database | Drift SQLite CRUD, 마이그레이션 |
| Update | GitHub Release 확인→다운로드→설치 |

## 3. Test Categories

```
test/                → Unit + Widget 테스트 (호스트 머신에서 실행, 기기 불필요)
integration_test/    → Integration 테스트 (실제 기기/에뮬레이터 필요)
```

## 4. Coverage Requirements

### 함수별
- **Happy path**: 1 test (정상 입력 → 예상 출력)
- **Edge case**: 1 test 이상 (null, empty, 경계값)
- **Error path**: 알려진 각 실패 모드당 1 test

### 동시성 시나리오별
- **실행 중 취소**: 1 test
- **Race condition**: 식별된 race당 1 test
- **Timeout**: 1 test

### UI Screen별
- **초기 렌더링**: 1 test
- **핵심 인터랙션**: 사용자 액션당 1 test
- **상태 전이**: 가시적 상태 변화당 1 test

## 5. Regression Test Rule

버그 리포트 시:
1. **버그를 재현하는 테스트** 작성 (반드시 실패해야 함)
2. 버그 수정
3. 테스트 **통과** 확인
4. 테스트 + 수정 함께 커밋

## 6. Naming Conventions

```
File:     {name}_test.dart
Function: {method}_{scenario}_expectedResult()

Examples:
  sendMessage_whenGenerating_doesNotSend()
  loadModel_withInvalidPath_setsErrorState()
  parseResponse_withActionAndArgs_returnsAction()
  stopGeneration_duringInference_resetsState()
```

## 7. Required Dependencies (pubspec.yaml)

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mockito: ^5.4.5
  build_runner: ^2.4.14
```

## 8. Flutter Runtime Constraint Tests (필수)

| ID | Constraint | Test Location | What to Verify |
|----|-----------|---------------|----------------|
| FR-1 | GGUF 모델 파일 파일시스템 접근 권한 | `test/` | 모델 경로 존재 여부, 읽기 권한 확인 |
| FR-2 | 저장 공간 부족 처리 | `test/` | 디스크 공간 체크, 부족 시 사용자 안내 |
| FR-3 | Isolate lifecycle (spawn/dispose) | `test/` | Isolate 정상 생성, 에러 시 정리, 메모리 누수 없음 |
| FR-4 | Isolate 간 통신 (SendPort/ReceivePort) | `test/` | 메시지 송수신, 대용량 텍스트 전달, 타임아웃 |

### 규칙

1. **Isolate는 반드시 try-catch로 보호** — `Isolate.spawn()` 호출부는 예외 처리 필수
2. **파일 접근 시 path 존재 확인** — GGUF 파일 로드 전 파일 존재 + 크기 > 0 검증
3. **새 Flutter/Android 버전 릴리즈 시 회귀 테스트 업데이트** — targetSdkVersion 변경 시 FR-x 테스트 케이스 재검증

## 9. Known Crash Regression Tests

| ID | Crash | Test Required |
|----|-------|---------------|
| P0-1 | Isolate 전역 상태 스레드 안전성 | Isolate 동시성 테스트 |
| P0-2 | llama_cpp_dart 콜백 예외 처리 | Native callback 에러 테스트 |
| P0-3 | null 모델로 tokenize 호출 | LlmRepositoryImpl null guard 테스트 |
| P0-4 | ChatNotifier 동시성 (Isolate) | ChatNotifier 동시성 테스트 |
| P1-1 | Isolate spawn 실패 시 graceful 처리 | LlmRepositoryImpl 에러 테스트 |
| P1-2 | 모델 로드 시 기존 모델 누수 | LlmRepositoryImpl lifecycle 테스트 |
| P1-3 | 취소 시 스트리밍 콜백 미복원 | ChatNotifier cancel 테스트 |

## 10. TDD Workflow

### 개발 사이클

| Phase | 작업 | 검증 |
|-------|------|------|
| RED | 테스트 케이스 작성 (§4 기준) | `flutter test` → 실패 확인 |
| GREEN | 최소 구현 코드 작성 | `flutter test` → 전체 통과 |
| REFACTOR | 코드 품질 개선 | `flutter test` → 여전히 통과 |

### 기능별 TDD 체크리스트

**새 기능 추가 시:**
1. [ ] 입력/출력 테스트 작성
2. [ ] 에러/엣지케이스 테스트 작성
3. [ ] 기능 구현 코드 작성
4. [ ] `flutter test` 전체 통과 확인

**Notifier 수정 시:**
1. [ ] 상태 전이 테스트 작성 (초기 → 변경 → 결과)
2. [ ] 에러/엣지케이스 테스트 작성
3. [ ] Notifier 코드 수정
4. [ ] `flutter test` 전체 통과 확인

**Bug fix 시 (§5 준수):**
1. [ ] 버그 재현 테스트 작성 (반드시 실패해야 함)
2. [ ] 버그 수정 코드 작성
3. [ ] 테스트 통과 확인
4. [ ] 기존 테스트 여전히 통과 확인

**Tool 추가 시:**
1. [ ] Tool 클래스 구현 (AgentTool 또는 ExtendedTool)
2. [ ] ReactStrategy의 tools 맵에 등록
3. [ ] RiskClassifier에 위험도 분류 추가
4. [ ] RiskClassifier + Tool 동작 테스트 작성
5. [ ] `flutter test` 통과 확인

## 11. Flutter-Specific Test Patterns

### Widget Testing

```dart
testWidgets('ChatScreen renders empty state', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: ChatScreen()),
  );
  await tester.pump();

  expect(find.text('메시지를 입력하세요'), findsOneWidget);
});
```

### Riverpod Testing (ProviderScope + overrides)

```dart
testWidgets('ChatScreen displays messages from provider', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatStateProvider.overrideWith(() => MockChatNotifier()),
      ],
      child: const MaterialApp(home: ChatScreen()),
    ),
  );
  await tester.pump();

  expect(find.text('Hello'), findsOneWidget);
});
```

### Mock Setup (@GenerateMocks + build_runner)

```dart
@GenerateMocks([LlmRepository])
import 'chat_notifier_test.mocks.dart';

void main() {
  late MockLlmRepository mockRepository;
  late ChatNotifier notifier;

  setUp(() {
    mockRepository = MockLlmRepository();
    notifier = ChatNotifier(repository: mockRepository);
  });

  test('sendMessage_whenGenerating_doesNotSend', () async {
    when(mockRepository.isGenerating).thenReturn(true);
    await notifier.sendMessage('test');
    verifyNever(mockRepository.sendMessage(any, userMessage: any));
  });
}
```

Mock 생성: `dart run build_runner build`

### Stream Testing

```dart
test('inferenceStream emits tokens in order', () async {
  final stream = Stream.fromIterable(['Hello', ' ', 'World']);
  await expectLater(stream, emitsInOrder(['Hello', ' ', 'World']));
});
```

## 12. Local Development & Verification

- 모든 단위/위젯 테스트 로컬 실행: `flutter test`
- 특정 파일만 실행: `flutter test test/path/to/test.dart`
- Integration 테스트: `flutter test integration_test/`
- 코드 스타일 검사: `dart format --set-exit-if-changed .`
- 정적 분석: `dart analyze`
- 테스트 실패 시 작업 중단, 다음 단계로 넘어가지 않음
