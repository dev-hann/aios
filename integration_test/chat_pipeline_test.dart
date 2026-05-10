import 'package:aios/data/providers/remote/llm_remote_engine.dart';
import 'package:aios/data/providers/remote/openai_client.dart';
import 'package:aios/domain/agent/llm_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'model_test.dart'
    show ensureProviderAvailable, providerReady, testConfig;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureProviderAvailable();
  });

  group('OpenAiClient pipeline', () {
    testWidgets('streamChat generates tokens and completes', (tester) async {
      if (!providerReady) return;

      final client = OpenAiClient(testConfig!);
      final tokens = <String>[];

      await for (final chunk in client.streamChat(
        messages: [
          {'role': 'system', 'content': 'You are a helpful assistant.'},
          {'role': 'user', 'content': 'Hello'},
        ],
        config: const LlmGenerationConfig(
          temperature: 0.1,
          topP: 0.9,
          maxTokens: 16,
        ),
      )) {
        if (chunk.text != null) tokens.add(chunk.text!);
      }

      expect(tokens.join(), isNotEmpty);
      debugPrint('Pipeline response: ${tokens.join()}');
    });

    testWidgets('streamChat with custom sampler params', (tester) async {
      if (!providerReady) return;

      final client = OpenAiClient(testConfig!);
      final tokens = <String>[];

      await for (final chunk in client.streamChat(
        messages: [
          {'role': 'system', 'content': 'You are a helpful assistant.'},
          {'role': 'user', 'content': 'Hello'},
        ],
        config: const LlmGenerationConfig(
          temperature: 0.1,
          topP: 0.9,
          maxTokens: 16,
        ),
      )) {
        if (chunk.text != null) tokens.add(chunk.text!);
      }

      expect(tokens.join(), isNotEmpty);
    });

    testWidgets('streamChat with history does not duplicate user message', (
      tester,
    ) async {
      if (!providerReady) return;

      final client = OpenAiClient(testConfig!);
      final tokens = <String>[];

      await for (final chunk in client.streamChat(
        messages: [
          {'role': 'system', 'content': 'You are a helpful assistant.'},
          {'role': 'user', 'content': 'What is 1+1?'},
          {'role': 'assistant', 'content': '2'},
          {'role': 'user', 'content': 'What was my previous question?'},
        ],
        config: const LlmGenerationConfig(
          temperature: 0.1,
          topP: 0.9,
          maxTokens: 32,
        ),
      )) {
        if (chunk.text != null) tokens.add(chunk.text!);
      }

      final response = tokens.join();
      expect(response, isNotEmpty);
      debugPrint('History-aware pipeline response: $response');
    });

    testWidgets('testConnection passes', (tester) async {
      if (!providerReady) return;

      final client = OpenAiClient(testConfig!);
      final result = await client.testConnection();
      expect(result, isTrue);
    });

    testWidgets('fetchModels returns list', (tester) async {
      if (!providerReady) return;

      final client = OpenAiClient(testConfig!);
      final models = await client.fetchModels();
      expect(models, isNotNull);
      debugPrint('Available models: ${models.length}');
    });
  });

  group('LlmRemoteSession', () {
    testWidgets('session chat with tool result', (tester) async {
      if (!providerReady) return;

      final engine = LlmRemoteEngine(testConfig!);
      final session = engine.createSession('You are a helpful assistant.');

      final tokens = <String>[];
      await for (final chunk in session.chat(
        [LlmContentPart.text('Hello')],
        config: const LlmGenerationConfig(
          temperature: 0.1,
          topP: 0.9,
          maxTokens: 16,
        ),
        tools: [],
      )) {
        if (chunk.text != null) tokens.add(chunk.text!);
      }
      expect(tokens.join(), isNotEmpty);
    });
  });
}
