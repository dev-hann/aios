import 'dart:convert';
import 'dart:developer' as developer;

import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';

class NotificationTool extends ExtendedTool {
  static const _tag = 'AIOS-NotificationTool';

  @override
  String get name => 'notification_reader';

  @override
  String get description =>
      'Read recent notifications. Args: {max_count}';

  @override
  String get parameters =>
      '{"max_count": "integer, max notifications (default 20)"}';

  @override
  Future<String> execute(String args, ToolContext toolContext) async {
    try {
      final json = _tryParseJson(args);
      final maxCount = _parseInt(json['max_count']) ?? 20;
      return await toolContext.invokeMethod(
            'getNotifications',
            {'max_count': maxCount},
          ) ??
          'No notifications';
    } on Object catch (e) {
      return 'Error: $e';
    }
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
