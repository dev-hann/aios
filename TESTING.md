# AIOS Testing Policy

## 테스트별 참고 섹션

| 상황 | 참고 섹션 |
|------|-----------|
| 단위 테스트 작성 | §1 원칙, §3 스코프, §5-6 네이밍/커버리지, §9 패턴 |
| 통합 테스트 | §3 P4, §4 카테고리 |
| TDD 워크플로우 | §8 TDD, §7 회귀 테스트 |
| Tool 추가 시 | §8 Tool 체크리스트 |
| 기기 테스트 | **TESTING_DEVICE.md** 참고 |

## 1. Principles

- 모든 **public 함수**는 최소 1개 이상의 단위 테스트를 가져야 함
- **상태 변경** Notifier 함수는 상태 전이를 반드시 검증
- 버그 수정 시 원본 버그를 재현하는 **회귀 테스트** 포함 필수
- 테스트는 기능 구현 **이전에 작성** (TDD)

## 2. Current Status

- **1063 단위/위젯 테스트** (전체 통과)
- 테스트 프레임워크: **flutter_test** + **mockito**
- 82 테스트 파일, 0 실패

## 3. Test Scope

### P0: Core Logic (필수)

| Module | File | Test 항목 |
|--------|------|-----------|
| ReactStrategy | `lib/domain/agent/react_strategy.dart` | native tool-calling 루프, tool 실행, 빈 응답 넛지, 루프 감지, multi-tool chaining, context awareness 주입, error recovery |
| OpenAiClient | `lib/data/providers/remote/openai_client.dart` | SSE tool_calls 파싱, tool schema 변환, enum/optional/example 파라미터 |
| LlmRemoteSession | `lib/data/providers/remote/llm_remote_session.dart` | 메시지 히스토리, addToolResult, tool_call_id 추적 |
| ConversationContext | `lib/domain/agent/conversation_context.dart` | 대화 맥락 유지, 턴 기록/조회, maxTurns, toPromptContext |
| ToolPreferenceTracker | `lib/domain/agent/tool_preference_tracker.dart` | tool 사용 빈도 추적, getMostUsed, toPromptContext |
| ChatNotifier | `lib/presentation/providers/chat_notifier.dart` | sendMessage, stopGeneration, state 일관성, 세션 관리 |

### P1: Agent System (필수)

| Module | File | Test 항목 |
|--------|------|-----------|
| RiskClassifier | `lib/domain/agent/risk_classifier.dart` | 위험도 분류 (LOW/MEDIUM/HIGH/CRITICAL) |
| LoopDetector | `lib/domain/agent/loop_detector.dart` | 반복 감지, 넛지/강제종료 |
| ErrorRecovery | `lib/domain/agent/error_recovery.dart` | 에러 분류, 복구 힌트, 재시도 추적, 사용자 메시지 |
| UserMessageMapper | `lib/domain/agent/user_message_mapper.dart` | 기술적 에러 → 사용자 친화적 메시지 변환 |
| ToolJsonParser | `lib/domain/agent/tool_json_parser.dart` | JSON 인수 파싱, parseIntDynamic, parseDoubleDynamic |
| ToolArgInference | `lib/domain/agent/tool_arg_inference.dart` | 빈 args 휴리스틱 추론 |
| AppLauncherTool | `lib/agent/tools/app_launcher_tool.dart` | 단일 `open` 액션, 퍼지 매칭, URL 감지 |
| ScreenActionTool | `lib/agent/tools/screen_action_tool.dart` | tap/long_click/type/scroll/swipe/global, 에러 처리 |
| ScreenReaderTool | `lib/agent/tools/screen_reader_tool.dart` | 화면 텍스트 읽기, UI 요소 검색, toolPrompt |
| NotificationTool | `lib/agent/tools/notification_tool.dart` | 알림 목록/내용 읽기, 앱 필터링, toolPrompt |
| SmsSenderTool | `lib/agent/tools/sms_sender_tool.dart` | SMS 전송/읽기, toolPrompt |
| PhoneCallerTool | `lib/agent/tools/phone_caller_tool.dart` | 전화 걸기/다이얼, toolPrompt |
| ContactSearchTool | `lib/agent/tools/contact_search_tool.dart` | 연락처 검색, toolPrompt |
| NotePadTool | `lib/agent/tools/notepad_tool.dart` | 메모 작성/조회/목록/삭제, toolPrompt |
| TimerTool | `lib/agent/tools/timer_tool.dart` | 타이머 설정/확인/취소/목록, toolPrompt |
| CalculatorTool | `lib/agent/tools/calculator_tool.dart` | 사칙연산, 퍼센트, 제곱근, 에러 |
| DeviceInfoTool | `lib/agent/tools/device_info_tool.dart` | 기기 정보 조회, toolPrompt |

