import 'dart:async';

import 'package:aios/data/providers/llama_engine_provider.dart';
import 'package:aios/data/repositories/llm_repository_impl.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:flutter_test/flutter_test.dart';

class MockLlamaEngineProvider implements LlamaEngineProvider {
  bool _modelLoaded = false;
  String? lastModelPath;
  int? lastContextSize;
  bool releaseModelCalled = false;
  bool loadModelResult = true;
  Object? loadModelError;
  String modelInfo = 'MockModel v1.0';
  String contextUsage = '0/2048 tokens';
  bool stopGenerationCalled = false;
  String? lastSavePath;
  String? lastLoadPath;
  List<ChatMessage>? lastHistory;
  String? lastUserMessage;
  double? lastTemperature;
  int? lastMaxTokens;

  StreamController<String>? _activeController;

  void Function()? onLoadModel;

  Stream<String> startGenerateStream(List<String> tokens) {
    final controller = StreamController<String>();
    _activeController = controller;
    for (final token in tokens) {
      controller.add(token);
    }
    controller.close();
    _activeController = null;
    return controller.stream;
  }

  StreamController<String> createGenerateController() {
    final controller = StreamController<String>();
    _activeController = controller;
    return controller;
  }

  @override
  Future<bool> loadModel(String path, {int? contextSize}) async {
    lastModelPath = path;
    lastContextSize = contextSize;
    if (loadModelError != null) {
      throw loadModelError!;
    }
    onLoadModel?.call();
    _modelLoaded = loadModelResult;
    return loadModelResult;
  }

  @override
  Future<void> releaseModel() async {
    releaseModelCalled = true;
    _modelLoaded = false;
  }

  @override
  bool get isModelLoaded => _modelLoaded;

  @override
  String getModelInfo() => modelInfo;

  @override
  String getContextUsage() => contextUsage;

  @override
  Stream<String> generate(
    List<ChatMessage> history,
    String userMessage, {
    double? temperature,
    int? maxTokens,
  }) {
    lastHistory = history;
    lastUserMessage = userMessage;
    lastTemperature = temperature;
    lastMaxTokens = maxTokens;
    if (_activeController != null) {
      return _activeController!.stream;
    }
    return const Stream.empty();
  }

  @override
  Future<void> stopGeneration() async {
    stopGenerationCalled = true;
  }

  @override
  Future<void> saveState(String path) async {
    lastSavePath = path;
  }

  @override
  Future<void> loadState(String path) async {
    lastLoadPath = path;
  }
}

