import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LlmProviderConfig', () {
    group('effectiveBaseUrl', () {
      test('effectiveBaseUrl_zai_returnsZaiUrl', () {
        const config = LlmProviderConfig(
          type: LlmProviderType.zai,
          apiKey: 'key',
          model: 'model',
        );
        expect(config.effectiveBaseUrl, 'https://api.z.ai/api/paas/v4');
      });

      test('effectiveBaseUrl_zaiCoding_returnsZaiCodingUrl', () {
        const config = LlmProviderConfig(
          type: LlmProviderType.zaiCoding,
          apiKey: 'key',
          model: 'model',
        );
        expect(config.effectiveBaseUrl, 'https://api.z.ai/api/coding/paas/v4');
      });

      test('effectiveBaseUrl_openai_returnsOpenaiUrl', () {
        const config = LlmProviderConfig(
          type: LlmProviderType.openai,
          apiKey: 'key',
          model: 'model',
        );
        expect(config.effectiveBaseUrl, 'https://api.openai.com/v1');
      });

      test('effectiveBaseUrl_anthropic_returnsAnthropicUrl', () {
        const config = LlmProviderConfig(
          type: LlmProviderType.anthropic,
          apiKey: 'key',
          model: 'model',
        );
        expect(config.effectiveBaseUrl, 'https://api.anthropic.com/v1');
      });

      test('effectiveBaseUrl_custom_returnsBaseUrl', () {
        const config = LlmProviderConfig(
          type: LlmProviderType.custom,
          apiKey: 'key',
          model: 'model',
          baseUrl: 'https://custom.api.com/v1',
        );
        expect(config.effectiveBaseUrl, 'https://custom.api.com/v1');
      });

      test('effectiveBaseUrl_customNoBaseUrl_returnsEmpty', () {
        const config = LlmProviderConfig(
          type: LlmProviderType.custom,
          apiKey: 'key',
          model: 'model',
        );
        expect(config.effectiveBaseUrl, '');
      });
    });

    group('endpoints', () {
      test('chatEndpoint_appendsChatCompletions', () {
        const config = LlmProviderConfig(
          type: LlmProviderType.openai,
          apiKey: 'key',
          model: 'model',
        );
        expect(
          config.chatEndpoint,
          'https://api.openai.com/v1/chat/completions',
        );
      });

      test('modelsEndpoint_appendsModels', () {
        const config = LlmProviderConfig(
          type: LlmProviderType.openai,
          apiKey: 'key',
          model: 'model',
        );
        expect(config.modelsEndpoint, 'https://api.openai.com/v1/models');
      });
    });

    group('headers', () {
      test('headers_containsAuthAndContentType', () {
        const config = LlmProviderConfig(
          type: LlmProviderType.openai,
          apiKey: 'sk-test123',
          model: 'gpt-4',
        );
        expect(config.headers['Content-Type'], 'application/json');
        expect(config.headers['Authorization'], 'Bearer sk-test123');
      });
    });

    group('serialization', () {
      test('toJson_fromJson_roundTrip', () {
        const config = LlmProviderConfig(
          type: LlmProviderType.zaiCoding,
          apiKey: 'test-key',
          model: 'glm-4.5-air',
        );
        final json = config.toJson();
        final restored = LlmProviderConfig.fromJson(json);

        expect(restored.type, LlmProviderType.zaiCoding);
        expect(restored.apiKey, 'test-key');
        expect(restored.model, 'glm-4.5-air');
        expect(restored.baseUrl, isNull);
      });

      test('fromJson_withBaseUrl_restoresBaseUrl', () {
        const config = LlmProviderConfig(
          type: LlmProviderType.custom,
          apiKey: 'key',
          model: 'model',
          baseUrl: 'https://custom.api.com',
        );
        final json = config.toJson();
        final restored = LlmProviderConfig.fromJson(json);

        expect(restored.baseUrl, 'https://custom.api.com');
      });

      test('fromJson_missingFields_defaultsGracefully', () {
        final restored = LlmProviderConfig.fromJson('{"type":"openai"}');
        expect(restored.type, LlmProviderType.openai);
        expect(restored.apiKey, '');
        expect(restored.model, '');
        expect(restored.baseUrl, isNull);
      });

      test('fromJson_unknownType_defaultsToZai', () {
        final restored = LlmProviderConfig.fromJson('{"type":"nonexistent"}');
        expect(restored.type, LlmProviderType.zai);
      });
    });

    group('copyWith', () {
      test('copyWith_allFields_updatesAll', () {
        const config = LlmProviderConfig(
          type: LlmProviderType.openai,
          apiKey: 'old-key',
          model: 'old-model',
        );
        final updated = config.copyWith(
          type: LlmProviderType.zai,
          apiKey: 'new-key',
          model: 'new-model',
          baseUrl: 'https://new.url',
        );
        expect(updated.type, LlmProviderType.zai);
        expect(updated.apiKey, 'new-key');
        expect(updated.model, 'new-model');
        expect(updated.baseUrl, 'https://new.url');
      });

      test('copyWith_noArgs_keepsOriginal', () {
        const config = LlmProviderConfig(
          type: LlmProviderType.openai,
          apiKey: 'key',
          model: 'model',
          baseUrl: 'https://url',
        );
        final copy = config.copyWith();
        expect(copy.type, config.type);
        expect(copy.apiKey, config.apiKey);
        expect(copy.model, config.model);
        expect(copy.baseUrl, config.baseUrl);
      });
    });
  });

  group('LlmModelInfo', () {
    group('fromApi', () {
      test('fromApi_simpleId_returnsModelInfo', () {
        final info = LlmModelInfo.fromApi('glm-4.5-air');
        expect(info.id, 'glm-4.5-air');
        expect(info.displayName, isNotEmpty);
        expect(info.capabilities, contains(ModelCapability.toolCalling));
      });

      test('fromApi_visionModel_hasVisionCapability', () {
        final info = LlmModelInfo.fromApi('gpt-4-vision');
        expect(info.capabilities, contains(ModelCapability.vision));
      });

      test('fromApi_thinkingModel_hasThinkingCapability', () {
        final info = LlmModelInfo.fromApi('gpt-5');
        expect(info.capabilities, contains(ModelCapability.thinking));
      });

      test('fromApi_plainModel_hasOnlyToolCalling', () {
        final info = LlmModelInfo.fromApi('glm-4-air');
        expect(info.capabilities.length, 1);
        expect(info.capabilities.first, ModelCapability.toolCalling);
      });
    });
  });
}
