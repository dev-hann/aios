import 'package:aios/data/providers/real_llama_engine_provider.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart' hide ChatMessage;

void main() {
  group('classifyTemplateByName', () {
    test('classifyTemplateByName_gemmaFilename_returnsGemma', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/data/models/gemma-2b-it-Q4_K_M.gguf',
        ),
        KnownChatTemplates.gemma,
      );
    });

    test('classifyTemplateByName_gemmaCaseInsensitive_returnsGemma', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/Gemma-3-4B-it.gguf',
        ),
        KnownChatTemplates.gemma,
      );
    });

    test('classifyTemplateByName_llama3WithHyphen_returnsLlama3', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/llama-3.1-8B-Instruct-Q4.gguf',
        ),
        KnownChatTemplates.llama3,
      );
    });

    test('classifyTemplateByName_llama3WithoutHyphen_returnsLlama3', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/llama3-8B-Instruct.gguf',
        ),
        KnownChatTemplates.llama3,
      );
    });

    test('classifyTemplateByName_llama2_returnsNull', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/llama-2-7b-chat.gguf',
        ),
        isNull,
      );
    });

    test('classifyTemplateByName_mistralFilename_returnsMistral', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/mistral-7b-instruct-v0.3.gguf',
        ),
        KnownChatTemplates.mistral,
      );
    });

    test('classifyTemplateByName_phi3WithHyphen_returnsPhi3', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/phi-3-mini-4k-instruct.gguf',
        ),
        KnownChatTemplates.phi3,
      );
    });

    test('classifyTemplateByName_phi3WithoutHyphen_returnsPhi3', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/phi3-mini.gguf',
        ),
        KnownChatTemplates.phi3,
      );
    });

    test('classifyTemplateByName_qwenFilename_returnsChatml', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/qwen2.5-7b-instruct.gguf',
        ),
        KnownChatTemplates.chatml,
      );
    });

    test('classifyTemplateByName_deepseekFilename_returnsDeepseek', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/deepseek-r1-7b.gguf',
        ),
        KnownChatTemplates.deepseek,
      );
    });

    test('classifyTemplateByName_commandRFilename_returnsCommandR', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/command-r-v01.gguf',
        ),
        KnownChatTemplates.commandR,
      );
    });

    test('classifyTemplateByName_vicunaFilename_returnsVicuna', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/vicuna-7b-v1.5.gguf',
        ),
        KnownChatTemplates.vicuna,
      );
    });

    test('classifyTemplateByName_falconFilename_returnsFalcon3', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/falcon3-7b-instruct.gguf',
        ),
        KnownChatTemplates.falcon3,
      );
    });

    test('classifyTemplateByName_unknownModel_returnsNull', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/models/unknown-model.gguf',
        ),
        isNull,
      );
    });

    test('classifyTemplateByName_emptyPath_returnsNull', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(''),
        isNull,
      );
    });

    test('classifyTemplateByName_unslothGemmaVariant_returnsGemma', () {
      expect(
        RealLlamaEngineProvider.classifyTemplateByName(
          '/data/models/gemma-4-E2B-it-Q8_0.gguf',
        ),
        KnownChatTemplates.gemma,
      );
    });
  });

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
