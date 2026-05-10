Map<String, dynamic>? inferToolArgs(String toolName, String userMessage) {
  final msg = userMessage.toLowerCase();
  switch (toolName) {
    case 'calculator':
      final expr = extractMathExpr(msg);
      if (expr != null) return {'expression': expr};
      return null;
    case 'notepad':
      final writeMatch = RegExp(
        r'(?:write|save|note|store|record)\s+(.+)',
        caseSensitive: false,
      ).firstMatch(userMessage);
      if (writeMatch != null) {
        return {
          'action': 'write',
          'key': 'note_${DateTime.now().millisecondsSinceEpoch}',
          'content': writeMatch.group(1)!.trim(),
        };
      }
      return {'action': 'list'};
    case 'timer':
      final durationMatch = RegExp(
        r'(\d+)\s*(?:second|sec|minute|min)',
        caseSensitive: false,
      ).firstMatch(msg);
      if (durationMatch != null) {
        final value = int.tryParse(durationMatch.group(1)!) ?? 0;
        final unit = msg.contains('min') ? value * 60 : value;
        return {'action': 'set', 'seconds': unit};
      }
      return null;
    default:
      return null;
  }
}

String? extractMathExpr(String msg) {
  final ops = {
    'plus': '+',
    'added to': '+',
    'and': '+',
    'minus': '-',
    'less': '-',
    'subtract': '-',
    'times': '*',
    'multiplied by': '*',
    'x': '*',
    'divided by': '/',
    'over': '/',
  };
  var expr = msg;
  expr = expr.replaceAll(RegExp(r'calculate\s*', caseSensitive: false), '');
  expr = expr.replaceAll(RegExp(r'what\s+is\s*', caseSensitive: false), '');
  expr = expr.replaceAll(RegExp(r'compute\s*', caseSensitive: false), '');
  for (final entry in ops.entries) {
    expr = expr.replaceAll(entry.key, entry.value);
  }
  expr = expr.replaceAll(RegExp(r'[^\d+\-*/.()% ]'), '').trim();
  if (expr.isEmpty || !RegExp(r'\d').hasMatch(expr)) {
    return null;
  }
  if (!RegExp(r'[+\-*/]').hasMatch(expr)) return null;
  return expr;
}
