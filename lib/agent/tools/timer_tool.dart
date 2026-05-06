import 'dart:convert';

import 'package:aios/domain/agent/agent_tool.dart';

class TimerTool implements AgentTool {
  @override
  String get name => 'timer';

  @override
  String get description => 'Set a countdown timer. Args: {seconds: int}';

  @override
  String get parameters =>
      '{"seconds": "integer, number of seconds to wait"}';

  @override
  String execute(String args) {
    try {
      final json = jsonDecode(args) as Map<String, dynamic>;
      final secs = json['seconds'] as int? ?? 0;
      if (secs <= 0 || secs > 300) {
        return 'Error: seconds must be 1-300';
      }
      return 'Timer requested: ${secs}s. '
          'Note: timer execution requires async context.';
    } on Object catch (e) {
      return 'Error: $e';
    }
  }
}
