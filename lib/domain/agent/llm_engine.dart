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
  final double temperature;
  final double topP;
  final int maxTokens;

  const LlmGenerationConfig({
    required this.temperature,
    required this.topP,
    required this.maxTokens,
  });
}

class LlmResponseChunk {
  final String? text;
  final String? thinking;
  final List<LlmToolCallDelta>? toolCallDeltas;

  const LlmResponseChunk({this.text, this.thinking, this.toolCallDeltas});
}

class LlmToolCallDelta {
  final int index;
  final String? id;
  final String? name;
  final String? arguments;

  const LlmToolCallDelta({
    required this.index,
    this.id,
    this.name,
    this.arguments,
  });
}

class LlmContentPart {
  final String text;
  const LlmContentPart.text(this.text);
}

class LlmToolSchema {
  final String name;
  final String description;
  final List<LlmToolParamSchema> parameters;

  const LlmToolSchema({
    required this.name,
    required this.description,
    required this.parameters,
  });
}

class LlmToolParamSchema {
  final String name;
  final String description;
  final String type;
  final bool required;
  final bool isEnum;
  final List<String>? enumValues;
  final String? example;

  const LlmToolParamSchema({
    required this.name,
    required this.description,
    this.type = 'string',
    required this.required,
    this.isEnum = false,
    this.enumValues,
    this.example,
  });
}
