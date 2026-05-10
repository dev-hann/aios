import 'dart:convert';

import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:aios/domain/agent/tool_result.dart';

class PhoneCallerTool extends ExtendedTool {
  static const _tag = 'AIOS-PhoneCaller';

  @override
  String get name => 'phone_caller';

  @override
  String get description =>
      'Call or dial a phone number. Args: {action: call|dial, number}';

  @override
  String get parameters => '{"action": "call|dial", "number": "string"}';

  @override
  String get toolPrompt =>
      'Make phone calls or dial numbers.\n\n'
      'Actions:\n'
      '- call: Directly make a phone call\n'
      '- dial: Open the dialer with the number\n\n'
      'Parameters: $parameters\n\n'
      'Rules:\n'
      '- "number" is required and must be a valid phone number\n'
      '- Use "call" to directly call, "dial" to open dialer\n'
      '- Numbers should be digits only (e.g. 01012345678)\n'
      '- Respond with user language';

  @override
  Future<ToolResult> execute(String args, ToolContext toolContext) async {
    try {
      final json = _tryParseJson(args);
      final action = json['action']?.toString().toLowerCase() ?? 'dial';
      final number = json['number']?.toString().trim() ?? '';
      if (number.isEmpty) return const ToolResult.err("'number' required");
      final result = await toolContext.invokeMethod('makeCall', {
        'action': action,
        'number': number,
      });
      if (result == null) {
        return const ToolResult.err(
          'phone call failed - no response from platform',
        );
      }
      return ToolResult.ok(result);
    } on Object catch (e) {
      return ToolResult.err('$e');
    }
  }

  Map<String, dynamic> _tryParseJson(String args) {
    try {
      final decoded = json.decode(args);
      if (decoded is Map<String, dynamic>) return decoded;
      print('[$_tag] WARN: Invalid JSON type: ${decoded.runtimeType}');
      return {};
    } on Object catch (e) {
      print('[$_tag] WARN: JSON parse error: $e');
      return {};
    }
  }
}
