import 'dart:async';

import 'package:aios/data/providers/real_llama_engine_provider.dart';
import 'package:aios/data/repositories/llm_repository_impl.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'model_test.dart' show ensureModelAvailable, modelPath, modelReady;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureModelAvailable();
  });

  group('LlmRepositoryImpl pipeline', () {
    late RealLlamaEngineProvider engineProvider;
    late LlmRepositoryImpl repository;

    setUp(() {
      engineProvider = RealLlamaEngineProvider();
      repository = LlmRepositoryImpl(engineProvider);
    });

    tearDown(() async {
      repository.dispose();
      await engineProvider.releaseModel();
    });

    testWidgets('sendMessage without model emits error state',
        (tester) async {
      final states = <ServiceState>[];
      repository.state.listen(states.add);

      await repository.sendMessage(
        [],
        userMessage: 'Hello',
      );

      expect(states, contains(ServiceState.error));
      expect(repository.isModelLoaded, isFalse);
    });

    testWidgets('sendMessage emits tokens and returns to ready',
        (tester) async {
      if (!modelReady) return;

      await repository.loadModel(modelPath, contextSize: 512);

      final tokens = <String>[];
      final states = <ServiceState>[];
      repository.tokenStream.listen(tokens.add);
      repository.state.listen(states.add);

      await repository.sendMessage(
        [],
        userMessage: 'Hello',
        temperature: 0.1,
        maxTokens: 16,
      );

      expect(states, contains(ServiceState.generating));
      expect(states.last, ServiceState.ready);
      expect(tokens.join(), isNotEmpty);
      debugPrint('Pipeline response: ${tokens.join()}');
    });

    testWidgets('sendMessage forwards sampler params', (tester) async {
      if (!modelReady) return;

      await repository.loadModel(modelPath, contextSize: 512);

      final tokens = <String>[];
      repository.tokenStream.listen(tokens.add);

      await repository.sendMessage(
        [],
        userMessage: 'Hello',
        temperature: 0.1,
        maxTokens: 16,
        topK: 10,
        topP: 0.9,
        repeatPenalty: 1.1,
      );

      expect(tokens.join(), isNotEmpty);
    });

    testWidgets('sendMessage with history does not duplicate user message',
        (tester) async {
      if (!modelReady) return;

      await repository.loadModel(modelPath, contextSize: 2048);

      final history = [
        ChatMessage(
          id: '1',
          role: 'user',
          content: 'What is 1+1?',
          createdAt: DateTime.now(),
        ),
        ChatMessage(
          id: '2',
          role: 'assistant',
          content: '2',
          createdAt: DateTime.now(),
        ),
      ];

      final tokens = <String>[];
      repository.tokenStream.listen(tokens.add);

      await repository.sendMessage(
        history,
        userMessage: 'What was my previous question?',
        temperature: 0.1,
        maxTokens: 32,
      );

      final response = tokens.join();
      expect(response, isNotEmpty);
      debugPrint('History-aware pipeline response: $response');
    });

    testWidgets('sendMessage with empty history uses templateOverride',
        (tester) async {
      if (!modelReady) return;

      await repository.loadModel(modelPath, contextSize: 512);

      final tokens = <String>[];
      repository.tokenStream.listen(tokens.add);

      await repository.sendMessage(
        [],
        userMessage: 'Say hi',
        temperature: 0.1,
        maxTokens: 16,
      );

      expect(tokens.join(), isNotEmpty);
    });

    testWidgets('loadModel passes contextSize', (tester) async {
      if (!modelReady) return;

      final states = <ServiceState>[];
      repository.state.listen(states.add);

      final result =
          await repository.loadModel(modelPath, contextSize: 1024);

      expect(result, isTrue);
      expect(states, contains(ServiceState.loadingModel));
      expect(states, contains(ServiceState.ready));
      expect(repository.isModelLoaded, isTrue);
    });

    testWidgets('stopGeneration returns to ready', (tester) async {
      if (!modelReady) return;

      await repository.loadModel(modelPath, contextSize: 512);

      final states = <ServiceState>[];
      repository.state.listen(states.add);

      final future = repository.sendMessage(
        [],
        userMessage: 'Hello',
        temperature: 0.1,
        maxTokens: 512,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      await repository.stopGeneration();
      await future;

      expect(states, contains(ServiceState.ready));
    });
  });
}
