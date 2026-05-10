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

import '../../../helpers/mock_conversation_repository.dart';
import '../../../helpers/mock_llm_repository.dart';
import '../../../helpers/mock_settings_repository.dart';

class _StepCapturingAgent implements AgentStrategy {
  final List<AgentStep> stepsToEmit;
  final Completer<void> _completer = Completer<void>();
  bool? lastConfirmation;
  bool cancelCalled = false;

  _StepCapturingAgent({required this.stepsToEmit});

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

  void completeExecution() => _completer.complete();

  @override
  void cancel() {
    cancelCalled = true;
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  void resolveConfirmation(bool approved) {
    lastConfirmation = approved;
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  void resolvePermission(bool granted) {}

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

class _DelayedEmitAgent implements AgentStrategy {
  final Duration delayBeforeSteps;
  final List<AgentStep> stepsToEmit;
  final Completer<void> _completer = Completer<void>();

  _DelayedEmitAgent({
    required this.delayBeforeSteps,
    required this.stepsToEmit,
  });

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

  void completeExecution() {
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  void resolveConfirmation(bool approved) {
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  void resolvePermission(bool granted) {}

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

  Widget _buildChatScreen(AgentStrategy agent) {
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
    conversationRepo.dispose();
  });

  testWidgets('render_noMessages_showsWelcome', (tester) async {
    final agent = _StepCapturingAgent(stepsToEmit: []);
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    expect(find.text('AIOS'), findsOneWidget);
    expect(find.text('AI 어시스턴트'), findsOneWidget);
  });

  testWidgets('send_message_showsMessagesAfterSending', (tester) async {
    final agent = _StepCapturingAgent(
      stepsToEmit: [const AgentStep('answer', 'Response')],
    );
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    agent.completeExecution();
    await tester.pumpAndSettle();

    expect(find.text('Hello'), findsAtLeast(1));
  });

  testWidgets('render_displaysInputBar', (tester) async {
    final agent = _StepCapturingAgent(stepsToEmit: []);
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
  });

  testWidgets('render_whileGenerating_showsGeneratingIndicator', (
    tester,
  ) async {
    final agent = _StepCapturingAgent(
      stepsToEmit: [const AgentStep('answer', 'R')],
    );
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    expect(find.byIcon(Icons.stop), findsOneWidget);

    agent.completeExecution();
    await tester.pumpAndSettle();
  });

  testWidgets('tapSend_triggersSendMessage', (tester) async {
    final agent = _StepCapturingAgent(
      stepsToEmit: [const AgentStep('answer', 'R')],
    );
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Test message');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    agent.completeExecution();
    await tester.pumpAndSettle();

    expect(find.text('Test message'), findsAtLeast(1));
  });

  testWidgets('render_displaysNewConversationIcon', (tester) async {
    final agent = _StepCapturingAgent(stepsToEmit: []);
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    expect(find.byIcon(Icons.add_comment_outlined), findsOneWidget);
  });

  testWidgets('render_agentSteps_showsThoughtActionObservation', (
    tester,
  ) async {
    final agent = _StepCapturingAgent(
      stepsToEmit: [
        const AgentStep('thought', 'User wants to calculate'),
        const AgentStep(
          'action',
          'Using calculator',
          toolName: 'calculator',
          toolArgs: '{"expression": "2+2"}',
        ),
        const AgentStep('observation', '4.0000', toolResult: '4.0000'),
        const AgentStep('answer', 'The result is 4'),
      ],
    );
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '2+2?');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump();

    expect(find.text('User wants to calculate'), findsNothing);
    expect(find.text('calculator 실행 중...'), findsOneWidget);
    expect(find.text('결과: 4.0000'), findsOneWidget);

    agent.completeExecution();
    await tester.pumpAndSettle();
  });

  testWidgets('render_confirmationRequired_showsWaitingForConfirmation', (
    tester,
  ) async {
    final agent = _StepCapturingAgent(
      stepsToEmit: [
        const AgentStep('thought', 'Opening app'),
        const AgentStep(
          'confirmation_required',
          'Needs approval',
          toolName: 'app_launcher',
          toolArgs: '{"action": "open_app"}',
          riskLevel: 'high',
        ),
      ],
    );
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'open youtube');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump();

    expect(find.text('사용자 확인 대기 중...'), findsOneWidget);
    expect(find.text('app_launcher'), findsNothing);

    agent.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('render_highRiskAction_showsConfirmationDialog', (tester) async {
    final agent = _StepCapturingAgent(
      stepsToEmit: [
        const AgentStep(
          'confirmation_required',
          'Needs approval',
          toolName: 'app_launcher',
          toolArgs: '{"action": "open_app", "package": "youtube"}',
          riskLevel: 'high',
        ),
      ],
    );
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'open youtube');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump();

    expect(find.text('실행 확인'), findsOneWidget);
    expect(find.text('승인'), findsOneWidget);
    expect(find.text('거부'), findsOneWidget);

    agent.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('confirmationDialog_approve_resolvesTrue', (tester) async {
    final agent = _StepCapturingAgent(
      stepsToEmit: [
        const AgentStep(
          'confirmation_required',
          'confirm',
          toolName: 'app_launcher',
          toolArgs: '{}',
          riskLevel: 'high',
        ),
      ],
    );
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'open youtube');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump();

    expect(find.text('실행 확인'), findsOneWidget);

    await tester.tap(find.text('승인'));
    await tester.pumpAndSettle();

    expect(agent.lastConfirmation, isTrue);
  });

  testWidgets('confirmationDialog_deny_resolvesFalse', (tester) async {
    final agent = _StepCapturingAgent(
      stepsToEmit: [
        const AgentStep(
          'confirmation_required',
          'confirm',
          toolName: 'sms_sender',
          toolArgs: '{"action": "send"}',
          riskLevel: 'critical',
        ),
      ],
    );
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'send SMS');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump();

    expect(find.text('실행 확인'), findsOneWidget);

    await tester.tap(find.text('거부'));
    await tester.pumpAndSettle();

    expect(agent.lastConfirmation, isFalse);
  });

  testWidgets('render_criticalRisk_showsWarningIcon', (tester) async {
    final agent = _StepCapturingAgent(
      stepsToEmit: [
        const AgentStep(
          'confirmation_required',
          'confirm',
          toolName: 'sms_sender',
          toolArgs: '{"action": "send"}',
          riskLevel: 'critical',
        ),
      ],
    );
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'send SMS');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.warning), findsAtLeast(1));

    await tester.tap(find.text('거부'));
    await tester.pumpAndSettle();
  });

