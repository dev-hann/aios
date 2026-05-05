import 'dart:convert';

import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';

class PhoneCallerTool implements ExtendedTool {
  @override
  String get name => 'phone_caller';

  @override
  String get description =>
      'Call or dial a number. Args: {action: call|dial, number}';

  @override
  String get parameters =>
      '{"action": "call|dial", "number": "string"}';

  @override
  Future<String> execute(String args, ToolContext toolContext) async {
    try {
      final json = _tryParseJson(args);
      final action = json['action']?.toString().toLowerCase() ?? 'dial';
      final number = json['number']?.toString().trim() ?? '';
      if (number.isEmpty) return "Error: 'number' required";
      return await toolContext.invokeMethod(
            'makeCall',
            {'action': action, 'number': number},
          ) ??
          'Error';
    } on Object catch (e) {
      return 'Error: $e';
    }
  }

  Map<String, dynamic> _tryParseJson(String args) {
    try {
      return json.decode(args) as Map<String, dynamic>;
    } on Object {
      return {};
    }
  }
}
