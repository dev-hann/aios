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
        'User: 지금 화면에 뭐 보여\n'
        'Action: screen_reader\n\n'
        'User: 화면에서 설정 버튼 찾아줘\n'
        'Action: screen_find\n\n'
        'User: 알림 뭐왔어\n'
        'Action: notification_reader\n\n'
        'User: 카톡 알림 읽어줘\n'
        'Action: notification_reader\n\n'
        'User: 01012345678으로 안부 문자 보내줘\n'
        'Action: sms_sender\n\n'
        'User: 문자 뭐왔어\n'
        'Action: sms_sender\n\n'
        'User: 엄마한테 전화해줘\n'
        'Action: phone_caller\n\n'
        'User: 01012345678로 전화 걸어줘\n'
        'Action: phone_caller\n\n'
        'User: 홍길동 전화번호 알려줘\n'
        'Action: contact_search\n\n'
        'User: 김씨 연락처 찾아줘\n'
        'Action: contact_search\n\n'
        'User: what is 2+2\n'
        'Action: calculator\n\n'
        'User: 385 곱하기 22 얼마야\n'
        'Action: calculator\n\n'
        'User: 1000 나누기 3은\n'
        'Action: calculator\n\n'
        'User: calculate (15+7)*3\n'
        'Action: calculator\n\n'
        'User: 오늘 할 일 적어줘: 장보기, 운동가기\n'
        'Action: notepad\n\n'
        'User: 메모 뭐 있어\n'
        'Action: notepad\n\n'
        'User: 장보기 메모 지워줘\n'
        'Action: notepad\n\n'
        'User: save a note: buy milk tomorrow\n'
        'Action: notepad\n\n'
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
