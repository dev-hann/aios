import 'package:aios/data/providers/remote/openai_client.dart';
import 'package:aios/domain/agent/llm_engine.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OpenAiClient client;

  setUp(() {
    const config = LlmProviderConfig(
      type: LlmProviderType.zai,
      apiKey: 'test-key',
      model: 'test-model',
      baseUrl: 'https://api.test.com',
    );
    client = OpenAiClient(config);
  });

  group('convertTools', () {
    test('convertTools_emptyList_returnsEmptyList', () {
      final result = client.convertTools([]);
      expect(result, isEmpty);
    });

    test('convertTools_singleTool_returnsValidSchema', () {
      final tools = [
        const LlmToolSchema(
          name: 'calculator',
          description: 'Evaluate math',
          parameters: [
            LlmToolParamSchema(
              name: 'expression',
              description: 'math expression',
              required: true,
            ),
          ],
        ),
      ];

      final result = client.convertTools(tools);

      expect(result.length, 1);
      final fn = result[0]['function'] as Map<String, dynamic>;
      expect(fn['name'], 'calculator');
      expect(fn['description'], 'Evaluate math');
      final params = fn['parameters'] as Map<String, dynamic>;
      expect(params['type'], 'object');
      final props = params['properties'] as Map<String, dynamic>;
      expect(props.containsKey('expression'), isTrue);
      final expr = props['expression'] as Map<String, dynamic>;
      expect(expr['type'], 'string');
      expect(expr['description'], 'math expression');
      expect(params['required'], ['expression']);
    });

    test('convertTools_enumParam_includesEnumValues', () {
      final tools = [
        const LlmToolSchema(
          name: 'screen_action',
          description: 'Screen actions',
          parameters: [
            LlmToolParamSchema(
              name: 'action',
              description: 'tap|type|scroll',
              required: true,
              isEnum: true,
              enumValues: ['tap', 'type', 'scroll'],
            ),
          ],
        ),
      ];

      final result = client.convertTools(tools);
      final fn = result[0]['function'] as Map<String, dynamic>;
      final props =
          (fn['parameters'] as Map<String, dynamic>)['properties']
              as Map<String, dynamic>;
      final action = props['action'] as Map<String, dynamic>;
      expect(action['enum'], ['tap', 'type', 'scroll']);
    });

    test('convertTools_optionalParam_notInRequired', () {
      final tools = [
        const LlmToolSchema(
          name: 'test',
          description: 'test tool',
          parameters: [
            LlmToolParamSchema(
              name: 'required_param',
              description: 'required',
              required: true,
            ),
            LlmToolParamSchema(
              name: 'optional_param',
              description: 'optional field',
              required: false,
            ),
          ],
        ),
      ];

      final result = client.convertTools(tools);
      final fn = result[0]['function'] as Map<String, dynamic>;
      final params = fn['parameters'] as Map<String, dynamic>;
      expect(params['required'], ['required_param']);
    });

    test('convertTools_noRequiredParams_omitsRequired', () {
      final tools = [
        const LlmToolSchema(
          name: 'screen_reader',
          description: 'Read screen',
          parameters: [],
        ),
      ];

      final result = client.convertTools(tools);
      final fn = result[0]['function'] as Map<String, dynamic>;
      final params = fn['parameters'] as Map<String, dynamic>;
      expect(params.containsKey('required'), isFalse);
    });

    test('convertTools_exampleParam_includesExample', () {
      final tools = [
        const LlmToolSchema(
          name: 'tool',
          description: 'test tool',
          parameters: [
            LlmToolParamSchema(
              name: 'count',
              description: 'number of items (e.g. 5)',
              type: 'integer',
              required: true,
              example: '5',
            ),
          ],
        ),
      ];

      final result = client.convertTools(tools);
      final fn = result[0]['function'] as Map<String, dynamic>;
      final props =
          (fn['parameters'] as Map<String, dynamic>)['properties']
              as Map<String, dynamic>;
      final count = props['count'] as Map<String, dynamic>;
      expect(count['example'], '5');
    });

    test('convertTools_multipleTools_returnsAll', () {
      final tools = [
        const LlmToolSchema(
          name: 'tool_a',
          description: 'Tool A',
          parameters: [],
        ),
        const LlmToolSchema(
          name: 'tool_b',
          description: 'Tool B',
          parameters: [],
        ),
      ];

      final result = client.convertTools(tools);

      expect(result.length, 2);
      final names = result
          .map((t) => (t['function'] as Map<String, dynamic>)['name'])
          .toList();
      expect(names, ['tool_a', 'tool_b']);
    });

    test('convertTools_functionType_isFunction', () {
      final tools = [
        const LlmToolSchema(name: 'test', description: 'test', parameters: []),
      ];

      final result = client.convertTools(tools);
      expect(result[0]['type'], 'function');
    });
  });
}
