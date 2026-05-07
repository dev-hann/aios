import 'dart:convert';
import 'dart:developer' as developer;

import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';

class SmsSenderTool extends ExtendedTool {
  static const _tag = 'AIOS-SmsSender';

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
    if (to.isEmpty) return "Error: 'to' required";
    if (body.isEmpty) return "Error: 'body' required";
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
    final limit = _parseInt(json['limit']) ?? 10;
    return await toolContext.invokeMethod(
          'readSms',
          {'limit': limit},
        ) ??
        'Error';
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> _tryParseJson(String args) {
    try {
      final decoded = json.decode(args);
      if (decoded is Map<String, dynamic>) return decoded;
      developer.log(
        'Invalid JSON type: ${decoded.runtimeType}',
        name: _tag,
        level: 900,
      );
      return {};
    } on Object catch (e) {
      developer.log(
        'JSON parse error: $e',
        name: _tag,
        level: 900,
      );
      return {};
    }
  }
}
