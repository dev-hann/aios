import 'dart:async';

import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockLlmRepository implements LlmRepository {
  final _stateController = StreamController<ServiceState>.broadcast();
  final _tokenController = StreamController<String>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  bool modelLoaded = false;
  String? lastModelPath;
  List<ChatMessage> lastHistory = [];
  String? lastUserMessage;
  String? lastSessionPath;
  bool stopGenerationCalled = false;
  bool releaseModelCalled = false;

  @override
  Stream<ServiceState> get state => _stateController.stream;

  @override
  Stream<String> get tokenStream => _tokenController.stream;

  @override
  Stream<double> get loadProgress => _progressController.stream;

  @override
  Future<bool> loadModel(String path, {int? contextSize}) async {
    lastModelPath = path;
    modelLoaded = true;
    _stateController.add(ServiceState.ready);
    return true;
  }

  @override
  Future<void> releaseModel() async {
    releaseModelCalled = true;
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
    lastHistory = history;
    lastUserMessage = userMessage;
    _stateController.add(ServiceState.generating);
    _tokenController.add('Hello');
    _stateController.add(ServiceState.ready);
  }

  @override
  Future<void> stopGeneration() async {
    stopGenerationCalled = true;
  }

  @override
  Future<void> saveSession(String path) async {
    lastSessionPath = path;
  }

  @override
  Future<void> loadSession(String path) async {
    lastSessionPath = path;
  }
}

void main() {
  group('LlmRepository', () {
    late _MockLlmRepository repository;

    setUp(() {
      repository = _MockLlmRepository();
    });

    test('load_model_returnsTrue_and_setsModelLoaded', () async {
      final result = await repository.loadModel('/path/to/model.gguf');

      expect(result, isTrue);
      expect(repository.isModelLoaded, isTrue);
      expect(repository.lastModelPath, '/path/to/model.gguf');
    });

    test('load_model_emitsReadyState', () async {
      final states = <ServiceState>[];
      repository.state.listen(states.add);

      await repository.loadModel('/path/to/model.gguf');

      expect(states, contains(ServiceState.ready));
    });

    test('send_message_emitsGeneratingAndToken', () async {
      final states = <ServiceState>[];
      final tokens = <String>[];
      repository.state.listen(states.add);
      repository.tokenStream.listen(tokens.add);

      await repository.sendMessage(
        [],
        userMessage: 'Hello',
      );

      expect(states, contains(ServiceState.generating));
      expect(tokens, contains('Hello'));
      expect(repository.lastUserMessage, 'Hello');
    });

    test('stop_generation_setsFlag', () async {
      await repository.stopGeneration();

      expect(repository.stopGenerationCalled, isTrue);
    });

    test('release_model_setsModelNotLoaded', () async {
      await repository.loadModel('/path/to/model.gguf');
      expect(repository.isModelLoaded, isTrue);

      await repository.releaseModel();

      expect(repository.isModelLoaded, isFalse);
      expect(repository.releaseModelCalled, isTrue);
    });

    test('release_model_emitsIdleState', () async {
      final states = <ServiceState>[];
      repository.state.listen(states.add);

      await repository.releaseModel();

      expect(states, contains(ServiceState.idle));
    });

    test('save_session_storesPath', () async {
      await repository.saveSession('/path/to/session.bin');

      expect(repository.lastSessionPath, '/path/to/session.bin');
    });

    test('load_session_readsPath', () async {
      await repository.loadSession('/path/to/session.bin');

      expect(repository.lastSessionPath, '/path/to/session.bin');
    });

    test('get_model_info_returnsString', () {
      final info = repository.getModelInfo();

      expect(info, isA<String>());
      expect(info, isNotEmpty);
    });

    test('get_context_usage_returnsString', () {
      final usage = repository.getContextUsage();

      expect(usage, isA<String>());
      expect(usage, isNotEmpty);
    });
  });
}
