class ResponseParser {
  ResponseParser(this.validToolNames);

  final Set<String> validToolNames;

  static final _actionRegex = RegExp(
    r'Action\s*:\s*(\w+)',
    multiLine: true,
    caseSensitive: false,
  );
  static final _argsRegex = RegExp(
    r'Args\s*:\s*(.+)',
    multiLine: true,
    caseSensitive: false,
  );
  static final _answerRegex = RegExp(
    r'Answer\s*:\s*(.+)',
    multiLine: true,
    caseSensitive: false,
    dotAll: true,
  );

  ParseResult parseIntent(String response) {
    final lower = response.trim().toLowerCase();
    if (lower.contains('conversation')) {
      return const ParseIntent(true);
    }
    if (lower.contains('task')) {
      return const ParseIntent(false);
    }
    return const ParseIntent(false);
  }

  ParseResult parse(String response) {
    final trimmed = response.trim();
    if (trimmed.isEmpty) return const ParseEmpty();

    try {
      final actionMatch = _actionRegex.firstMatch(trimmed);
      if (actionMatch != null) {
        final toolName = actionMatch.group(1)!.toLowerCase();
        if (validToolNames.contains(toolName)) {
          final afterAction = trimmed.substring(actionMatch.end);
          final argsStart = afterAction.indexOf('{');
          final args = argsStart >= 0
              ? _extractJsonArgs(afterAction, argsStart)
              : _argsRegex
                      .firstMatch(trimmed)
                      ?.group(1)
                      ?.trim() ??
                  '{}';
          return ParseAction(toolName, args);
        }
      }

      final answerMatch = _answerRegex.firstMatch(trimmed);
      if (answerMatch != null) {
        return ParseAnswer(answerMatch.group(1)!.trim());
      }
    } on Object catch (e) {
      print('[AIOS-Parser] ERROR: parseResponse error: $e');
    }

    return const ParseEmpty();
  }

  String _extractJsonArgs(String text, int startIndex) {
    var depth = 0;
    var inString = false;
    var escape = false;

    for (var i = startIndex; i < text.length; i++) {
      final c = text[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (c == '\\') {
        escape = true;
        continue;
      }
      if (c == '"') {
        inString = !inString;
        continue;
      }
      if (!inString) {
        if (c == '{') depth++;
        if (c == '}') {
          depth--;
          if (depth == 0) return text.substring(startIndex, i + 1);
        }
      }
    }
    return text.substring(startIndex);
  }
}

sealed class ParseResult {
  const ParseResult();
}

class ParseAction extends ParseResult {
  final String toolName;
  final String args;
  const ParseAction(this.toolName, this.args);
}

class ParseAnswer extends ParseResult {
  final String text;
  const ParseAnswer(this.text);
}

class ParseEmpty extends ParseResult {
  const ParseEmpty();
}

class ParseIntent extends ParseResult {
  final bool isConversation;
  const ParseIntent(this.isConversation);
}
