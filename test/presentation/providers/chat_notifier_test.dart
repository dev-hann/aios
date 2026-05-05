import 'dart:async';

import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/presentation/providers/chat_notifier.dart';
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

  @override
  Future<void> save(List<ChatMessage> messages) async {
    savedMessages
      ..clear()
      ..addAll(messages);
  }

  @override
  Future<List<ChatMessage>> load() async => List.unmodifiable(savedMessages);

  @override
  Future<void> clear() async {
    savedMessages.clear();
  }

  @override
  Future<void> appendMessage(ChatMessage message) async {
    lastAppendedMessage = message;
    savedMessages.add(message);
  }
}

void main() {
  group('ChatNotifier', () {
    late _MockLlmRepository llmRepo;
    late _MockConversationRepository conversationRepo;
    late ChatNotifier notifier;

    setUp(() {
      llmRepo = _MockLlmRepository();
      conversationRepo = _MockConversationRepository();
      notifier = ChatNotifier(llmRepo, conversationRepo);
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
      llmRepo.tokens = [];
      await notifier.sendMessage('Hello');

      expect(notifier.state.messages, isNotEmpty);
      expect(notifier.state.messages.first.role, 'user');
      expect(notifier.state.messages.first.content, 'Hello');
    });

    test('sendMessage_setsIsGeneratingTrue', () async {
      llmRepo.tokens = ['Hi'];
      var wasGenerating = false;

      final future = notifier.sendMessage('Hello');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      wasGenerating = notifier.state.isGenerating;
      await future;

      expect(wasGenerating, isTrue);
    });

    test('sendMessage_appendsTokensToCurrentResponse', () async {
      llmRepo.tokens = ['Hello', ' ', 'World'];
      await notifier.sendMessage('Test');

      final assistantMessages =
          notifier.state.messages.where((m) => m.role == 'assistant').toList();
      expect(assistantMessages, isNotEmpty);
      expect(assistantMessages.first.content, 'Hello World');
    });

    test('sendMessage_addsAssistantMessageOnComplete', () async {
      llmRepo.tokens = ['Hi', ' there'];
      await notifier.sendMessage('Hello');

      final assistantMessages =
          notifier.state.messages.where((m) => m.role == 'assistant').toList();
      expect(assistantMessages, isNotEmpty);
      expect(assistantMessages.first.content, contains('Hi'));
    });

    test('sendMessage_setsIsGeneratingFalseOnComplete', () async {
      llmRepo.tokens = ['Response'];
      await notifier.sendMessage('Hello');

      expect(notifier.state.isGenerating, isFalse);
    });

    test('sendMessage_setsIsGeneratingFalseOnError', () async {
      llmRepo.sendMessageError = Exception('Test error');
      await notifier.sendMessage('Hello');

      expect(notifier.state.isGenerating, isFalse);
      expect(notifier.state.errorMessage, isNotNull);
    });

    test('stopGeneration_cancelsAndKeepsPartial', () async {
      llmRepo.tokens = ['Partial'];

      final sendFuture = notifier.sendMessage('Hello');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      await notifier.stopGeneration();
      await sendFuture;

      expect(llmRepo.stopGenerationCalled, isTrue);
      expect(notifier.state.isGenerating, isFalse);
      final assistantMessages =
          notifier.state.messages.where((m) => m.role == 'assistant').toList();
      expect(assistantMessages, isNotEmpty);
    });

    test('clearChat_resetsState', () async {
      llmRepo.tokens = ['Hi'];
      await notifier.sendMessage('Hello');

      expect(notifier.state.messages, isNotEmpty);

      await notifier.clearChat();

      expect(notifier.state.messages, isEmpty);
      expect(notifier.state.currentResponse, isEmpty);
      expect(notifier.state.isGenerating, isFalse);
    });

    test('loadModel_delegatesToRepository', () async {
      await notifier.loadModel('/path/to/model.gguf', contextSize: 4096);

      expect(llmRepo.lastModelPath, '/path/to/model.gguf');
      expect(llmRepo.lastContextSize, 4096);
    });

    test('sendMessage_doesNothingForEmptyText', () async {
      await notifier.sendMessage('');
      await notifier.sendMessage('   ');

      expect(notifier.state.messages, isEmpty);
    });

    test('sendMessage_emptyResponse_setsErrorMessage', () async {
      llmRepo.tokens = [];
      await notifier.sendMessage('Hello');

      final assistantMessages = notifier.state.messages
          .where((m) => m.role == 'assistant')
          .toList();
      expect(assistantMessages, isEmpty);
      expect(notifier.state.errorMessage, 'No response from model');
    });

    test('sendMessage_passesPreviousMessagesAsHistory', () async {
      llmRepo.tokens = ['Hi'];

      final prev = ChatMessage(
        id: 'prev',
        role: 'user',
        content: 'Old message',
        createdAt: DateTime.now(),
      );
      notifier.state = notifier.state.copyWith(messages: [prev]);

      await notifier.sendMessage('New message');

      expect(llmRepo.lastHistory, [prev]);
      expect(llmRepo.lastUserMessage, 'New message');
    });

    test('sendMessage_passesSettingsToRepository', () async {
      llmRepo.tokens = ['Ok'];

      await notifier.sendMessage(
        'Hello',
        temperature: 0.5,
        maxTokens: 256,
        topK: 30,
        topP: 0.8,
        repeatPenalty: 1.15,
      );

      expect(llmRepo.lastTemperature, 0.5);
      expect(llmRepo.lastMaxTokens, 256);
      expect(llmRepo.lastTopK, 30);
      expect(llmRepo.lastTopP, 0.8);
      expect(llmRepo.lastRepeatPenalty, 1.15);
    });

    test('sendMessage_savesAssistantMessageToConversationRepo', () async {
      llmRepo.tokens = ['Response'];
      await notifier.sendMessage('Hello');

      expect(conversationRepo.lastAppendedMessage, isNotNull);
      expect(conversationRepo.lastAppendedMessage!.role, 'assistant');
      expect(conversationRepo.lastAppendedMessage!.content, 'Response');
    });
  });
}
