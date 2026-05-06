import 'package:aios/data/providers/real_llama_engine_provider.dart';
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
}
