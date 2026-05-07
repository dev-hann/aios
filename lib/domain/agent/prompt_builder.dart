class PromptBuilder {
  PromptBuilder();

  final List<({String role, String content})> _history = [];

  String buildSystemPrompt(String toolManifest) {
    return 'You are AIOS, an AI assistant on an Android phone.\n\n'
        'TOOLS:\n$toolManifest\n\n'
        'FORMAT:\n'
        'Action: tool_name\n'
        'Args: {"param": "value"}\n'
        'or:\n'
        'Answer: your response\n\n'
        'MANDATORY RULES (you MUST follow these exactly):\n'
        '1. You MUST call list_apps before open_app.\n'
        '2. NEVER guess or invent a package_name.\n'
        '3. Copy the EXACT package_name from list_apps result '
        '(text inside parentheses). Do not modify it.\n'
        '4. Example:\n'
        'Action: app_launcher\n'
        'Args: {"action": "list_apps", "query": "youtube"}\n'
        '-> Observation: 1. YouTube (app.revanced.android.youtube)\n'
        'Action: app_launcher\n'
        'Args: {"action": "open_app", '
        '"package_name": "app.revanced.android.youtube"}\n'
        '5. If open_app returns an error, call list_apps again '
        'with a query to find the correct package_name.\n'
        '6. Max 5 tool calls, then Answer.\n'
        '7. Be concise. Match user language.';
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