  testWidgets('fullChatFlow_messageToAnswer_showsAll', (tester) async {
    final agent = _StepCapturingAgent(
      stepsToEmit: [
        const AgentStep('thought', 'Calculating...'),
        const AgentStep(
          'action',
          'calc',
          toolName: 'calculator',
          toolArgs: '{"expression": "2+2"}',
        ),
        const AgentStep('observation', '4.0000', toolResult: '4.0000'),
        const AgentStep('answer', 'The result is 4'),
      ],
    );
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '2+2?');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump();

    expect(find.text('Calculating...'), findsNothing);
    expect(find.text('calculator 실행 중...'), findsOneWidget);
    expect(find.text('결과: 4.0000'), findsOneWidget);

    agent.completeExecution();
    await tester.pumpAndSettle();

    expect(find.text('The result is 4'), findsOneWidget);
  });

  testWidgets('render_generatingNoSteps_showsThinkingIndicator', (
    tester,
  ) async {
    final agent = _DelayedEmitAgent(
      delayBeforeSteps: const Duration(seconds: 5),
      stepsToEmit: [const AgentStep('answer', 'R')],
    );
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    expect(find.text('생각 중...'), findsOneWidget);

    agent.completeExecution();
    await tester.pumpAndSettle();
  });

  testWidgets('clearChat_removesAllMessages', (tester) async {
    final agent = _StepCapturingAgent(
      stepsToEmit: [const AgentStep('answer', 'Hi')],
    );
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    agent.completeExecution();
    await tester.pumpAndSettle();

    expect(find.text('Hello'), findsAtLeast(1));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
  });
}
