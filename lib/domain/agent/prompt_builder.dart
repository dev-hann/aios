class PromptBuilder {
  PromptBuilder();

  final List<({String role, String content})> _history = [];

  String buildRoutingPrompt(String routingManifest) {
    return 'You are AIOS, an AI assistant on an Android phone.\n\n'
        'TOOLS:\n$routingManifest\n\n'
        'Respond with:\n'
        'Action: tool_name\n'
        'or:\n'
        'Answer: your response\n\n'
        'Rules: Max 5 tool calls. Be concise. Match user language.';
  }

  String buildToolPrompt(
    String toolName,
    String toolPrompt, {
    String? extraContext,
  }) {
    final base = 'You are AIOS. Execute the $toolName tool.\n\n'
        '$toolPrompt\n\n'
        'Respond with:\n'
        'Action: $toolName\n'
        'Args: {"param": "value"}';

    if (extraContext != null) {
      return '$base\n\nInstalled apps:\n$extraContext';
    }
    return base;
  }

  void addUserMessage(String content) {
    _history.add((role: 'user', content: content));
  }

  void addAssistantMessage(String content) {
    _history.add((role: 'assistant', content: content));
  }

  void addObservation(String content) {
    _history.add((role: 'user', content: content));
  }

  List<({String role, String content})> getHistory() =>
      List.unmodifiable(_history);

  void clearHistory() {
    _history.clear();
  }

  String getConversationContext() {
    final buffer = StringBuffer();
    for (final msg in _history) {
      buffer.writeln('${msg.role}: ${msg.content}');
    }
    return buffer.toString();
  }
}
