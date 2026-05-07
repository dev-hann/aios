import 'dart:convert';

import 'package:aios/domain/agent/agent_tool.dart';

class TimerTool extends AgentTool {
  static const _tag = 'AIOS-TimerTool';

  @override
  String get name => 'timer';

  @override
  String get description => 'Set a countdown timer. Args: {seconds: int}';

  @override
  String get parameters =>
      '{"seconds": "integer, number of seconds to wait"}';

  @override
  Future<String> execute(String args) async {
    try {
      final json = _tryParseJson(args);
      final secs = _parseInt(json['seconds']) ?? 0;
      if (secs <= 0 || secs > 300) {
        return "Error: 'seconds' must be 1-300";
      }
      return 'Timer requested: ${secs}s. '
          'Note: timer execution requires async context.';
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
      print('[$_tag] WARN: Invalid JSON type: ${decoded.runtimeType}');
      return {};
    } on Object catch (e) {
      print('[$_tag] WARN: JSON parse error: $e');
      return {};
    }
  }
}
