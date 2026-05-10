import 'package:aios/data/providers/remote/openai_client.dart';
import 'package:aios/domain/agent/llm_engine.dart';

class LlmRemoteSession implements LlmChatSession {
  LlmRemoteSession({required OpenAiClient client, required String systemPrompt})
    : _client = client,
      _systemPrompt = systemPrompt;

  final OpenAiClient _client;
  final String _systemPrompt;
  final List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>>? _lastToolCalls;

  static const _tag = 'AIOS-LlmRemoteSession';

  @override
  Stream<LlmResponseChunk> chat(
    List<LlmContentPart> messages, {
    required LlmGenerationConfig config,
    required List<LlmToolSchema> tools,
  }) async* {
    if (messages.isNotEmpty) {
      _messages.add({'role': 'user', 'content': messages.first.text});
    }

    final apiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt},
      ..._messages,
    ];

    String fullContent = '';
    String fullThinking = '';
    final Map<int, _AccEntry> toolCallAcc = {};

    await for (final chunk in _client.streamChat(
      messages: apiMessages,
      config: config,
      tools: tools,
    )) {
      if (chunk.text != null) fullContent += chunk.text!;
      if (chunk.thinking != null) fullThinking += chunk.thinking!;

      if (chunk.toolCallDeltas != null) {
        for (final tc in chunk.toolCallDeltas!) {
          final entry = toolCallAcc.putIfAbsent(tc.index, _AccEntry.new);
          if (tc.id != null) entry.id = tc.id;
          if (tc.name != null) entry.name = tc.name;
          if (tc.arguments != null) entry.arguments += tc.arguments!;
        }
      }

      yield chunk;
    }

    final assistantMsg = <String, dynamic>{
      'role': 'assistant',
      if (fullContent.isNotEmpty) 'content': fullContent,
    };

    if (toolCallAcc.isNotEmpty) {
      final toolCallsList = <Map<String, dynamic>>[];
      for (final entry in toolCallAcc.entries) {
        final tc = entry.value;
        toolCallsList.add({
          'id': tc.id ?? 'call_${entry.key}',
          'type': 'function',
          'function': {'name': tc.name ?? '', 'arguments': tc.arguments},
        });
      }
      assistantMsg['tool_calls'] = toolCallsList;
      _lastToolCalls = toolCallsList;
    } else {
      _lastToolCalls = null;
    }

    _messages.add(assistantMsg);

    print(
      '[$_tag] chat complete: '
      'content=${fullContent.length}chars, '
      'toolCalls=${toolCallAcc.length}',
    );
  }

  @override
  void addToolResult(String toolName, String result) {
    final toolCallId = _findToolCallId(toolName);
    _messages.add({
      'role': 'tool',
      'tool_call_id': toolCallId,
      'content': result,
    });
    print('[$_tag] Tool result added: $toolName (id=$toolCallId)');
  }

  String _findToolCallId(String toolName) {
    if (_lastToolCalls == null) return '';
    for (final tc in _lastToolCalls!) {
      final fn = tc['function'] as Map<String, dynamic>?;
      if (fn?['name'] == toolName) {
        return tc['id'] as String? ?? '';
      }
    }
    return _lastToolCalls!.isNotEmpty
        ? _lastToolCalls!.last['id'] as String? ?? ''
        : '';
  }
}

class _AccEntry {
  String? id;
  String? name;
  String arguments = '';
}
