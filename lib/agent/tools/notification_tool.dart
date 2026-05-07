import 'dart:convert';

import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';

class NotificationTool extends ExtendedTool {
  static const _tag = 'AIOS-Notification';

  @override
  String get name => 'notification_reader';

  @override
  String get description =>
      'Read device notifications. '
      'Args: {action, app, max_count}';

  @override
  String get parameters =>
      '{"action": "list|read", '
      '"app": "string (app name to filter)", '
      '"max_count": "integer, max notifications (default 20)"}';

  @override
  String get toolPrompt =>
      'Read device notifications.\n\n'
      'Actions:\n'
      '- list: List all recent notifications\n'
      '- read: Read notifications from a specific app\n\n'
      'Parameters: $parameters\n\n'
      'Rules:\n'
      '- Default action is list (shows all notifications)\n'
      '- Use read with app name to filter by app\n'
      '- app can be partial match (e.g. "kakao" for KakaoTalk)\n'
      '- Use max_count to limit number of results\n'
      '- Respond with user language';

  @override
  Future<String> execute(String args, ToolContext toolContext) async {
    try {
      final json = _tryParseJson(args);
      final action = json['action']?.toString().toLowerCase() ?? 'list';
      final app = json['app']?.toString() ?? '';
      final maxCount = _parseInt(json['max_count']) ?? 20;

      return await _handleRead(
        toolContext,
        maxCount: maxCount,
        app: app,
      );
    } on Object catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> _handleRead(
    ToolContext toolContext, {
    int maxCount = 20,
    String app = '',
  }) async {
    print('[$_tag] Reading notifications: app="$app", max=$maxCount');
    final methodArgs = <String, dynamic>{'max_count': maxCount};
    if (app.isNotEmpty) {
      methodArgs['app'] = app;
    }
    final result = await toolContext.invokeMethod(
          'getNotifications',
          methodArgs,
        ) ??
        'No notifications';
    return result;
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
      print('[$_tag] WARN: Invalid JSON type: ${decoded.runtimeType}');
      return {};
    } on Object catch (e) {
      print('[$_tag] WARN: JSON parse error: $e');
      return {};
    }
  }
}
