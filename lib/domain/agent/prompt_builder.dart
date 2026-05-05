class PromptBuilder {
  PromptBuilder();

  final List<({String role, String content})> _history = [];

  String buildSystemPrompt(String toolManifest) {
    return 'You are AIOS, an AI assistant on an Android phone. '
        'You can use tools or answer directly.\n\n'
        'TOOLS:\n$toolManifest\n\n'
        'FORMAT:\n'
        '- Tool: Action: tool_name\nArgs: {"param": "value"}\n'
        '- Answer: Answer: your response\n\n'
        'RULES:\n'
        '1. Max 3 tool calls per request, then Answer.\n'
        '2. Use tools only for device actions/info. '
        'Answer directly from knowledge otherwise.\n'
        '3. Be concise. Match user\'s language.';
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