### P2: State Management (필수)

| Module | File | Test 항목 |
|--------|------|-----------|
| SettingsNotifier | `lib/presentation/providers/settings_notifier.dart` | 설정 읽기/쓰기, 기본값, 영속성 |
| UpdateNotifier | `lib/presentation/providers/update_notifier.dart` | check/download/install 흐름, 에러 상태 |

### P3: UI (필수)

| Screen/Widget | File | Test 항목 |
|---------------|------|-----------|
| ChatScreen | `lib/presentation/screens/chat/chat_screen.dart` | 메시지 전송, 정지 버튼, 입력바 가시성 |
| SettingsScreen | `lib/presentation/screens/settings/settings_screen.dart` | 설정 항목 렌더링, 업데이트 상태 |
| ProviderSettingsScreen | `lib/presentation/screens/settings/provider_settings_screen.dart` | 제공자 선택, API 키, 모델 선택, 연결 테스트 |
| InferenceSettingsScreen | `lib/presentation/screens/settings/inference_settings_screen.dart` | 슬라이더, 기본값 리셋 |
| PermissionManagementScreen | `lib/presentation/screens/settings/permission_management_screen.dart` | 권한 상태 표시 |
| MessageBubble | `lib/presentation/widgets/message_bubble.dart` | 유저/어시스턴트 말풍선, tool info 렌더링 |
| InputBar | `lib/presentation/widgets/input_bar.dart` | 입력, 전송, 정지 |
| SessionDrawer | `lib/presentation/widgets/session_drawer.dart` | 세션 목록, 전환, 삭제 |
| ConnectionStatusBadge | `lib/presentation/widgets/connection_status_badge.dart` | 연결 상태 표시 |
| LoadingIndicator | `lib/presentation/widgets/loading_indicator.dart` | 로딩 단계 표시 |
| SectionCard | `lib/presentation/widgets/section_card.dart` | 섹션 카드 렌더링 |
| NavTile | `lib/presentation/widgets/nav_tile.dart` | 네비게이션 타일 |

### P4: Data Layer (필수)

| Module | File | Test 항목 |
|--------|------|-----------|
| Database | `lib/data/datasources/local/database.dart` | Drift SQLite CRUD, 마이그레이션 |
| GitHubApi | `lib/data/datasources/remote/github_api.dart` | 릴리즈 조회, 버전 파싱 |
| ConversationRepositoryImpl | `lib/data/repositories/conversation_repository_impl.dart` | 대화 CRUD, 세션 관리 |
| LlmRepositoryImpl | `lib/data/repositories/llm_repository_impl.dart` | 상태 관리, 세션 생성 |
| SettingsRepositoryImpl | `lib/data/repositories/settings_repository_impl.dart` | SharedPreferences 영속성 |
| NoteRepositoryImpl | `lib/data/repositories/note_repository_impl.dart` | 메모 CRUD |
| UpdateRepositoryImpl | `lib/data/repositories/update_repository_impl.dart` | APK 다운로드, 설치 |
| OverlayService | `lib/data/services/overlay_service.dart` | 오버레이 상태 표시/숨김 |
| ForegroundService | `lib/data/services/foreground_service.dart` | 포그라운드 서비스 제어 |

## 4. Test Categories

```
test/                → Unit + Widget 테스트 (호스트 머신에서 실행, 기기 불필요)
integration_test/    → Integration 테스트 (실제 기기 + .env.test API key 필요)
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

### Agent Strategy Testing (Mock LlmRepository)

```dart
test('execute with tool calls processes correctly', () async {
  final mockEngine = _MockLlmEngine();
  final strategy = ReactStrategy(
    engine: mockEngine,
    basicTools: {'calculator': _MockTool()},
  );
  final result = await strategy.execute('calculate 2+3');
  expect(result.success, isTrue);
});
```

### Notifier Testing (StateNotifier + Mock Repository)

```dart
test('checkForUpdate transitions to available', () async {
  final mockRepo = MockUpdateRepository();
  mockRepo.checkResult = UpdateResult.success(info);
  final notifier = UpdateNotifier(mockRepo, '1.0.0');

  await notifier.checkForUpdate();

  expect(notifier.state.status, UpdateStatus.available);
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
- 포맷팅: `dart format . --set-exit-if-changed`
- 코드 생성: `dart run build_runner build`
- 테스트 실패 시 작업 중단, 다음 단계로 넘어가지 않음
