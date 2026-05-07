# AIOS Testing Policy

## 1. Principles

- 모든 **public 함수**는 최소 1개 이상의 단위 테스트를 가져야 함
- **상태 변경** Notifier 함수는 상태 전이를 반드시 검증
- 버그 수정 시 원본 버그를 재현하는 **회귀 테스트** 포함 필수
- 테스트는 기능 구현 **이전에 작성** (TDD)

## 2. Current Status

- **698 테스트** 전체 통과
- 알려진 타임아웃: `model_test.dart`, `agent_integration_test.dart` (GGUF 모델 파일 필요)
- 알려진 사전 실패: `integration_test/database_integration_test.dart` 3개 (`isNull` 관련)

## 3. Test Scope

### P0: Core Logic (필수)

| Module | File | Test 항목 |
|--------|------|-----------|
| LlmRepositoryImpl | `lib/data/repositories/llm_repository_impl.dart` | 모델 로드/해제, 추론 호출, 에러 처리, 세션 저장/로드 |
| ChatNotifier | `lib/presentation/providers/chat_notifier.dart` | sendMessage, stopGeneration, loadModel, state 일관성 |
| ReactStrategy | `lib/domain/agent/react_strategy.dart` | Phase 1/2 흐름, tool 실행, ParseEmpty 넛지, 루프 감지 |

### P1: Agent System (필수)

| Module | File | Test 항목 |
|--------|------|-----------|
| ResponseParser | `lib/domain/agent/response_parser.dart` | Action/Answer/Empty 파싱, JSON args 추출 |
| PromptBuilder | `lib/domain/agent/prompt_builder.dart` | routing/tool 프롬프트 생성, 컨텍스트 포함 |
| RiskClassifier | `lib/domain/agent/risk_classifier.dart` | 위험도 분류 (LOW/MEDIUM/HIGH/CRITICAL) |
| LoopDetector | `lib/domain/agent/loop_detector.dart` | 반복 감지, 넛지/강제종료 |
| AppLauncherTool | `lib/agent/tools/app_launcher_tool.dart` | open_app/open_url/list_apps, validate, 에러 처리 |
| ScreenActionTool | `lib/agent/tools/screen_action_tool.dart` | tap/long_click/type/scroll/swipe/global, 에러 처리 |
| ScreenReaderTool | `lib/agent/tools/screen_reader_tool.dart` | 화면 텍스트 읽기, UI 요소 검색, toolPrompt |

### P2: State Management (필수)

| Module | File | Test 항목 |
|--------|------|-----------|
| SettingsNotifier | `lib/presentation/providers/settings_notifier.dart` | 설정 읽기/쓰기, 기본값, 영속성 |
| UpdateNotifier | `lib/presentation/providers/update_notifier.dart` | check/download/install 흐름, 에러 상태 |

### P3: UI (필수)

| Screen | File | Test 항목 |
|--------|------|-----------|
| ChatScreen | `lib/presentation/screens/chat/chat_screen.dart` | 메시지 전송, 정지 버튼, 입력바 가시성 |
| SettingsScreen | `lib/presentation/screens/settings/settings_screen.dart` | 권한 설정, 고급 옵션 토글 |
| UpdateScreen | `lib/presentation/screens/update/update_screen.dart` | 상태 전이, 다운로드 진행률 |

### P4: Integration (기기 필요)

| Module | What to Test |
|--------|--------------|
| llama_cpp_dart on-device | 실제 GGUF 모델 로드→추론→해제 |
| Full Agent Flow | "open youtube" → Phase 1 → Phase 2 → app 실행 |
| Database | Drift SQLite CRUD, 마이그레이션 |
| Update | GitHub Release 확인→다운로드→설치 |

## 4. Test Categories

```
test/                → Unit + Widget 테스트 (호스트 머신에서 실행, 기기 불필요)
integration_test/    → Integration 테스트 (실제 기기/에뮬레이터 필요)
```

## 5. Naming Conventions

```
File:     {name}_test.dart
Function: {method}_{scenario}_expectedResult()

Examples:
  sendMessage_whenGenerating_doesNotSend()
  parseResponse_actionWithArgs_returnsAction()
  buildRoutingPrompt_containsToolManifest()
  execute_openAppWithValidPackage_opensApp()
```

## 6. Coverage Requirements

### 함수별
- **Happy path**: 1 test (정상 입력 → 예상 출력)
- **Edge case**: 1 test 이상 (null, empty, 경계값)
- **Error path**: 알려진 각 실패 모드당 1 test

### 동시성 시나리오별
- **실행 중 취소**: 1 test
- **Race condition**: 식별된 race당 1 test
- **Timeout**: 1 test

## 7. Regression Test Rule

버그 리포트 시:
1. **버그를 재현하는 테스트** 작성 (반드시 실패해야 함)
2. 버그 수정
3. 테스트 **통과** 확인
4. 테스트 + 수정 함께 커밋

## 8. TDD Workflow

| Phase | 작업 | 검증 |
|-------|------|------|
| RED | 테스트 케이스 작성 | `flutter test` → 실패 확인 |
| GREEN | 최소 구현 코드 작성 | `flutter test` → 전체 통과 |
| REFACTOR | 코드 품질 개선 | `flutter test` → 여전히 통과 |

### Tool 추가 시 TDD 체크리스트

1. [ ] Tool 클래스 구현 (AgentTool 또는 ExtendedTool)
2. [ ] `agent_provider.dart`의 tools 맵에 등록
3. [ ] `RiskClassifier`에 위험도 분류 추가
4. [ ] Tool 동작 테스트 작성
5. [ ] `flutter test` 통과 확인

## 9. Test Patterns

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
testWidgets('with provider override', (tester) async {
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

### Agent Strategy Testing (Fake LlmRepository)

```dart
test('phase2 with empty args triggers tool prompt', () async {
  final llmRepo = _FakeLlmRepository();
  llmRepo.tokensToEmit = [
    'Action: app_launcher',
    'Action: app_launcher\nArgs: {"action":"open_app","package_name":"com.youtube"}',
  ];
  final tool = _FakeExtendedTool('app_launcher');
  final strategy = ReactStrategy(
    llmRepo,
    toolContext: toolContext,
    extendedTools: {'app_launcher': tool},
  );
  final result = await strategy.execute('open youtube');
  expect(result.success, isTrue);
});
```

## 10. Required Dependencies

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mockito: ^5.4.5
  build_runner: ^2.4.14
```

## 11. Local Development & Verification

- 모든 단위/위젯 테스트: `flutter test`
- 특정 파일만: `flutter test test/path/to/test.dart`
- Integration 테스트: `flutter test integration_test/`
- 정적 분석: `flutter analyze`
- 테스트 실패 시 작업 중단, 다음 단계로 넘어가지 않음
