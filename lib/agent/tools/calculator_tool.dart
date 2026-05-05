import 'dart:convert';

import 'package:aios/domain/agent/agent_tool.dart';

class CalculatorTool implements AgentTool {
  @override
  String get name => 'calculator';

  @override
  String get description => 'Evaluate math expression. Args: {expression}';

  @override
  String get parameters => '{"expression": "string"}';

  @override
  String execute(String args) {
    try {
      final json = jsonDecode(args) as Map<String, dynamic>;
      final expr = json['expression']?.toString() ?? '';
      final sanitized =
          expr.replaceAll(RegExp(r'[^0-9+\-*/.()% ]'), '');
      if (sanitized.isEmpty) return 'Error: empty expression';
      final result = _evalExpr(sanitized);
      return result.toStringAsFixed(4);
    } on Object catch (e) {
      return 'Error: $e';
    }
  }

  double _evalExpr(String expr) {
    final tokens = expr.replaceAll(' ', '').split('');
    final values = <double>[];
    final ops = <String>[];
    final precedence = {'+': 1, '-': 1, '*': 2, '/': 2};
    var i = 0;

    void applyOp() {
      final b = values.removeLast();
      final a = values.removeLast();
      final op = ops.removeLast();
      values.add(switch (op) {
        '+' => a + b,
        '-' => a - b,
        '*' => a * b,
        '/' => a / b,
        _ => a,
      });
    }

    while (i < tokens.length) {
      final c = tokens[i];
      if (c == '(') {
        ops.add(c);
      } else if (c == ')') {
        while (ops.isNotEmpty && ops.last != '(') {
          applyOp();
        }
        ops.removeLast();
      } else if (RegExp(r'[0-9.]').hasMatch(c)) {
        final sb = StringBuffer();
        while (i < tokens.length &&
            RegExp(r'[0-9.]').hasMatch(tokens[i])) {
          sb.write(tokens[i]);
          i++;
        }
        values.add(double.parse(sb.toString()));
        continue;
      } else if (precedence.containsKey(c)) {
        while (ops.isNotEmpty &&
            precedence[ops.last] != null &&
            precedence[ops.last]! >= precedence[c]!) {
          applyOp();
        }
        ops.add(c);
      }
      i++;
    }
    while (ops.isNotEmpty) {
      applyOp();
    }
    return values.last;
  }
}