void main() {
  group('LlmRepositoryImpl', () {
    late MockLlamaEngineProvider mockProvider;
    late LlmRepositoryImpl repository;

    setUp(() {
      mockProvider = MockLlamaEngineProvider();
      repository = LlmRepositoryImpl(mockProvider);
    });

    tearDown(() {
      repository.dispose();
    });

    test('loadModel_success_emitsLoadingThenReady', () async {
      final states = <ServiceState>[];
      final progressValues = <double>[];
      repository.state.listen(states.add);
      repository.loadProgress.listen(progressValues.add);

      final result = await repository.loadModel('/path/to/model.gguf');

      expect(result, isTrue);
      expect(states, contains(ServiceState.loadingModel));
      expect(states, contains(ServiceState.ready));
      expect(progressValues, contains(1.0));
    });

    test('loadModel_failure_emitsError', () async {
      mockProvider.loadModelResult = false;
      final states = <ServiceState>[];
      repository.state.listen(states.add);

      final result = await repository.loadModel('/path/to/model.gguf');

      expect(result, isFalse);
      expect(states, contains(ServiceState.loadingModel));
      expect(states, contains(ServiceState.error));
    });

    test('loadModel_exception_emitsError', () async {
      mockProvider.loadModelError = Exception('file not found');
      final states = <ServiceState>[];
      repository.state.listen(states.add);

      final result = await repository.loadModel('/bad/path.gguf');

      expect(result, isFalse);
      expect(states, contains(ServiceState.error));
    });

    test('loadModel_passesContextSize', () async {
      await repository.loadModel('/path.gguf', contextSize: 4096);

      expect(mockProvider.lastContextSize, 4096);
    });

    test('sendMessage_emitsTokensThenCompletes', () async {
      await repository.loadModel('/model.gguf');

      final generateController = StreamController<String>();
      mockProvider._activeController = generateController;

      final tokens = <String>[];
      repository.tokenStream.listen(tokens.add);

      final future = repository.sendMessage(
        [],
        userMessage: 'Hello',
      );

      generateController.add('Hello');
      generateController.add(' world');
      await generateController.close();
      await future;

      expect(tokens, ['Hello', ' world']);
    });

    test('sendMessage_updatesStateToGenerating', () async {
      await repository.loadModel('/model.gguf');

      final controller = StreamController<String>();
      mockProvider._activeController = controller;

      final states = <ServiceState>[];
      repository.state.listen(states.add);

      final future = repository.sendMessage(
        [],
        userMessage: 'Hello',
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(states, contains(ServiceState.generating));

      controller.add('Hi');
      await controller.close();
      await future;
    });

    test('sendMessage_afterCompletion_returnsToReady', () async {
      await repository.loadModel('/model.gguf');

      final states = <ServiceState>[];
      repository.state.listen(states.add);

      mockProvider._activeController = null;
      await repository.sendMessage(
        [],
        userMessage: 'Hello',
      );

      expect(states.last, ServiceState.ready);
    });

    test('sendMessage_passesParameters', () async {
      await repository.loadModel('/model.gguf');

      final history = [
        ChatMessage(
          id: '1',
          role: 'user',
          content: 'prev',
          createdAt: DateTime.now(),
        ),
      ];

      mockProvider._activeController = null;
      await repository.sendMessage(
        history,
        userMessage: 'test',
        temperature: 0.7,
        maxTokens: 512,
      );

      expect(mockProvider.lastHistory, history);
      expect(mockProvider.lastUserMessage, 'test');
      expect(mockProvider.lastTemperature, 0.7);
      expect(mockProvider.lastMaxTokens, 512);
    });

    test('stopGeneration_cancelsAndReturnsToReady', () async {
      await repository.loadModel('/model.gguf');

      final controller = StreamController<String>();
      mockProvider._activeController = controller;

      final states = <ServiceState>[];
      repository.state.listen(states.add);

      final future = repository.sendMessage(
        [],
        userMessage: 'Hello',
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      await repository.stopGeneration();

      await controller.close();
      await future;

      expect(mockProvider.stopGenerationCalled, isTrue);
      expect(states.last, ServiceState.ready);
    });

    test('releaseModel_emitsIdle', () async {
      final states = <ServiceState>[];
      repository.state.listen(states.add);

      await repository.releaseModel();

      expect(mockProvider.releaseModelCalled, isTrue);
      expect(states, contains(ServiceState.idle));
    });

    test('isModelLoaded_reflectsState', () async {
      expect(repository.isModelLoaded, isFalse);

      await repository.loadModel('/model.gguf');
      expect(repository.isModelLoaded, isTrue);

      await repository.releaseModel();
      expect(repository.isModelLoaded, isFalse);
    });

    test('getModelInfo_delegatesToProvider', () async {
      mockProvider.modelInfo = 'Gemma 2B Q4';

      final info = repository.getModelInfo();

      expect(info, 'Gemma 2B Q4');
    });

    test('getContextUsage_delegatesToProvider', () async {
      mockProvider.contextUsage = '512/2048 tokens';

      final usage = repository.getContextUsage();

      expect(usage, '512/2048 tokens');
    });

    test('saveSession_delegatesToProvider', () async {
      await repository.saveSession('/save/state.bin');

      expect(mockProvider.lastSavePath, '/save/state.bin');
    });

    test('loadSession_delegatesToProvider', () async {
      await repository.loadSession('/load/state.bin');

      expect(mockProvider.lastLoadPath, '/load/state.bin');
    });

    test('sendMessage_withoutModel_doesNotSend', () async {
      final tokens = <String>[];
      final states = <ServiceState>[];
      repository.tokenStream.listen(tokens.add);
      repository.state.listen(states.add);

      await repository.sendMessage(
        [],
        userMessage: 'Hello',
      );

      expect(mockProvider.lastUserMessage, isNull);
      expect(tokens, isEmpty);
      expect(states, contains(ServiceState.error));
    });

    test('resetContext_emitsReadyIfLoaded', () async {
      await repository.loadModel('/model.gguf');

      final states = <ServiceState>[];
      repository.state.listen(states.add);

      await repository.resetContext();

      expect(states, contains(ServiceState.ready));
    });

    test('releaseModel_exception_emitsIdle', () async {
      mockProvider.releaseModelCalled = true;
      mockProvider._modelLoaded = true;

      final releasingProvider = MockLlamaEngineProvider();
      releasingProvider._modelLoaded = true;

      final repo = LlmRepositoryImpl(releasingProvider);

      final states = <ServiceState>[];
      repo.state.listen(states.add);

      await repo.releaseModel();

      expect(states, contains(ServiceState.idle));

      repo.dispose();
    });

    test('sendMessage_streamError_emitsReadyAndCompletes', () async {
      await repository.loadModel('/model.gguf');

      final errorController = StreamController<String>();
      mockProvider._activeController = errorController;

      final states = <ServiceState>[];
      repository.state.listen(states.add);

      final future = repository.sendMessage(
        [],
        userMessage: 'Hello',
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      errorController.addError(Exception('stream error'));
      await errorController.close();
      await future;

      expect(states.last, ServiceState.ready);
    });

    test('resetContext_notLoaded_doesNotEmitReady', () async {
      final states = <ServiceState>[];
      repository.state.listen(states.add);

      await repository.resetContext();

      expect(states, isNot(contains(ServiceState.ready)));
    });

    test('loadModel_emitsZeroProgressAtStart', () async {
      final progressValues = <double>[];
      repository.loadProgress.listen(progressValues.add);

      await repository.loadModel('/model.gguf');

      expect(progressValues.first, 0.0);
      expect(progressValues.last, 1.0);
    });

    test('dispose_closesControllers', () async {
      final stateFuture = repository.state.drain<void>();
      final tokenFuture = repository.tokenStream.drain<void>();
      final progressFuture = repository.loadProgress.drain<void>();

      repository.dispose();

      await expectLater(stateFuture, completes);
      await expectLater(tokenFuture, completes);
      await expectLater(progressFuture, completes);
    });
  });
}
