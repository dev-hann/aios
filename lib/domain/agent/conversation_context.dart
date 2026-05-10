import 'dart:collection';

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
  ConversationContext({int maxTurns = 5, int maxResponseLength = 200})
    : _maxTurns = maxTurns,
      _maxResponseLength = maxResponseLength;

  final int _maxTurns;
  final int _maxResponseLength;
  final Queue<ConversationTurn> _turns = Queue();

  int get length => _turns.length;

  bool get isEmpty => _turns.isEmpty;

  void addTurn(
    String userMessage,
    String assistantResponse, {
    String? toolUsed,
  }) {
    _turns.addLast(
      ConversationTurn(
        userMessage: userMessage,
        assistantResponse: assistantResponse,
        toolUsed: toolUsed,
      ),
    );
    while (_turns.length > _maxTurns) {
      _turns.removeFirst();
    }
  }

  List<ConversationTurn> getRecentTurns([int? count]) {
    final list = _turns.toList();
    if (count == null || count >= list.length) {
      return List.unmodifiable(list);
    }
    return List.unmodifiable(list.sublist(list.length - count));
  }

  String toPromptContext() {
    if (_turns.isEmpty) return '';
    final buffer = StringBuffer()..writeln('CONVERSATION HISTORY:');
    for (final turn in _turns) {
      final response = turn.assistantResponse.length > _maxResponseLength
          ? '${turn.assistantResponse.substring(0, _maxResponseLength)}...'
          : turn.assistantResponse;
      buffer
        ..writeln('User: ${turn.userMessage}')
        ..writeln('Assistant: $response');
    }
    return buffer.toString();
  }

  void clear() {
    _turns.clear();
  }
}
