import 'package:aios/data/providers/real_llama_engine_provider.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart' hide ChatMessage;

void main() {
  group('classifyTemplateByName', () {
    test('detects gemma from filename', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/data/models/gemma-2b-it-Q4_K_M.gguf',
        ),
        KnownChatTemplates.gemma,
      );
    });

    test('detects gemma case insensitively', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/Gemma-3-4B-it.gguf',
        ),
        KnownChatTemplates.gemma,
      );
    });

    test('detects llama3 from filename with hyphen', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/llama-3.1-8B-Instruct-Q4.gguf',
        ),
        KnownChatTemplates.llama3,
      );
    });

    test('detects llama3 from filename without hyphen', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/llama3-8B-Instruct.gguf',
        ),
        KnownChatTemplates.llama3,
      );
    });

    test('does not match llama2 as llama3', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/llama-2-7b-chat.gguf',
        ),
        isNull,
      );
    });

    test('detects mistral from filename', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/mistral-7b-instruct-v0.3.gguf',
        ),
        KnownChatTemplates.mistral,
      );
    });

    test('detects phi3 from filename with hyphen', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/phi-3-mini-4k-instruct.gguf',
        ),
        KnownChatTemplates.phi3,
      );
    });

    test('detects phi3 from filename without hyphen', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/phi3-mini.gguf',
        ),
        KnownChatTemplates.phi3,
      );
    });

    test('detects qwen as chatml', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/qwen2.5-7b-instruct.gguf',
        ),
        KnownChatTemplates.chatml,
      );
    });

    test('detects deepseek from filename', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/deepseek-r1-7b.gguf',
        ),
        KnownChatTemplates.deepseek,
      );
    });

    test('detects command-r from filename', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/command-r-v01.gguf',
        ),
        KnownChatTemplates.commandR,
      );
    });

    test('detects vicuna from filename', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/vicuna-7b-v1.5.gguf',
        ),
        KnownChatTemplates.vicuna,
      );
    });

    test('detects falcon from filename', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/falcon3-7b-instruct.gguf',
        ),
        KnownChatTemplates.falcon3,
      );
    });

    test('returns null for unknown model', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/unknown-model.gguf',
        ),
        isNull,
      );
    });

    test('returns null for empty path', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(''),
        isNull,
      );
    });

    test(
        'classifies unsloth gemma variant via filename '
        'when gguf template lacks magic substring', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/data/models/gemma-4-E2B-it-Q8_0.gguf',
        ),
        KnownChatTemplates.gemma,
      );
    });
  });

  group('isGemma4Model', () {
    test('detects gemma-4 with hyphen', () {
      expect(
        RealLlamaEngineProvider.isGemma4Model(
          '/models/gemma-4-E2B-it-Q8_0.gguf',
        ),
        isTrue,
      );
    });

    test('detects gemma4 without hyphen', () {
      expect(
        RealLlamaEngineProvider.isGemma4Model(
          '/models/gemma4-9b-it.gguf',
        ),
        isTrue,
      );
    });

    test('detects case insensitively', () {
      expect(
        RealLlamaEngineProvider.isGemma4Model(
          '/models/Gemma-4-IT.gguf',
        ),
        isTrue,
      );
    });

    test('returns false for gemma 2', () {
      expect(
        RealLlamaEngineProvider.isGemma4Model(
          '/models/gemma-2b-it.gguf',
        ),
        isFalse,
      );
    });

    test('returns false for gemma 3', () {
      expect(
        RealLlamaEngineProvider.isGemma4Model(
          '/models/gemma-3-4b-it.gguf',
        ),
        isFalse,
      );
    });

    test('returns false for non-gemma', () {
      expect(
        RealLlamaEngineProvider.isGemma4Model(
          '/models/llama-3-8b.gguf',
        ),
        isFalse,
      );
    });
  });

  group('renderGemma4Prompt', () {
    test('renders single user message', () {
      final result = RealLlamaEngineProvider.renderGemma4Prompt(
        [],
        'how are you?',
      );
      expect(result, contains('<|turn>user'));
      expect(result, contains('how are you?<turn|>'));
      expect(result, contains('<|turn>model'));
    });

    test('renders history with user and assistant', () {
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

    test('ends with assistant start marker', () {
      final result = RealLlamaEngineProvider.renderGemma4Prompt(
        [],
        'test',
      );
      expect(result.endsWith('<|turn>model\n'), isTrue);
    });

    test('renders system message', () {
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

    test('maps assistant role to model', () {
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
