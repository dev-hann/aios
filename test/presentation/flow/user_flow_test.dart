import 'dart:async';

import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/presentation/providers/agent_provider.dart';
import 'package:aios/presentation/providers/conversation_provider.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/screens/chat/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_conversation_repository.dart';
import '../../helpers/mock_llm_repository.dart';
import '../../helpers/mock_settings_repository.dart';

class _CompletableAgent implements AgentStrategy {
  _CompletableAgent({required this.stepsToEmit});
  final List<AgentStep> stepsToEmit;
  final Completer<void> _completer = Completer<void>();
  bool? lastConfirmation;
  bool cancelCalled = false;

  @override
  Future<AgentResult> execute(
    String prompt, {
    int maxIterations = 8,
    int maxTokens = 512,
    void Function(AgentStep)? onStep,
  }) async {
    for (final step in stepsToEmit) {
      onStep?.call(step);
    }
    await _completer.future;
    return AgentResult(steps: stepsToEmit, success: true);
  }

  void complete() => _completer.complete();

  @override
  void cancel() {
    cancelCalled = true;
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  void resolveConfirmation({required bool approved}) {
    lastConfirmation = approved;
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  void resolvePermission({required bool granted}) {}

  @override
  void setPermissionChecker(
    Future<bool> Function(String permissionKey)? checker,
  ) {}

  @override
  String getToolManifest() => '- test: test';

  @override
  List<({String role, String content})> getConversationHistory() => [];

  @override
  void clearHistory() {}

  @override
  Future<void> warmup() async {}

  @override
  void setConversationContext(ConversationContext? context) {}

  @override
  void setToolPreferenceTracker(ToolPreferenceTracker? tracker) {}
}

class _ErrorAgent implements AgentStrategy {
  _ErrorAgent(this.error);
  final Exception error;

  @override
  Future<AgentResult> execute(
    String prompt, {
    int maxIterations = 8,
    int maxTokens = 512,
    void Function(AgentStep)? onStep,
  }) async {
    throw error;
  }

  @override
  void cancel() {}

  @override
  void resolveConfirmation({required bool approved}) {}

  @override
  void resolvePermission({required bool granted}) {}

  @override
  void setPermissionChecker(
    Future<bool> Function(String permissionKey)? checker,
  ) {}

  @override
  String getToolManifest() => '- test: test';

  @override
  List<({String role, String content})> getConversationHistory() => [];

  @override
  void clearHistory() {}

  @override
  Future<void> warmup() async {}

  @override
  void setConversationContext(ConversationContext? context) {}

  @override
  void setToolPreferenceTracker(ToolPreferenceTracker? tracker) {}
}

class _DelayedAgent implements AgentStrategy {
  _DelayedAgent({required this.stepsToEmit});
  final List<AgentStep> stepsToEmit;
  final Completer<void> _completer = Completer<void>();
  bool cancelCalled = false;

  @override
  Future<AgentResult> execute(
    String prompt, {
    int maxIterations = 8,
    int maxTokens = 512,
    void Function(AgentStep)? onStep,
  }) async {
    await _completer.future;
    for (final step in stepsToEmit) {
      onStep?.call(step);
    }
    return AgentResult(steps: stepsToEmit, success: true);
  }

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  void cancel() {
    cancelCalled = true;
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  void resolveConfirmation({required bool approved}) {
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  void resolvePermission({required bool granted}) {}

  @override
  void setPermissionChecker(
    Future<bool> Function(String permissionKey)? checker,
  ) {}

  @override
  String getToolManifest() => '- test: test';

  @override
  List<({String role, String content})> getConversationHistory() => [];

  @override
  void clearHistory() {}

  @override
  Future<void> warmup() async {}

  @override
  void setConversationContext(ConversationContext? context) {}

  @override
  void setToolPreferenceTracker(ToolPreferenceTracker? tracker) {}
}

void main() {
  late MockLlmRepository llmRepo;
  late MockConversationRepository conversationRepo;

  Widget buildAppWithRouter({required AgentStrategy agent}) {
    final settingsRepo = MockSettingsRepository();

    return ProviderScope(
      overrides: [
        llmRepositoryProvider.overrideWithValue(llmRepo),
        conversationRepositoryProvider.overrideWithValue(conversationRepo),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        agentProvider.overrideWithValue(agent),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [GoRoute(path: '/', builder: (_, __) => const ChatScreen())],
        ),
      ),
    );
  }

  Widget buildChatScreen({required AgentStrategy agent}) {
    return ProviderScope(
      overrides: [
        llmRepositoryProvider.overrideWithValue(llmRepo),
        conversationRepositoryProvider.overrideWithValue(conversationRepo),
        settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
        agentProvider.overrideWithValue(agent),
      ],
      child: const MaterialApp(home: ChatScreen()),
    );
  }

  setUp(() {
    llmRepo = MockLlmRepository();
    conversationRepo = MockConversationRepository();
  });

  tearDown(() {
    llmRepo.dispose();
  });

  group('E2E: Chat screen shows on launch', () {
    testWidgets('showsChatScreen', (tester) async {
      final agent = _CompletableAgent(stepsToEmit: []);
      await tester.pumpWidget(buildAppWithRouter(agent: agent));
      await tester.pumpAndSettle();

      expect(find.text('AIOS'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('E2E: Send message without model', () {
    testWidgets('sendMessage_error_showsErrorBar', (tester) async {
      final agent = _ErrorAgent(Exception('Model not loaded'));
      await tester.pumpWidget(buildChatScreen(agent: agent));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('sendMessage_networkError_showsNetworkMessage', (tester) async {
      final agent = _ErrorAgent(Exception('Network connection failed'));
      await tester.pumpWidget(buildChatScreen(agent: agent));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      expect(find.text('네트워크 연결 오류입니다. 인터넷 연결을 확인하세요.'), findsOneWidget);
    });
  });

  group('E2E: Chat delete flow', () {
    testWidgets('sendMessageThenDelete_canOpenDrawer', (tester) async {
      final agent = _CompletableAgent(
        stepsToEmit: [const AgentStep('answer', 'Hello!')],
      );
      await tester.pumpWidget(buildChatScreen(agent: agent));
      await tester.pumpAndSettle();

      expect(find.text('AIOS'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      agent.complete();
      await tester.pumpAndSettle();

      expect(find.text('Hi'), findsAtLeast(1));
      expect(find.text('Hello!'), findsAtLeast(1));

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.byType(Drawer), findsOneWidget);
    });
  });

  group('E2E: Agent step cards', () {
    testWidgets('fullAgentLoop_showsAllStepCards', (tester) async {
      final agent = _CompletableAgent(
        stepsToEmit: [
          const AgentStep('thought', 'User wants to know time'),
          const AgentStep(
            'action',
            'Getting device info',
            toolName: 'device_info',
            toolArgs: '{"query": "time"}',
          ),
          const AgentStep(
            'observation',
            'Current time: 3:00 PM',
            toolResult: 'Current time: 3:00 PM',
          ),
          const AgentStep('answer', 'It is 3:00 PM'),
        ],
      );
      await tester.pumpWidget(buildChatScreen(agent: agent));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'What time is it?');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await tester.pump();

      expect(find.text('User wants to know time'), findsNothing);
      expect(find.text('device_info 실행 중...'), findsOneWidget);
      expect(find.text('결과: Current time: 3:00 PM'), findsOneWidget);

      agent.complete();
      await tester.pumpAndSettle();

      expect(find.text('It is 3:00 PM'), findsOneWidget);
    });
  });

  group('E2E: Confirmation dialog', () {
    testWidgets('highRiskAction_showsDialog_approve', (tester) async {
      final agent = _CompletableAgent(
        stepsToEmit: [
          const AgentStep(
            'confirmation_required',
            'Needs approval',
            toolName: 'app_launcher',
            toolArgs: '{"package": "com.youtube"}',
            riskLevel: 'high',
          ),
        ],
      );
      await tester.pumpWidget(buildChatScreen(agent: agent));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'open youtube');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await tester.pump();

      expect(find.text('실행 확인'), findsOneWidget);
      expect(find.text('승인'), findsOneWidget);
      expect(find.text('거부'), findsOneWidget);

      await tester.tap(find.text('승인'));
      await tester.pumpAndSettle();

      expect(agent.lastConfirmation, isTrue);
    });

    testWidgets('criticalRiskAction_showsWarning_deny', (tester) async {
      final agent = _CompletableAgent(
        stepsToEmit: [
          const AgentStep(
            'confirmation_required',
            'SMS needs approval',
            toolName: 'sms_sender',
            toolArgs: '{"action": "send", "to": "123"}',
            riskLevel: 'critical',
          ),
        ],
      );
      await tester.pumpWidget(buildChatScreen(agent: agent));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'send SMS');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.warning), findsAtLeast(1));

      await tester.tap(find.text('거부'));
      await tester.pumpAndSettle();

      expect(agent.lastConfirmation, isFalse);
    });
  });

  group('E2E: Stop generation', () {
    testWidgets('stopDuringGeneration_cancelsAgent', (tester) async {
      final agent = _DelayedAgent(
        stepsToEmit: [const AgentStep('answer', 'Done')],
      );
      await tester.pumpWidget(buildChatScreen(agent: agent));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      expect(find.byIcon(Icons.stop), findsOneWidget);

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pumpAndSettle();

      expect(agent.cancelCalled, isTrue);
    });
  });

  group('E2E: Drawer round-trip', () {
    testWidgets('drawerOpenAndClose_preservesChat', (tester) async {
      final agent = _CompletableAgent(
        stepsToEmit: [const AgentStep('answer', 'Reply')],
      );
      await tester.pumpWidget(buildChatScreen(agent: agent));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      agent.complete();
      await tester.pumpAndSettle();

      expect(find.text('Hello'), findsAtLeast(1));

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.byType(Drawer), findsOneWidget);

      Navigator.of(tester.element(find.byType(Drawer))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Hello'), findsAtLeast(1));
    });
  });
}
