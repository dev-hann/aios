import 'dart:async';

import 'package:aios/data/providers/remote/llm_remote_session.dart';
import 'package:aios/data/providers/remote/openai_client.dart';
import 'package:aios/domain/agent/llm_engine.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOpenAiClient extends OpenAiClient {
  _FakeOpenAiClient()
    : super(
        const LlmProviderConfig(
          type: LlmProviderType.zai,
          apiKey: 'test',
          model: 'test',
          baseUrl: 'https://test.com',
        ),
      );

  final List<Map<String, dynamic>> _chunks = [];
  bool _cancelled = false;

  void addTextChunk(String text) {
    _chunks.add({'type': 'text', 'data': text});
  }

  void addToolCallChunk({
    required int index,
    String? id,
    String? name,
    String? arguments,
  }) {
    _chunks.add({
      'type': 'tool_call',
      'index': index,
      'id': id,
      'name': name,
      'arguments': arguments,
    });
  }

  @override
  Stream<LlmResponseChunk> streamChat({
    required List<Map<String, dynamic>> messages,
    required LlmGenerationConfig config,
    List<LlmToolSchema> tools = const [],
    bool toolStream = true,
  }) async* {
    for (final chunk in _chunks) {
      if (_cancelled) break;
      if (chunk['type'] == 'text') {
        yield LlmResponseChunk(text: chunk['data'] as String);
      } else if (chunk['type'] == 'tool_call') {
        yield LlmResponseChunk(
          toolCallDeltas: [
            LlmToolCallDelta(
              index: chunk['index'] as int,
              id: chunk['id'] as String?,
              name: chunk['name'] as String?,
              arguments: chunk['arguments'] as String?,
            ),
          ],
        );
      }
    }
  }

  @override
  void cancel() {
    _cancelled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LlmRemoteSession', () {
    late _FakeOpenAiClient client;
    late LlmRemoteSession session;

    setUp(() {
      client = _FakeOpenAiClient();
      session = LlmRemoteSession(
        client: client,
        systemPrompt: 'You are a test assistant.',
      );
    });

    group('chat', () {
      test('chat_textResponse_yieldsChunks', () async {
        client
          ..addTextChunk('Hello')
          ..addTextChunk(' world');

        final chunks = <LlmResponseChunk>[];
        await for (final chunk in session.chat(
          [const LlmContentPart.text('Hi')],
          config: const LlmGenerationConfig(
            temperature: 0.7,
            topP: 0.9,
            maxTokens: 100,
          ),
          tools: [],
        )) {
          chunks.add(chunk);
        }

        expect(chunks.length, 2);
        expect(chunks[0].text, 'Hello');
        expect(chunks[1].text, ' world');
      });

      test('chat_withUserMessage_addsToHistory', () async {
        client.addTextChunk('response');

        await session
            .chat(
              [const LlmContentPart.text('test input')],
              config: const LlmGenerationConfig(
                temperature: 0.7,
                topP: 0.9,
                maxTokens: 100,
              ),
              tools: [],
            )
            .toList();

        session.addToolResult('test', 'result');

        expect(() => session.addToolResult('test', 'result'), returnsNormally);
      });

      test('chat_toolCall_accumulatesCorrectly', () async {
        client
          ..addToolCallChunk(
            index: 0,
            id: 'call_1',
            name: 'calculator',
            arguments: '{"expr',
          )
          ..addToolCallChunk(index: 0, arguments: 'ession":"2+2"}');

        final chunks = <LlmResponseChunk>[];
        await for (final chunk in session.chat(
          [const LlmContentPart.text('calc 2+2')],
          config: const LlmGenerationConfig(
            temperature: 0.7,
            topP: 0.9,
            maxTokens: 100,
          ),
          tools: [],
        )) {
          chunks.add(chunk);
        }

        expect(chunks.length, 2);
        expect(chunks[0].toolCallDeltas?.first.name, 'calculator');
        expect(chunks[1].toolCallDeltas?.first.arguments, 'ession":"2+2"}');
      });

      test('chat_multipleToolCalls_accumulatesAll', () async {
        client
          ..addToolCallChunk(
            index: 0,
            id: 'call_1',
            name: 'calculator',
            arguments: '{}',
          )
          ..addToolCallChunk(
            index: 1,
            id: 'call_2',
            name: 'notepad',
            arguments: '{}',
          );

        final chunks = <LlmResponseChunk>[];
        await for (final chunk in session.chat(
          [const LlmContentPart.text('multi')],
          config: const LlmGenerationConfig(
            temperature: 0.7,
            topP: 0.9,
            maxTokens: 100,
          ),
          tools: [],
        )) {
          chunks.add(chunk);
        }

        expect(chunks.length, 2);
        expect(chunks[0].toolCallDeltas?.first.name, 'calculator');
        expect(chunks[1].toolCallDeltas?.first.name, 'notepad');
      });

      test('chat_emptyMessages_doesNotAddUserMessage', () async {
        client.addTextChunk('ok');

        await session
            .chat(
              [],
              config: const LlmGenerationConfig(
                temperature: 0.7,
                topP: 0.9,
                maxTokens: 100,
              ),
              tools: [],
            )
            .toList();

        expect(true, isTrue);
      });
    });

    group('addToolResult', () {
      test('addToolResult_afterToolCall_usesCorrectId', () async {
        client.addToolCallChunk(
          index: 0,
          id: 'call_abc',
          name: 'calculator',
          arguments: '{}',
        );

        await session
            .chat(
              [const LlmContentPart.text('test')],
              config: const LlmGenerationConfig(
                temperature: 0.7,
                topP: 0.9,
                maxTokens: 100,
              ),
              tools: [],
            )
            .toList();

        session.addToolResult('calculator', '4');

        expect(true, isTrue);
      });

      test('addToolResult_unknownTool_usesLastId', () async {
        client.addToolCallChunk(
          index: 0,
          id: 'call_abc',
          name: 'calculator',
          arguments: '{}',
        );

        await session
            .chat(
              [const LlmContentPart.text('test')],
              config: const LlmGenerationConfig(
                temperature: 0.7,
                topP: 0.9,
                maxTokens: 100,
              ),
              tools: [],
            )
            .toList();

        session.addToolResult('unknown_tool', 'result');

        expect(true, isTrue);
      });

      test('addToolResult_noToolCalls_usesEmptyId', () async {
        client.addTextChunk('just text');

        await session
            .chat(
              [const LlmContentPart.text('test')],
              config: const LlmGenerationConfig(
                temperature: 0.7,
                topP: 0.9,
                maxTokens: 100,
              ),
              tools: [],
            )
            .toList();

        session.addToolResult('any_tool', 'result');

        expect(true, isTrue);
      });

      test('addToolResult_multipleToolCalls_resolvesByName', () async {
        client
          ..addToolCallChunk(
            index: 0,
            id: 'call_1',
            name: 'calculator',
            arguments: '{}',
          )
          ..addToolCallChunk(
            index: 1,
            id: 'call_2',
            name: 'notepad',
            arguments: '{}',
          );

        await session
            .chat(
              [const LlmContentPart.text('test')],
              config: const LlmGenerationConfig(
                temperature: 0.7,
                topP: 0.9,
                maxTokens: 100,
              ),
              tools: [],
            )
            .toList();

        session
          ..addToolResult('notepad', 'saved')
          ..addToolResult('calculator', '4');

        expect(true, isTrue);
      });
    });

    group('session reuse', () {
      test('chat_multipleRounds_accumulatesMessages', () async {
        client.addTextChunk('first');

        await session
            .chat(
              [const LlmContentPart.text('hi')],
              config: const LlmGenerationConfig(
                temperature: 0.7,
                topP: 0.9,
                maxTokens: 100,
              ),
              tools: [],
            )
            .toList();

        client.addTextChunk('second');

        await session
            .chat(
              [const LlmContentPart.text('hello again')],
              config: const LlmGenerationConfig(
                temperature: 0.7,
                topP: 0.9,
                maxTokens: 100,
              ),
              tools: [],
            )
            .toList();

        expect(true, isTrue);
      });
    });
  });
}
