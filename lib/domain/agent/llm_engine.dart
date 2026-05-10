abstract class LlmEngine {
  LlmChatSession createSession(String systemPrompt);
  void cancelGeneration();
  Future<void> warmup();
}

abstract class LlmChatSession {
  Stream<LlmResponseChunk> chat(
    List<LlmContentPart> messages, {
    required LlmGenerationConfig config,
    required List<LlmToolSchema> tools,
  });

  void addToolResult(String toolName, String result);
}

class LlmGenerationConfig {
  const LlmGenerationConfig({
    required this.temperature,
    required this.topP,
    required this.maxTokens,
  });
  final double temperature;
  final double topP;
  final int maxTokens;
}

class LlmResponseChunk {
  const LlmResponseChunk({this.text, this.thinking, this.toolCallDeltas});
  final String? text;
  final String? thinking;
  final List<LlmToolCallDelta>? toolCallDeltas;
}

class LlmToolCallDelta {
  const LlmToolCallDelta({
    required this.index,
    this.id,
    this.name,
    this.arguments,
  });
  final int index;
  final String? id;
  final String? name;
  final String? arguments;
}

class LlmContentPart {
  const LlmContentPart.text(this.text);
  final String text;
}

class LlmToolSchema {
  const LlmToolSchema({
    required this.name,
    required this.description,
    required this.parameters,
  });
  final String name;
  final String description;
  final List<LlmToolParamSchema> parameters;
}

class LlmToolParamSchema {
  const LlmToolParamSchema({
    required this.name,
    required this.description,
    required this.required,
    this.type = 'string',
    this.isEnum = false,
    this.enumValues,
    this.example,
  });
  final String name;
  final String description;
  final String type;
  final bool required;
  final bool isEnum;
  final List<String>? enumValues;
  final String? example;
}

class ToolCallAccumulator {
  String? id;
  String? name;
  String arguments = '';

  void applyDelta(LlmToolCallDelta delta) {
    if (delta.id != null) id = delta.id;
    if (delta.name != null) name = delta.name;
    if (delta.arguments != null) arguments += delta.arguments!;
  }
}
