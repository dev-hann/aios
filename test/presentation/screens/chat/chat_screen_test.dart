import 'dart:async';

import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/model_info.dart';
import 'package:aios/domain/entities/conversation.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/domain/repositories/model_repository.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:aios/presentation/providers/agent_provider.dart';
import 'package:aios/presentation/providers/conversation_provider.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/model_provider.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/screens/chat/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockLlmRepository implements LlmRepository {
  final _stateController = StreamController<ServiceState>.broadcast();
  final _tokenController = StreamController<String>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  bool modelLoaded = false;
  List<String> tokens = [];

  @override
  Stream<ServiceState> get state => _stateController.stream;

  @override
  Stream<String> get tokenStream => _tokenController.stream;

  @override
  Stream<double> get loadProgress => _progressController.stream;

  @override
  Future<bool> loadModel(String path, {int? contextSize}) async {
    modelLoaded = true;
    _stateController.add(ServiceState.ready);
    return true;
  }

  @override
  Future<void> releaseModel() async {
    modelLoaded = false;
    _stateController.add(ServiceState.idle);
  }

  @override
  bool get isModelLoaded => modelLoaded;

  @override
  String getModelInfo() => 'MockModel v1.0';

  @override
  String getContextUsage() => '0/2048 tokens';

  @override
  Future<void> resetContext() async {}

  @override
  Future<void> sendMessage(
    List<ChatMessage> history, {
    required String userMessage,
    double? temperature,
    int? maxTokens,
    int? topK,
    double? topP,
    double? repeatPenalty,
    String? grammar,
  }) async {
    _stateController.add(ServiceState.generating);
    for (final token in tokens) {
      _tokenController.add(token);
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
    _stateController.add(ServiceState.ready);
  }

  @override
  Future<void> stopGeneration() async {}

  @override
  Future<void> saveSession(String path) async {}

  @override
  Future<void> loadSession(String path) async {}

  void emitState(ServiceState s) => _stateController.add(s);

  void dispose() {
    _stateController.close();
    _tokenController.close();
    _progressController.close();
  }
}

class _MockConversationRepository implements ConversationRepository {
  @override
  Future<void> save(List<ChatMessage> messages) async {}

  @override
  Future<List<ChatMessage>> load() async => [];

  @override
  Future<void> clear() async {}

  @override
  Future<void> appendMessage(ChatMessage message) async {}

