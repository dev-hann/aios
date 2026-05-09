import 'package:aios/domain/agent/llm_engine.dart';
import 'package:llamadart/llamadart.dart';

class LlmEngineImpl implements LlmEngine {
  LlmEngineImpl(this._engine);

  final LlamaEngine _engine;

  @override
  LlmChatSession createSession(String systemPrompt) {
    return LlmChatSessionImpl(
      ChatSession(_engine, systemPrompt: systemPrompt),
    );
  }

  @override
  void cancelGeneration() => _engine.cancelGeneration();

  @override
  Future<void> warmup() async {
    try {
      final session = ChatSession(_engine, systemPrompt: '');
      final params = GenerationParams(
        temp: 0.1,
        topK: 1,
        topP: 1.0,
        penalty: 1.0,
        maxTokens: 1,
      );
      await for (final _ in session.create(
        [LlamaTextContent('hi')],
        params: params,
      )) {
        break;
      }
      print('[AIOS-LlmEngine] Warmup complete');
    } on Object catch (e) {
      print('[AIOS-LlmEngine] WARN: warmup failed - $e');
    }
  }
}

class LlmChatSessionImpl implements LlmChatSession {
  LlmChatSessionImpl(this._session);

  final ChatSession _session;

  @override
  Stream<LlmResponseChunk> chat(
    List<LlmContentPart> messages, {
    required LlmGenerationConfig config,
    required List<LlmToolSchema> tools,
  }) async* {
    final userParts = messages.map((m) => LlamaTextContent(m.text)).toList();

    final llamaTools = tools
        .map((t) => ToolDefinition(
              name: t.name,
              description: t.description,
              parameters: t.parameters.map((p) {
                if (p.isEnum && p.enumValues != null) {
                  return ToolParam.enumType(
                    p.name,
                    values: p.enumValues!,
                    description: p.description,
                    required: p.required,
                  );
                }
                return ToolParam.string(
                  p.name,
                  description: p.description,
                  required: p.required,
                );
              }).toList(),
              handler: (_) async => '',
            ))
        .toList();

    final params = GenerationParams(
      temp: config.temperature,
      topK: config.topK,
      topP: config.topP,
      penalty: config.penalty,
      maxTokens: config.maxTokens,
    );

    await for (final chunk
        in _session.create(userParts, params: params, tools: llamaTools)) {
      final delta = chunk.choices.first.delta;
      yield LlmResponseChunk(
        text: delta.content,
        thinking: delta.thinking,
        toolCallDeltas: delta.toolCalls
            ?.map((tc) => LlmToolCallDelta(
                  index: tc.index,
                  id: tc.id,
                  name: tc.function?.name,
                  arguments: tc.function?.arguments,
                ))
            .toList(),
      );
    }
  }

  @override
  void addToolResult(String toolName, String result) {
    _session.addMessage(
      LlamaChatMessage.withContent(
        role: LlamaChatRole.tool,
        content: [LlamaToolResultContent(name: toolName, result: result)],
      ),
    );
  }
}
