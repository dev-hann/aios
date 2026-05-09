import 'dart:async';

import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/conversation.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/presentation/providers/chat_notifier.dart';
import 'package:aios/presentation/providers/chat_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockLlmRepository implements LlmRepository {
  final _stateController = StreamController<ServiceState>.broadcast();
  final _tokenController = StreamController<String>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  bool modelLoaded = false;
  String? lastModelPath;
  int? lastContextSize;
  List<ChatMessage> lastHistory = [];
  String? lastUserMessage;
  bool stopGenerationCalled = false;
  Object? sendMessageError;
  List<String> tokens = [];
  double? lastTemperature;
  int? lastMaxTokens;
  int? lastTopK;
  double? lastTopP;
  double? lastRepeatPenalty;

  @override
  Stream<ServiceState> get state => _stateController.stream;

  @override
  Stream<String> get tokenStream => _tokenController.stream;

  @override
  Stream<double> get loadProgress => _progressController.stream;

  @override
  Future<bool> loadModel(String path, {int? contextSize}) async {
    lastModelPath = path;
    lastContextSize = contextSize;
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
    if (sendMessageError != null) {
      throw sendMessageError!;
    }
    lastHistory = history;
    lastUserMessage = userMessage;
    lastTemperature = temperature;
    lastMaxTokens = maxTokens;
    lastTopK = topK;
    lastTopP = topP;
    lastRepeatPenalty = repeatPenalty;
    _stateController.add(ServiceState.generating);
    for (final token in tokens) {
      _tokenController.add(token);
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
    _stateController.add(ServiceState.ready);
  }

  @override
  Future<void> stopGeneration() async {
    stopGenerationCalled = true;
  }

  @override
  Future<void> saveSession(String path) async {}

  @override
  Future<void> loadSession(String path) async {}

  void dispose() {
    _stateController.close();
    _tokenController.close();
    _progressController.close();
  }
}

class _MockConversationRepository implements ConversationRepository {
  final List<ChatMessage> savedMessages = [];
  ChatMessage? lastAppendedMessage;
  final List<Conversation> _conversations = [];

  @override
  Future<void> save(List<ChatMessage> messages) async {
    savedMessages
      ..clear()
      ..addAll(messages);
  }

  @override
  Future<List<ChatMessage>> load() async =>
      List.unmodifiable(savedMessages);

  @override
  Future<void> clear() async {
    savedMessages.clear();
  }

  @override
  Future<void> appendMessage(ChatMessage message) async {
    lastAppendedMessage = message;
    savedMessages.add(message);
  }

  @override
  Future<Conversation> createConversation({String? title}) async {
    final conv = Conversation(
      id: 'conv_test_${_conversations.length}',
      title: title ?? '새 대화',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _conversations.insert(0, conv);
    return conv;
  }

  @override
  Future<List<Conversation>> getAllConversations() async =>
      List.unmodifiable(_conversations);

  @override
  Future<List<ChatMessage>> loadConversation(String id) async =>
      List.unmodifiable(savedMessages);

  @override
  Future<void> deleteConversation(String id) async {}

  @override
  Future<void> updateConversationTitle(String id, String title) async {}

  @override
  Stream<List<Conversation>> watchAllConversations() =>
      Stream.value(_conversations);

  @override
  void setActiveConversationId(String id) {}
}

class _MockAgentStrategy implements AgentStrategy {
  AgentResult? resultToReturn;
  String? lastPrompt;
  int? lastMaxIterations;
  int? lastMaxTokens;
  bool cancelCalled = false;
  bool? lastConfirmationApproved;
  List<AgentStep> capturedSteps = [];
  Duration executeDelay = Duration.zero;
  bool shouldThrow = false;
  Completer<void>? holdCompleter;

  @override
  Future<AgentResult> execute(
    String prompt, {
    int maxIterations = 8,
    int maxTokens = 512,
    void Function(AgentStep)? onStep,
  }) async {
    if (shouldThrow) {
      throw Exception('Agent execution failed');
    }

    lastPrompt = prompt;
    lastMaxIterations = maxIterations;
    lastMaxTokens = maxTokens;

    if (resultToReturn != null) {
      for (final step in resultToReturn!.steps) {
        capturedSteps.add(step);
        onStep?.call(step);
      }
    } else {
      onStep?.call(const AgentStep('answer', 'Default response'));
    }

    if (holdCompleter != null) {
      await holdCompleter!.future;
    }

    if (executeDelay > Duration.zero) {
      await Future<void>.delayed(executeDelay);
    }

    return resultToReturn ?? AgentResult(
      steps: [const AgentStep('answer', 'Default response')],
      success: true,
    );
  }