  @override
  Future<Conversation> createConversation({String? title}) async {
    return Conversation(
      id: 'test_conv',
      title: title ?? '새 대화',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Conversation>> getAllConversations() async => [];

  @override
  Future<List<ChatMessage>> loadConversation(String id) async => [];

  @override
  Future<void> deleteConversation(String id) async {}

  @override
  Future<void> updateConversationTitle(String id, String title) async {}

  @override
  Stream<List<Conversation>> watchAllConversations() => Stream.value([]);
}

class _MockSettingsRepository implements SettingsRepository {
  @override
  int get contextSize => SettingsRepository.defaultContextSize;

  @override
  int get maxTokens => SettingsRepository.defaultMaxTokens;

  @override
  double get temperature => SettingsRepository.defaultTemperature;

  @override
  int get topK => SettingsRepository.defaultTopK;

  @override
  double get topP => SettingsRepository.defaultTopP;

  @override
  double get repeatPenalty => SettingsRepository.defaultRepeatPenalty;

  @override
  int get agentMaxIterations =>
      SettingsRepository.defaultAgentMaxIterations;

  @override
  String? get lastModelPath => null;

  @override
  bool get onboardingCompleted => true;

  @override
  Future<void> setContextSize(int value) async {}

  @override
  Future<void> setMaxTokens(int value) async {}

  @override
  Future<void> setTemperature(double value) async {}

  @override
  Future<void> setTopK(int value) async {}

  @override
  Future<void> setTopP(double value) async {}

  @override
  Future<void> setRepeatPenalty(double value) async {}

  @override
  Future<void> setAgentMaxIterations(int value) async {}

  @override
  Future<void> setLastModelPath(String path) async {}

  @override
  Future<void> clearLastModelPath() async {}

  @override
  Future<void> setOnboardingCompleted() async {}
}

class _MockModelRepository implements ModelRepository {
  @override
  List<ModelInfo> scanModels() => [];

  @override
  List<ModelInfo> scanExternalDirs() => [];

  @override
  bool restoreModel(String name) => false;

  @override
  Future<bool> importModelFromUri(
    String sourcePath,
    String fileName,
  ) async =>
      false;
}

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
  String getToolManifest() => '- test: test';

  @override
  List<({String role, String content})> getConversationHistory() => [];

  @override
  void clearHistory() {}

  @override
  void setConversationContext(ConversationContext? context) {}

  @override
  void setToolPreferenceTracker(
    ToolPreferenceTracker? tracker,
  ) {}
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
  String getToolManifest() => '- test: test';

  @override
  List<({String role, String content})> getConversationHistory() => [];

  @override
  void clearHistory() {}

  @override
  void setConversationContext(ConversationContext? context) {}

  @override
  void setToolPreferenceTracker(
    ToolPreferenceTracker? tracker,
  ) {}
}

void main() {
  late _MockLlmRepository llmRepo;
  late _MockConversationRepository conversationRepo;

  Widget _buildChatScreen(AgentStrategy agent) {
    return ProviderScope(
      overrides: [
        llmRepositoryProvider.overrideWithValue(llmRepo),
        conversationRepositoryProvider
            .overrideWithValue(conversationRepo),
        settingsRepositoryProvider
            .overrideWithValue(_MockSettingsRepository()),
        modelRepositoryProvider
            .overrideWithValue(_MockModelRepository()),
        agentProvider.overrideWithValue(agent),
      ],
      child: const MaterialApp(home: ChatScreen()),
    );
  }

  setUp(() {
    llmRepo = _MockLlmRepository();
    conversationRepo = _MockConversationRepository();
  });

  tearDown(() {
    llmRepo.dispose();
  });

  testWidgets('render_noMessages_showsWelcome', (tester) async {
    final agent = _StepCapturingAgent(stepsToEmit: []);
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    expect(find.text('AIOS'), findsOneWidget);
    expect(
      find.text('Your on-device AI assistant'),
      findsOneWidget,
    );
  });

  testWidgets('send_message_showsMessagesAfterSending', (tester) async {
    final agent = _StepCapturingAgent(
      stepsToEmit: [const AgentStep('answer', 'Response')],
    );
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byIcon(Icons.send));
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
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('render_whileGenerating_showsGeneratingIndicator',
      (tester) async {
    final agent = _StepCapturingAgent(
      stepsToEmit: [const AgentStep('answer', 'R')],
    );
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.byIcon(Icons.stop_circle), findsOneWidget);

    agent.completeExecution();
    await tester.pumpAndSettle();
  });

  testWidgets('render_loadingModel_showsModelLoadingView', (tester) async {
    final agent = _StepCapturingAgent(stepsToEmit: []);
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    llmRepo.emitState(ServiceState.loadingModel);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading AI model...'), findsAtLeast(1));
  });

  testWidgets('tapSend_triggersSendMessage', (tester) async {
    final agent = _StepCapturingAgent(
      stepsToEmit: [const AgentStep('answer', 'R')],
    );
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    await tester.enterText(
      find.byType(TextField),
      'Test message',
    );
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    agent.completeExecution();
    await tester.pumpAndSettle();

    expect(find.text('Test message'), findsAtLeast(1));
  });

  testWidgets('render_displaysSettingsIcon', (tester) async {
    final agent = _StepCapturingAgent(stepsToEmit: []);
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('render_errorState_showsErrorState', (tester) async {
    final agent = _StepCapturingAgent(stepsToEmit: []);
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    llmRepo.emitState(ServiceState.error);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(ChatScreen), findsOneWidget);
  });

  testWidgets('render_agentSteps_showsThoughtActionObservation',
      (tester) async {
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
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('User wants to calculate'),
      findsNothing,
    );
    expect(find.text('calculator 실행 중...'), findsOneWidget);
    expect(find.text('결과: 4.0000'), findsOneWidget);

    agent.completeExecution();
    await tester.pumpAndSettle();
  });

  testWidgets('render_confirmationRequired_showsWaitingForConfirmation',
      (tester) async {
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
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('사용자 확인 대기 중...'),
      findsOneWidget,
    );
    expect(find.text('app_launcher'), findsNothing);

    agent.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('render_highRiskAction_showsConfirmationDialog',
      (tester) async {
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
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();

    expect(find.text('Confirm Action'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Deny'), findsOneWidget);
    expect(
      find.textContaining('app_launcher'),
      findsOneWidget,
    );

    agent.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('confirmationDialog_approve_resolvesTrue',
      (tester) async {
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
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();

    expect(find.text('Confirm Action'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(agent.lastConfirmation, isTrue);
  });

  testWidgets('confirmationDialog_deny_resolvesFalse',
      (tester) async {
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
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();

    expect(find.text('Confirm Action'), findsOneWidget);

    await tester.tap(find.text('Deny'));
    await tester.pumpAndSettle();

    expect(agent.lastConfirmation, isFalse);
  });

  testWidgets('render_criticalRisk_showsWarningIcon',
      (tester) async {
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
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.warning), findsAtLeast(1));

    await tester.tap(find.text('Deny'));
    await tester.pumpAndSettle();
  });

  testWidgets('fullChatFlow_messageToAnswer_showsAll',
      (tester) async {
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
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();

    expect(find.text('Calculating...'), findsNothing);
    expect(find.text('calculator 실행 중...'), findsOneWidget);
    expect(find.text('결과: 4.0000'), findsOneWidget);

    agent.completeExecution();
    await tester.pumpAndSettle();

    expect(find.text('The result is 4'), findsOneWidget);
  });

  testWidgets('render_generatingNoSteps_showsThinkingIndicator',
      (tester) async {
    final agent = _DelayedEmitAgent(
      delayBeforeSteps: const Duration(seconds: 5),
      stepsToEmit: [const AgentStep('answer', 'R')],
    );
    await tester.pumpWidget(_buildChatScreen(agent));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('Thinking...'), findsOneWidget);

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
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    agent.completeExecution();
    await tester.pumpAndSettle();

    expect(find.text('Hello'), findsAtLeast(1));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
  });
}
