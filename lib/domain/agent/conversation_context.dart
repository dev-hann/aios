class ConversationTurn {
  const ConversationTurn({
    required this.userMessage,
    required this.assistantResponse,
    required this.toolUsed,
  });

  final String userMessage;
  final String assistantResponse;
  final String? toolUsed;
}

class ConversationContext {
  ConversationContext({
    int maxTurns = 5,
    int maxResponseLength = 200,
  })  : _maxTurns = maxTurns,
        _maxResponseLength = maxResponseLength;

  final int _maxTurns;
  final int _maxResponseLength;
  final List<ConversationTurn> _turns = [];

  int get length => _turns.length;

  bool get isEmpty => _turns.isEmpty;

  void addTurn(
    String userMessage,
    String assistantResponse, {
    String? toolUsed,
  }) {
    _turns.add(ConversationTurn(
      userMessage: userMessage,
      assistantResponse: assistantResponse,
      toolUsed: toolUsed,
    ));
    while (_turns.length > _maxTurns) {
      _turns.removeAt(0);
    }
  }

  List<ConversationTurn> getRecentTurns([int? count]) {
    if (count == null || count >= _turns.length) {
      return List.unmodifiable(_turns);
    }
    return List.unmodifiable(
      _turns.sublist(_turns.length - count),
    );
  }

  String toPromptContext() {
    if (_turns.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('CONVERSATION HISTORY:');
    for (final turn in _turns) {
      buffer.writeln('User: ${turn.userMessage}');
      final response = turn.assistantResponse.length > _maxResponseLength
          ? '${turn.assistantResponse.substring(0, _maxResponseLength)}...'
          : turn.assistantResponse;
      buffer.writeln('Assistant: $response');
    }
    return buffer.toString();
  }

  void clear() {
    _turns.clear();
  }
}
