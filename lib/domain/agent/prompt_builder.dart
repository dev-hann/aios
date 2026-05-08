class PromptBuilder {
  PromptBuilder();

  final List<({String role, String content})> _history = [];

  String buildIntentPrompt(String routingManifest) {
    return 'Classify: does the user request match any tool?\n\n'
        'Tools:\n$routingManifest\n\n'
        'TASK = request matches a tool above\n'
        'CONVERSATION = greetings, chat, general knowledge\n'
        'When in doubt, reply TASK.\n'
        'Reply ONLY "TASK" or "CONVERSATION".';
  }

  String buildAnswerPrompt() {
    return 'You are AIOS, an on-device phone assistant.\n'
        'Respond concisely in the user\'s language (1-2 sentences).\n'
        'Be friendly and helpful.';
  }

  String buildRoutingPrompt(
    String routingManifest, {
    String? conversationContext,
    String? toolPreferences,
  }) {
    final contextSection = conversationContext != null &&
            conversationContext.isNotEmpty
        ? '\n$conversationContext\n'
        : '';
    final prefSection = toolPreferences != null && toolPreferences.isNotEmpty
        ? '\n$toolPreferences\n'
        : '';
    return 'You are AIOS, a phone assistant. '
        'Select a tool or answer directly.\n\n'
        'Tools:\n$routingManifest\n'
        '$contextSection'
        '$prefSection'
        'IMPORTANT: For greetings, chat, general questions '
        '-> Answer directly.\n'
        'For device actions -> use Action format.\n\n'
        'Examples:\n'
        'User: open youtube\n'
        'Action: app_launcher\n\n'
        'User: 안녕하세요\n'
        'Answer: 안녕하세요! 무엇을 도와드릴까요?\n\n'
        'User: 배터리 몇퍼센트야\n'
        'Action: device_info\n\n'
        'User: 고마워\n'
        'Answer: 천만에요! 더 필요한 거 있으면 말씀해주세요.\n\n'
        'User: 화면에서 확인 눌러줘\n'
        'Action: screen_action\n\n'
        'User: 누구세요?\n'
        'Answer: 저는 AIOS, 휴대폰 AI 비서입니다.\n\n'
        'Respond ONLY "Action: tool_name" or "Answer: text".';
  }

  String buildToolPrompt(
    String toolName,
    String toolPrompt, {
    String? extraContext,
  }) {
    final base = 'Execute the $toolName tool.\n\n'
        '$toolPrompt\n\n'
        'Respond EXACTLY:\n'
        'Action: $toolName\n'
        'Args: {"param": "value"}';

    if (extraContext != null) {
      return '$base\n\nInstalled apps '
          '(use open_app with package_name from this list):\n'
          '$extraContext';
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
