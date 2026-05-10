import 'package:aios/data/providers/remote/llm_remote_engine.dart';
import 'package:aios/domain/agent/llm_engine.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LlmRemoteEngine', () {
    late LlmRemoteEngine engine;

    setUp(() {
      const config = LlmProviderConfig(
        type: LlmProviderType.zai,
        apiKey: 'test-key',
        model: 'test-model',
        baseUrl: 'https://api.test.com',
      );
      engine = LlmRemoteEngine(config);
    });

    test('createSession_returnsLlmChatSession', () {
      final session = engine.createSession('You are a test assistant.');

      expect(session, isA<LlmChatSession>());
    });

    test('createSession_withDifferentPrompts_returnsSession', () {
      final session1 = engine.createSession('Prompt 1');
      final session2 = engine.createSession('Prompt 2');

      expect(session1, isNotNull);
      expect(session2, isNotNull);
    });

    test('cancelGeneration_doesNotThrow', () {
      expect(() => engine.cancelGeneration(), returnsNormally);
    });

    test('warmup_completesWithoutError', () async {
      await engine.warmup();

      expect(true, isTrue);
    });
  });
}
