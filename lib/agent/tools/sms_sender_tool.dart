import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:aios/domain/agent/tool_json_parser.dart';
import 'package:aios/domain/agent/tool_result.dart';

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
  String get toolPrompt =>
      'Send and read SMS messages.\n\n'
      'Actions:\n'
      '- send: Send an SMS to a phone number\n'
      '- read: Read recent SMS messages\n\n'
      'Parameters: $parameters\n\n'
      'Rules:\n'
      '- send requires both "to" (phone number) and "body" (message)\n'
      '- "to" must be a valid phone number (e.g. 01012345678)\n'
      '- read shows recent messages, use "limit" to control count\n'
      '- Respond with user language';

  @override
  Future<ToolResult> execute(String args, ToolContext toolContext) async {
    try {
      final json = tryParseToolJson(args, _tag);
      final action = json['action']?.toString().toLowerCase() ?? '';

      return switch (action) {
        'send' => _sendSms(json, toolContext),
        'read' => _readSms(json, toolContext),
        _ => ToolResult.err("Unknown action '$action'. Use 'send' or 'read'."),
      };
    } on Object catch (e) {
      return ToolResult.err('$e');
    }
  }

  Future<ToolResult> _sendSms(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final to = json['to']?.toString().trim() ?? '';
    final body = json['body']?.toString().trim() ?? '';
    if (to.isEmpty) return const ToolResult.err("'to' required");
    if (body.isEmpty) return const ToolResult.err("'body' required");
    final result = await toolContext.invokeMethod('sendSms', {
      'to': to,
      'body': body,
    });
    if (result == null) {
      return const ToolResult.err(
        'SMS send failed - no response from platform',
      );
    }
    return ToolResult.ok(result);
  }

  Future<ToolResult> _readSms(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final limit = parseIntDynamic(json['limit']) ?? 10;
    final result = await toolContext.invokeMethod('readSms', {'limit': limit});
    if (result == null) {
      return const ToolResult.err(
        'SMS read failed - no response from platform',
      );
    }
    return ToolResult.ok(result);
  }
}