  @override
  void cancel() {
    cancelCalled = true;
  }

  @override
  void resolveConfirmation(bool approved) {
    lastConfirmationApproved = approved;
  }

  @override
  String getToolManifest() => '- test: test tool';

  @override
  List<({String role, String content})> getConversationHistory() => [];

  @override
  void clearHistory() {}

  @override
  Future<void> warmup() async {}

  @override
  void setConversationContext(ConversationContext? context) {}

  @override
  void setToolPreferenceTracker(
    ToolPreferenceTracker? tracker,
  ) {}
}

void main() {
  group('ChatNotifier', () {
    late _MockLlmRepository llmRepo;
    late _MockConversationRepository conversationRepo;
    late _MockAgentStrategy agent;
    late ChatNotifier notifier;

    setUp(() {
      llmRepo = _MockLlmRepository();
      conversationRepo = _MockConversationRepository();
      agent = _MockAgentStrategy();
      notifier = ChatNotifier(llmRepo, conversationRepo, agent);
    });

    tearDown(() {
      notifier.dispose();
      llmRepo.dispose();
    });

    test('initial_state_hasEmptyMessagesAndIdle', () {
      expect(notifier.state.messages, isEmpty);
      expect(notifier.state.isGenerating, isFalse);
      expect(notifier.state.currentResponse, isEmpty);
      expect(notifier.state.serviceState, ServiceState.idle);
      expect(notifier.state.errorMessage, isNull);
    });

    test('sendMessage_addsUserMessage', () async {
      await notifier.sendMessage('Hello');

      expect(notifier.state.messages, isNotEmpty);
      expect(notifier.state.messages.first.role, 'user');
      expect(notifier.state.messages.first.content, 'Hello');
    });

    test('sendMessage_callsAgentExecute', () async {
      await notifier.sendMessage('Hello');

      expect(agent.lastPrompt, 'Hello');
    });

    test('sendMessage_setsIsGeneratingTrue', () async {
      agent.executeDelay = const Duration(milliseconds: 100);
      var wasGenerating = false;

      final future = notifier.sendMessage('Hello');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      wasGenerating = notifier.state.isGenerating;
      await future;

      expect(wasGenerating, isTrue);
    });

    test('sendMessage_addsAssistantMessageFromAnswer', () async {
      agent.resultToReturn = AgentResult(
        steps: [const AgentStep('answer', 'Hi there')],
        success: true,
      );

      await notifier.sendMessage('Hello');

      final assistantMessages = notifier.state.messages
          .where((m) => m.role == 'assistant')
          .toList();
      expect(assistantMessages, isNotEmpty);
      expect(assistantMessages.first.content, 'Hi there');
    });

    test('sendMessage_setsIsGeneratingFalseOnComplete', () async {
      await notifier.sendMessage('Hello');

      expect(notifier.state.isGenerating, isFalse);
    });

    test('sendMessage_setsIsGeneratingFalseOnError', () async {
      agent.resultToReturn = AgentResult(
        steps: const [],
        success: false,
      );

      await notifier.sendMessage('Hello');

      expect(notifier.state.isGenerating, isFalse);
    });

    test('sendMessage_passesAgentMaxIterations', () async {
      await notifier.sendMessage(
        'Hello',
        agentMaxIterations: 5,
        maxTokens: 256,
      );

      expect(agent.lastMaxIterations, 5);
      expect(agent.lastMaxTokens, 256);
    });

    test('sendMessage_afterCompletion_clearsAgentSteps', () async {
      agent.resultToReturn = AgentResult(
        steps: [
          const AgentStep('thought', 'Thinking...'),
          const AgentStep('action', 'Using calculator',
              toolName: 'calculator', toolArgs: '{"expression": "2+2"}'),
          const AgentStep('observation', '4.0000'),
          const AgentStep('answer', 'The result is 4'),
        ],
        success: true,
      );

      await notifier.sendMessage('What is 2+2?');

      expect(notifier.state.agentSteps, isEmpty);
    });

    test('stopGeneration_cancelsAgent', () async {
      await notifier.stopGeneration();

      expect(agent.cancelCalled, isTrue);
      expect(notifier.state.isGenerating, isFalse);
    });

    test('clearChat_resetsState', () async {
      agent.resultToReturn = AgentResult(
        steps: [const AgentStep('answer', 'Hi')],
        success: true,
      );
      await notifier.sendMessage('Hello');

      expect(notifier.state.messages, isNotEmpty);

      await notifier.clearChat();

      expect(notifier.state.messages, isEmpty);
      expect(notifier.state.currentResponse, isEmpty);
      expect(notifier.state.isGenerating, isFalse);
    });

    test('resolveConfirmation_delegatesToAgent', () async {
      notifier.resolveConfirmation(true);
      expect(agent.lastConfirmationApproved, isTrue);

      notifier.resolveConfirmation(false);
      expect(agent.lastConfirmationApproved, isFalse);
    });

    test('loadModel_delegatesToRepository', () async {
      await notifier.loadModel(
        '/path/to/model.gguf',
        contextSize: 4096,
      );

      expect(llmRepo.lastModelPath, '/path/to/model.gguf');
      expect(llmRepo.lastContextSize, 4096);
    });

    test('sendMessage_doesNothingForEmptyText', () async {
      await notifier.sendMessage('');
      await notifier.sendMessage('   ');

      expect(notifier.state.messages, isEmpty);
    });

    test('sendMessage_savesAssistantMessageToConversationRepo',
        () async {
      agent.resultToReturn = AgentResult(
        steps: [const AgentStep('answer', 'Response')],
        success: true,
      );
      await notifier.sendMessage('Hello');

      expect(conversationRepo.lastAppendedMessage, isNotNull);
      expect(conversationRepo.lastAppendedMessage!.role, 'assistant');
      expect(conversationRepo.lastAppendedMessage!.content, 'Response');
    });

    test('handleStep_confirmationRequired_setsIsConfirmingAndStepTogether',
        () async {
      final states = <ChatState>[];
      notifier.addListener((state) => states.add(state));

      agent.resultToReturn = AgentResult(
        steps: [
          const AgentStep('thought', 'I need to open YouTube'),
          const AgentStep(
            'confirmation_required',
            'High risk: app_launcher',
            toolName: 'app_launcher',
            toolArgs: '{"action": "open_app", "package": "youtube"}',
            riskLevel: 'high',
          ),
        ],
        success: true,
      );

      await notifier.sendMessage('open youtube');

      final confirmState = states.firstWhere(
        (s) => s.isConfirming && s.agentSteps.any((s) => s.type == 'confirmation_required'),
        orElse: () => const ChatState(),
      );

      expect(confirmState.isConfirming, isTrue,
          reason: 'isConfirming and agentSteps must be set '
              'in the SAME state update');
      expect(
        confirmState.agentSteps
            .where((s) => s.type == 'confirmation_required')
            .isNotEmpty,
        isTrue,
        reason: 'confirmation_required step must exist when '
            'isConfirming is true',
      );
    });

    test('handleStep_confirmationRequired_noOrphanIsConfirming',
        () async {
      int confirmWithoutStepCount = 0;
      int stepWithoutConfirmCount = 0;

      notifier.addListener((state) {
        final hasConfirmStep = state.agentSteps
            .any((s) => s.type == 'confirmation_required');
        if (state.isConfirming && !hasConfirmStep) {
          confirmWithoutStepCount++;
        }
        if (hasConfirmStep && !state.isConfirming) {
          stepWithoutConfirmCount++;
        }
      });

      agent.resultToReturn = AgentResult(
        steps: [
          const AgentStep(
            'confirmation_required',
            'confirm',
            toolName: 'sms_sender',
            toolArgs: '{"action": "send"}',
            riskLevel: 'critical',
          ),
        ],
        success: true,
      );

      await notifier.sendMessage('send SMS');

      expect(confirmWithoutStepCount, 0,
          reason: 'isConfirming should never be true '
              'without a confirmation step');
      expect(stepWithoutConfirmCount, 0,
          reason: 'confirmation step should never exist '
              'without isConfirming being true');
    });

  test('resolveConfirmation_resetsIsConfirming', () async {
    final completer = Completer<void>();
    agent.resultToReturn = AgentResult(
      steps: [
        const AgentStep(
          'confirmation_required',
          'confirm',
          toolName: 'app_launcher',
          toolArgs: '{}',
          riskLevel: 'high',
        ),
      ],
      success: true,
    );
    agent.holdCompleter = completer;

    final future = notifier.sendMessage('open youtube');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(notifier.state.isConfirming, isTrue);

    notifier.resolveConfirmation(true);
    completer.complete();
    await future;

    expect(notifier.state.isConfirming, isFalse);
  });

    test('sendMessage_fullAgentFlow_thoughtActionObservationAnswer',
        () async {
      final stepTypes = <String>[];
      notifier.addListener((state) {
        for (final step in state.agentSteps) {
          if (!stepTypes.contains(step.type)) {
            stepTypes.add(step.type);
          }
        }
      });

      agent.resultToReturn = AgentResult(
        steps: [
          const AgentStep('thought', 'User wants to calculate'),
          const AgentStep('action', 'calc',
              toolName: 'calculator', toolArgs: '{"expression": "2+2"}'),
          const AgentStep('observation', '4.0000'),
          const AgentStep('answer', 'The result is 4'),
        ],
        success: true,
      );

      await notifier.sendMessage('What is 2+2?');

      expect(stepTypes, containsAll(['thought', 'action', 'observation']));
      final assistantMsgs = notifier.state.messages
          .where((m) => m.role == 'assistant')
          .toList();
      expect(assistantMsgs, hasLength(1));
      expect(assistantMsgs.first.content, 'The result is 4');
    });

    test('sendMessage_agentError_setsErrorMessage', () async {
      agent.resultToReturn = AgentResult(
        steps: [],
        success: false,
      );

      await notifier.sendMessage('Hello');

      expect(notifier.state.isGenerating, isFalse);
    });

    test('sendMessage_throwsException_setsErrorMessage', () async {
      agent.shouldThrow = true;

      await notifier.sendMessage('Hello');

      expect(notifier.state.isGenerating, isFalse);
      expect(notifier.state.errorMessage, isNotNull);
    });

    test('sendMessage_concurrentCalls_bothExecute', () async {
      final completer = Completer<void>();
      agent.holdCompleter = completer;
      agent.resultToReturn = AgentResult(
        steps: [const AgentStep('answer', 'First')],
        success: true,
      );

      final future1 = notifier.sendMessage('First');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state.isGenerating, isTrue);

      completer.complete();
      await future1;

      expect(notifier.state.isGenerating, isFalse);
    });

    test('sendMessage_preservesMessages_acrossMultipleCalls', () async {
      agent.resultToReturn = AgentResult(
        steps: [const AgentStep('answer', 'R1')],
        success: true,
      );
      await notifier.sendMessage('Q1');

      agent.resultToReturn = AgentResult(
        steps: [const AgentStep('answer', 'R2')],
        success: true,
      );
      await notifier.sendMessage('Q2');

      final messages = notifier.state.messages;
      expect(messages.where((m) => m.role == 'user'), hasLength(2));
      expect(messages.where((m) => m.role == 'assistant'), hasLength(2));
    });

    test('loadConversation_populatesMessages', () async {
      final testMessages = [
        ChatMessage(
          id: '1',
          role: 'user',
          content: 'Hello',
          createdAt: DateTime.now(),
        ),
        ChatMessage(
          id: '2',
          role: 'assistant',
          content: 'Hi',
          createdAt: DateTime.now(),
        ),
      ];
      conversationRepo.savedMessages.addAll(testMessages);

      await notifier.loadConversation();

      expect(notifier.state.messages, hasLength(2));
      expect(notifier.state.messages.first.content, 'Hello');
      expect(notifier.state.messages.last.content, 'Hi');
    });

    test('clearChat_clearsAgentHistory', () async {
      agent.resultToReturn = AgentResult(
        steps: [const AgentStep('answer', 'Hi')],
        success: true,
      );
      await notifier.sendMessage('Hello');

      await notifier.clearChat();

      expect(notifier.state.agentSteps, isEmpty);
    });

    test('sendMessage_withWhitespaceOnly_doesNotSend', () async {
      await notifier.sendMessage('   \t\n  ');

      expect(notifier.state.messages, isEmpty);
      expect(agent.lastPrompt, isNull);
    });

    test('sendMessage_passesAllParams', () async {
      await notifier.sendMessage(
        'Test',
        temperature: 0.5,
        maxTokens: 128,
        topK: 20,
        topP: 0.8,
        repeatPenalty: 1.5,
        agentMaxIterations: 3,
      );

      expect(agent.lastMaxIterations, 3);
      expect(agent.lastMaxTokens, 128);
    });

    test('state_reflectsServiceState_fromRepository', () async {
      llmRepo._stateController.add(ServiceState.loadingModel);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state.serviceState, ServiceState.loadingModel);

      llmRepo._stateController.add(ServiceState.ready);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state.serviceState, ServiceState.ready);
    });
  });
}
