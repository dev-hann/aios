class PromptBuilder {
  PromptBuilder();

  final List<({String role, String content})> _history = [];

  String buildRoutingPrompt(String routingManifest) {
    return 'You are AIOS, an AI assistant on an Android phone.\n\n'
        'AVAILABLE TOOLS:\n$routingManifest\n\n'
        'You MUST respond in EXACTLY one of these two formats:\n\n'
        'Format 1 (to use a tool):\n'
        'Action: tool_name\n\n'
        'Format 2 (to answer directly):\n'
        'Answer: your text response\n\n'
        'Examples:\n'
        'User: open youtube\n'
        'Action: app_launcher\n\n'
        'User: open firefox\n'
        'Action: app_launcher\n\n'
        'User: open https://google.com\n'
        'Action: app_launcher\n\n'
        'User: 화면에서 확인 버튼 눌러줘\n'
        'Action: screen_action\n\n'
        'User: 뒤로 가줘\n'
        'Action: screen_action\n\n'
        'User: 위로 스크롤해줘\n'
        'Action: screen_action\n\n'
        'User: what is 2+2\n'
        'Answer: 4\n\n'
        'Rules: Max 5 tool calls. Be concise. Match user language. '
        'NEVER respond with anything except Action: or Answer: format.';
  }

  String buildToolPrompt(
    String toolName,
    String toolPrompt, {
    String? extraContext,
  }) {
    final base = 'You are AIOS. Execute the $toolName tool.\n\n'
        '$toolPrompt\n\n'
        'You MUST respond in EXACTLY this format:\n'
        'Action: $toolName\n'
        'Args: {"param": "value"}\n\n'
        'Example:\n'
        'Action: $toolName\n'
        'Args: {"action": "open_app", "package_name": "com.example.app"}';

    if (extraContext != null) {
      return '$base\n\nInstalled apps (use open_app with package_name '
          'from this list):\n$extraContext';
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
