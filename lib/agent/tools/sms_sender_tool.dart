import 'dart:convert';

import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';

class SmsSenderTool implements ExtendedTool {
  @override
  String get name => 'sms_sender';

  @override
  String get description =>
      'Send/read SMS. Args: {action: send|read, to, body, limit}';

  @override
  String get parameters =>
      '{"action": "send|read", "to": "string", '
      '"body": "string", "limit": "integer (default 10)"}';

  @override
  Future<String> execute(String args, ToolContext toolContext) async {
    try {
      final json = _tryParseJson(args);
      final action = json['action']?.toString().toLowerCase() ?? '';

      return switch (action) {
        'send' => _sendSms(json, toolContext),
        'read' => _readSms(json, toolContext),
        _ => "Error: Unknown action '$action'. Use 'send' or 'read'.",
      };
    } on Object catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> _sendSms(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final to = json['to']?.toString().trim() ?? '';
    final body = json['body']?.toString().trim() ?? '';
    if (to.isEmpty) return "Error: 'to' required (phone number)";
    if (body.isEmpty) return "Error: 'body' required (message text)";
    return await toolContext.invokeMethod(
          'sendSms',
          {'to': to, 'body': body},
        ) ??
        'Error';
  }

  Future<String> _readSms(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final limit = json['limit'] as int? ?? 10;
    return await toolContext.invokeMethod(
          'readSms',
          {'limit': limit},
        ) ??
        'Error';
  }

  Map<String, dynamic> _tryParseJson(String args) {
    try {
      return json.decode(args) as Map<String, dynamic>;
    } on Object {
      return {};
    }
  }
}
