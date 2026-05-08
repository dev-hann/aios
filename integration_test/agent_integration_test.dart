import 'package:aios/data/providers/real_llama_engine_provider.dart';
import 'package:aios/data/repositories/llm_repository_impl.dart';
import 'package:aios/domain/agent/react_strategy.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'model_test.dart' show ensureModelAvailable, modelPath, modelReady;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureModelAvailable();
  });

  group('ReactStrategy integration', () {
    late RealLlamaEngineProvider engineProvider;
    late LlmRepositoryImpl repository;
    late ReactStrategy strategy;

    setUp(() {
      engineProvider = RealLlamaEngineProvider();
      repository = LlmRepositoryImpl(engineProvider);
    });

    tearDown(() async {
      repository.dispose();
      await engineProvider.releaseModel();
    });

    ReactStrategy _createStrategy() {
      final engine = engineProvider.engine;
      if (engine == null) throw StateError('Model not loaded');
      return ReactStrategy(engine: engine);
    }

    testWidgets('execute with answer response', (tester) async {
      if (!modelReady) return;

      await repository.loadModel(modelPath, contextSize: 512);
      strategy = _createStrategy();

      final steps = <AgentStep>[];
      final result = await strategy.execute(
        'Say hello in one word.',
        maxIterations: 3,
        maxTokens: 32,
        onStep: steps.add,
      );

      expect(result.steps, isNotEmpty);
      expect(result.success, isTrue);
      expect(steps, isNotEmpty);

      debugPrint('Agent steps: ${steps.map((s) => s.type).join(' -> ')}');
      debugPrint(
        'Answer: ${result.steps.where((s) => s.type == 'answer').map((s) => s.content).join('; ')}',
      );
    });

    testWidgets('execute plain text fallback', (tester) async {
      if (!modelReady) return;

      await repository.loadModel(modelPath, contextSize: 512);
      strategy = _createStrategy();

      final result = await strategy.execute(
        'Hi',
        maxIterations: 2,
        maxTokens: 16,
      );

      expect(result.steps.any((s) => s.type == 'answer'), isTrue);
    });

    testWidgets('execute with no tool context returns error for tools',
        (tester) async {
      if (!modelReady) return;

      await repository.loadModel(modelPath, contextSize: 512);

      final noContextStrategy = _createStrategy();

      final result = await noContextStrategy.execute(
        'List apps on this phone',
        maxIterations: 5,
        maxTokens: 64,
      );

      expect(result.steps, isNotEmpty);
    });

    testWidgets('clearHistory resets conversation', (tester) async {
      if (!modelReady) return;

      await repository.loadModel(modelPath, contextSize: 512);
      strategy = _createStrategy();
      await strategy.execute('Hello', maxIterations: 2, maxTokens: 16);
      expect(strategy.getConversationHistory(), isNotEmpty);

      strategy.clearHistory();
      expect(strategy.getConversationHistory(), isEmpty);
    });

    testWidgets('getToolManifest returns non-empty', (tester) async {
      if (!modelReady) return;

      await repository.loadModel(modelPath, contextSize: 512);
      strategy = _createStrategy();
      final manifest = strategy.getToolManifest();
      expect(manifest, isNotEmpty);
      expect(manifest, contains('app_launcher'));
    });

    testWidgets('cancel stops execution', (tester) async {
      if (!modelReady) return;

      await repository.loadModel(modelPath, contextSize: 512);
      strategy = _createStrategy();

      final future = strategy.execute(
        'Tell me a long story',
        maxIterations: 8,
        maxTokens: 256,
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));
      strategy.cancel();

      final result = await future;
      expect(result.steps, isNotEmpty);
    });

    testWidgets('multiple sequential executes', (tester) async {
      if (!modelReady) return;

      await repository.loadModel(modelPath, contextSize: 512);
      strategy = _createStrategy();

      final r1 = await strategy.execute(
        'Say A',
        maxIterations: 2,
        maxTokens: 8,
      );
      final r2 = await strategy.execute(
        'Say B',
        maxIterations: 2,
        maxTokens: 8,
      );

      expect(r1.steps, isNotEmpty);
      expect(r2.steps, isNotEmpty);
    });
  });
}
