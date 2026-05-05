import 'dart:convert';

import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';

class NotificationTool implements ExtendedTool {
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
      final maxCount = json['max_count'] as int? ?? 20;
      return await toolContext.invokeMethod(
            'getNotifications',
            {'max_count': maxCount},
          ) ??
          'No notifications';
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
