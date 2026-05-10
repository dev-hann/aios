import 'dart:async';

import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/conversation.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:aios/presentation/providers/agent_provider.dart';
import 'package:aios/presentation/providers/conversation_provider.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/screens/chat/chat_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _MockLlmRepository implements LlmRepository {
  final _stateController = StreamController<ServiceState>.broadcast();

  bool connected = false;

  @override
  Stream<ServiceState> get state => _stateController.stream;

  @override
  Future<bool> connect(LlmProviderConfig config) async {
    connected = true;
    _stateController.add(ServiceState.ready);
    return true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
    _stateController.add(ServiceState.idle);
  }

  @override
  bool get isConnected => connected;

  @override
  Future<List<LlmModelInfo>> fetchModels(LlmProviderConfig config) async {
    return [];
  }

  @override
  Future<bool> testConnection(LlmProviderConfig config) async => true;

  @override
  Future<void> stopGeneration() async {}

  @override
  Future<void> loadModel(String path, {int? contextSize}) async {}

  void emitState(ServiceState s) => _stateController.add(s);

  void dispose() {
    _stateController.close();
  }
}

class _MockConversationRepository implements ConversationRepository {
  final List<ChatMessage> _messages = [];

  @override
  Future<void> save(List<ChatMessage> messages) async {
    _messages
      ..clear()
      ..addAll(messages);
  }

  @override
  Future<List<ChatMessage>> load() async => List.of(_messages);

  @override
  Future<void> clear() async {
    _messages.clear();
  }

  @override
  Future<void> appendMessage(ChatMessage message) async {
    _messages.add(message);
  }

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
  Future<List<ChatMessage>> loadConversation(String id) async =>
      List.of(_messages);

  @override
  Future<void> deleteConversation(String id) async {}

  @override
  Future<void> updateConversationTitle(String id, String title) async {}

  @override
  Stream<List<Conversation>> watchAllConversations() => Stream.value([]);

  @override
  void setActiveConversationId(String id) {}
}

class _MockSettingsRepository implements SettingsRepository {
  double _temperature = SettingsRepository.defaultTemperature;
  int _maxTokens = SettingsRepository.defaultMaxTokens;
  double _topP = SettingsRepository.defaultTopP;
  int _agentMaxIterations = SettingsRepository.defaultAgentMaxIterations;
  String? _providerConfig;
  bool _onboardingCompleted;

  _MockSettingsRepository({bool onboardingCompleted = true})
    : _onboardingCompleted = onboardingCompleted;

  @override
  double get temperature => _temperature;
  @override
  int get maxTokens => _maxTokens;
  @override
  double get topP => _topP;
  @override
  int get agentMaxIterations => _agentMaxIterations;
  @override
  String? get providerConfig => _providerConfig;
  @override
  bool get onboardingCompleted => _onboardingCompleted;

  @override
  Future<void> setTemperature(double value) async => _temperature = value;
  @override
  Future<void> setMaxTokens(int value) async => _maxTokens = value;
  @override
  Future<void> setTopP(double value) async => _topP = value;
  @override
  Future<void> setAgentMaxIterations(int value) async =>
      _agentMaxIterations = value;
  @override
  Future<void> setProviderConfig(String json) async => _providerConfig = json;
  @override
  Future<void> clearProviderConfig() async => _providerConfig = null;
  @override
  Future<void> setOnboardingCompleted() async => _onboardingCompleted = true;
}

class _CompletableAgent implements AgentStrategy {
  final List<AgentStep> stepsToEmit;
  final Completer<void> _completer = Completer<void>();
  bool? lastConfirmation;
  bool cancelCalled = false;

  _CompletableAgent({required this.stepsToEmit});

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

class _ErrorAgent implements AgentStrategy {
  final Object error;

  _ErrorAgent(this.error);

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
  void resolveConfirmation(bool approved) {}

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

class _DelayedAgent implements AgentStrategy {
  final List<AgentStep> stepsToEmit;
  final Completer<void> _completer = Completer<void>();
  bool cancelCalled = false;

  _DelayedAgent({required this.stepsToEmit});

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
  late _MockLlmRepository llmRepo;
  late _MockConversationRepository conversationRepo;

  Widget _buildAppWithRouter({required AgentStrategy agent}) {
    final settingsRepo = _MockSettingsRepository();

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

  Widget _buildChatScreen({required AgentStrategy agent}) {
    return ProviderScope(
      overrides: [
        llmRepositoryProvider.overrideWithValue(llmRepo),
        conversationRepositoryProvider.overrideWithValue(conversationRepo),
        settingsRepositoryProvider.overrideWithValue(_MockSettingsRepository()),
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

  group('E2E: Chat screen shows on launch', () {
    testWidgets('showsChatScreen', (tester) async {
      final agent = _CompletableAgent(stepsToEmit: []);
      await tester.pumpWidget(_buildAppWithRouter(agent: agent));
      await tester.pumpAndSettle();

      expect(find.text('AIOS'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('E2E: Send message without model', () {
    testWidgets('sendMessage_error_showsErrorBar', (tester) async {
      final agent = _ErrorAgent('Model not loaded');
      await tester.pumpWidget(_buildChatScreen(agent: agent));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('sendMessage_networkError_showsNetworkMessage', (tester) async {
      final agent = _ErrorAgent('Network connection failed');
      await tester.pumpWidget(_buildChatScreen(agent: agent));
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
      await tester.pumpWidget(_buildChatScreen(agent: agent));
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
      await tester.pumpWidget(_buildChatScreen(agent: agent));
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
      await tester.pumpWidget(_buildChatScreen(agent: agent));
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
      await tester.pumpWidget(_buildChatScreen(agent: agent));
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
      await tester.pumpWidget(_buildChatScreen(agent: agent));
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
      await tester.pumpWidget(_buildChatScreen(agent: agent));
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
