import 'package:aios/data/providers/real_llama_engine_provider.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isGemma4Model', () {
    test('isGemma4Model_gemma4WithHyphen_returnsTrue', () {
      expect(
        RealLlamaEngineProvider.isGemma4Model(
          '/models/gemma-4-E2B-it-Q8_0.gguf',
        ),
        isTrue,
      );
    });

    test('isGemma4Model_gemma4WithoutHyphen_returnsTrue', () {
      expect(
        RealLlamaEngineProvider.isGemma4Model(
          '/models/gemma4-9b-it.gguf',
        ),
        isTrue,
      );
    });

    test('isGemma4Model_caseInsensitive_returnsTrue', () {
      expect(
        RealLlamaEngineProvider.isGemma4Model(
          '/models/Gemma-4-IT.gguf',
        ),
        isTrue,
      );
    });

    test('isGemma4Model_gemma2_returnsFalse', () {
      expect(
        RealLlamaEngineProvider.isGemma4Model(
          '/models/gemma-2b-it.gguf',
        ),
        isFalse,
      );
    });

    test('isGemma4Model_gemma3_returnsFalse', () {
      expect(
        RealLlamaEngineProvider.isGemma4Model(
          '/models/gemma-3-4b-it.gguf',
        ),
        isFalse,
      );
    });

    test('isGemma4Model_nonGemma_returnsFalse', () {
      expect(
        RealLlamaEngineProvider.isGemma4Model(
          '/models/llama-3-8b.gguf',
        ),
        isFalse,
      );
    });
  });

  group('renderGemma4Prompt', () {
    test('renderGemma4Prompt_singleUserMessage_rendersCorrectly', () {
      final result = RealLlamaEngineProvider.renderGemma4Prompt(
        [],
        'how are you?',
      );
      expect(result, contains('<|turn>user'));
      expect(result, contains('how are you?<turn|>'));
      expect(result, contains('<|turn>model'));
    });

    test('renderGemma4Prompt_historyWithUserAndAssistant_rendersCorrectly',
        () {
      final history = [
        ChatMessage(
          id: '1',
          role: 'user',
          content: 'hello',
          createdAt: DateTime.now(),
        ),
        ChatMessage(
          id: '2',
          role: 'assistant',
          content: 'hi there',
          createdAt: DateTime.now(),
        ),
      ];
      final result = RealLlamaEngineProvider.renderGemma4Prompt(
        history,
        'how are you?',
      );
      expect(result, contains('<|turn>user\nhello<turn|>'));
      expect(result, contains('<|turn>model\nhi there<turn|>'));
      expect(result, contains('how are you?<turn|>'));
    });

    test('renderGemma4Prompt_endsWithAssistantStartMarker', () {
      final result = RealLlamaEngineProvider.renderGemma4Prompt(
        [],
        'test',
      );
      expect(result.endsWith('<|turn>model\n'), isTrue);
    });

    test('renderGemma4Prompt_systemMessage_rendersCorrectly', () {
      final history = [
        ChatMessage(
          id: '1',
          role: 'system',
          content: 'You are helpful.',
          createdAt: DateTime.now(),
        ),
      ];
      final result = RealLlamaEngineProvider.renderGemma4Prompt(
        history,
        'hi',
      );
      expect(result, contains('<|turn>system\nYou are helpful.<turn|>'));
    });

    test('renderGemma4Prompt_assistantRole_mapsToModel', () {
      final history = [
        ChatMessage(
          id: '1',
          role: 'assistant',
          content: 'response',
          createdAt: DateTime.now(),
        ),
      ];
      final result = RealLlamaEngineProvider.renderGemma4Prompt(
        history,
        'next question',
      );
      expect(result, contains('<|turn>model\nresponse<turn|>'));
      expect(result, isNot(contains('<|turn>assistant')));
    });
  });
}
