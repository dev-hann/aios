import 'package:aios/data/providers/remote/llm_remote_engine.dart';
import 'package:aios/data/providers/remote/openai_client.dart';
import 'package:aios/data/repositories/llm_repository_impl.dart';
import 'package:aios/domain/agent/llm_engine.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _testApiKey = String.fromEnvironment('TEST_API_KEY');
const _testModel = String.fromEnvironment(
  'TEST_MODEL',
  defaultValue: 'gpt-4o-mini',
);
const _testBaseUrl = String.fromEnvironment('TEST_BASE_URL');
const _testProviderType = String.fromEnvironment('TEST_PROVIDER_TYPE');

LlmProviderConfig? testConfig;
bool providerReady = false;

LlmProviderType _resolveProviderType() {
  switch (_testProviderType.toLowerCase()) {
    case 'zai':
      return LlmProviderType.zai;
    case 'zaicoding':
      return LlmProviderType.zaiCoding;
    case 'openai':
      return LlmProviderType.openai;
    case 'anthropic':
      return LlmProviderType.anthropic;
    case 'custom':
      return LlmProviderType.custom;
    default:
      return _testBaseUrl.isEmpty
          ? LlmProviderType.openai
          : LlmProviderType.custom;
  }
}

Future<bool> ensureProviderAvailable() async {
  if (_testApiKey.isEmpty) {
    debugPrint('No TEST_API_KEY provided, tests will be skipped.');
    return false;
  }

  testConfig = LlmProviderConfig(
    type: _resolveProviderType(),
    apiKey: _testApiKey,
    model: _testModel,
    baseUrl: _testBaseUrl.isEmpty ? null : _testBaseUrl,
  );

  try {
    final client = OpenAiClient(testConfig!);
    final ok = await client.testConnection();
    if (ok) {
      debugPrint(
        'Provider ready: ${testConfig!.model}@${testConfig!.effectiveBaseUrl}',
      );
      return true;
    }
    debugPrint('Connection test failed');
    return false;
  } on Object catch (e) {
    debugPrint('Provider connection failed: $e');
    return false;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    providerReady = await ensureProviderAvailable();
  });

  group('LlmRemoteEngine', () {
    late LlmRemoteEngine engine;

    setUp(() {
      if (!providerReady) return;
      engine = LlmRemoteEngine(testConfig!);
    });

    testWidgets('creates session without error', (tester) async {
      if (!providerReady) return;
      final session = engine.createSession('You are a helpful assistant.');
      expect(session, isNotNull);
    });

    testWidgets('chat generates text response', (tester) async {
      if (!providerReady) return;

      final session = engine.createSession('You are a helpful assistant.');
      final tokens = <String>[];
      await for (final chunk in session.chat(
        [const LlmContentPart.text('Hello')],
        config: const LlmGenerationConfig(
          temperature: 0.1,
          topP: 0.9,
          maxTokens: 256,
        ),
        tools: [],
      )) {
        if (chunk.text != null) tokens.add(chunk.text!);
      }
      final result = tokens.join();
      if (result.isEmpty) {
        debugPrint(
          'Remote response was empty '
          '(reasoning model may consume tokens for thinking)',
        );
      } else {
        debugPrint('Remote response: $result');
      }
      expect(result, isNotEmpty);
    });

    testWidgets('chat with history context', (tester) async {
      if (!providerReady) return;

      final session = engine.createSession('You are a helpful assistant.');
      final tokens1 = <String>[];
      await for (final chunk in session.chat(
        [const LlmContentPart.text('My favorite number is 42.')],
        config: const LlmGenerationConfig(
          temperature: 0.1,
          topP: 0.9,
          maxTokens: 256,
        ),
        tools: [],
      )) {
        if (chunk.text != null) tokens1.add(chunk.text!);
      }
      expect(tokens1.join(), isNotEmpty);

      final tokens2 = <String>[];
      await for (final chunk in session.chat(
        [const LlmContentPart.text('What was my favorite number?')],
        config: const LlmGenerationConfig(
          temperature: 0.1,
          topP: 0.9,
          maxTokens: 256,
        ),
        tools: [],
      )) {
        if (chunk.text != null) tokens2.add(chunk.text!);
      }
      final response = tokens2.join();
      expect(response, isNotEmpty);
      debugPrint('History-aware response: $response');
    });

    testWidgets('warmup completes without error', (tester) async {
      if (!providerReady) return;
      await engine.warmup();
    });

    testWidgets('cancelGeneration does not throw', (tester) async {
      if (!providerReady) return;
      engine.cancelGeneration();
    });
  });

  group('LlmRepositoryImpl', () {
    late LlmRepositoryImpl repository;

    setUp(() {
      repository = LlmRepositoryImpl();
    });

    tearDown(() {
      repository.dispose();
    });

    testWidgets('connect with valid config returns true', (tester) async {
      if (!providerReady) return;

      final states = <ServiceState>[];
      repository.state.listen(states.add);

      final result = await repository.connect(testConfig!);
      expect(result, isTrue);
      expect(states, contains(ServiceState.loadingModel));
      expect(states, contains(ServiceState.ready));
    });

    testWidgets('connect with invalid config returns false', (tester) async {
      const badConfig = LlmProviderConfig(
        type: LlmProviderType.openai,
        apiKey: 'invalid-key',
        model: 'nonexistent-model',
      );

      final result = await repository.connect(badConfig);
      expect(result, isFalse);
    });

    testWidgets('fetchModels returns list', (tester) async {
      if (!providerReady) return;

      final models = await repository.fetchModels(testConfig!);
      debugPrint('Available models: ${models.length}');
      expect(models, isNotNull);
    });

    testWidgets('testConnection returns true', (tester) async {
      if (!providerReady) return;

      final result = await repository.testConnection(testConfig!);
      expect(result, isTrue);
    });

    testWidgets('testConnection with bad key returns false', (tester) async {
      const badConfig = LlmProviderConfig(
        type: LlmProviderType.openai,
        apiKey: 'bad-key',
        model: 'gpt-4o-mini',
      );

      final result = await repository.testConnection(badConfig);
      expect(result, isFalse);
    });

    testWidgets('disconnect emits idle', (tester) async {
      if (!providerReady) return;

      final states = <ServiceState>[];
      repository.state.listen(states.add);

      await repository.connect(testConfig!);
      await repository.disconnect();

      expect(states, contains(ServiceState.idle));
    });
  });
}
