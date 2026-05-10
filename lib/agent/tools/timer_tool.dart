import 'package:aios/domain/agent/agent_tool.dart';
import 'package:aios/domain/agent/tool_json_parser.dart';
import 'package:aios/domain/agent/tool_result.dart';

class TimerEntry {
  TimerEntry({required this.startedAt, required this.durationSeconds});

  final DateTime startedAt;
  final int durationSeconds;

  int get remainingSeconds {
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final remaining = durationSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  bool get isExpired => remainingSeconds <= 0;
}

class TimerTool extends AgentTool {
  TimerTool(this._timers);

  static const _tag = 'AIOS-TimerTool';

  final Map<String, TimerEntry> _timers;

  @override
  String get name => 'timer';

  @override
  String get description =>
      'Set/check/cancel countdown timers. Args: {action, seconds, name}';

  @override
  String get parameters =>
      '{"action": "set|check|cancel|list", "seconds": "int 1-300", '
      '"name": "string (optional timer name)"}';

  @override
  String get toolPrompt =>
      'Manage timers (max 300s).\n\n'
      'Parameters: $parameters\n\n'
      'Actions:\n'
      '- set: start timer. Requires "seconds" (1-300)\n'
      '- check: show remaining time\n'
      '- cancel: stop timer\n'
      '- list: show active timers\n\n'
      'Rules:\n'
      '- Korean: "X분" = X*60s, "X초" = Xs\n'
      '- Default name is "default"';

  @override
  Future<ToolResult> execute(String args) async {
    try {
      final json = tryParseToolJson(args, _tag);
      final action = json['action']?.toString().toLowerCase() ?? '';
      return switch (action) {
        'set' => _set(json),
        'check' => _check(json),
        'cancel' => _cancel(json),
        'list' => _list(),
        '' => const ToolResult.err(
          "'action' required. Use set, check, cancel, or list.",
        ),
        _ => ToolResult.err(
          "Unknown action '$action'. Use set, check, cancel, or list.",
        ),
      };
    } on Object catch (e) {
      print('[$_tag] ERROR: $e');
      return ToolResult.err('$e');
    }
  }

  ToolResult _set(Map<String, dynamic> json) {
    final secs = parseIntDynamic(json['seconds']) ?? 0;
    if (secs <= 0 || secs > 300) {
      return const ToolResult.err("'seconds' must be 1-300");
    }
    final name = json['name']?.toString() ?? 'default';
    _timers[name] = TimerEntry(
      startedAt: DateTime.now(),
      durationSeconds: secs,
    );
    return ToolResult.ok('Timer "$name" set for $secs seconds');
  }

  ToolResult _check(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? 'default';
    final timer = _timers[name];
    if (timer == null) return const ToolResult.err('No timer found');
    if (timer.isExpired) {
      _timers.remove(name);
      return ToolResult.ok('Timer "$name" has expired');
    }
    return ToolResult.ok(
      'Timer "$name": ${timer.remainingSeconds} seconds remaining',
    );
  }

  ToolResult _cancel(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? 'default';
    if (_timers.remove(name) != null) {
      return ToolResult.ok('Cancelled timer "$name"');
    }
    return const ToolResult.err('No timer found');
  }

  ToolResult _list() {
    final expired = <String>[];
    for (final entry in _timers.entries) {
      if (entry.value.isExpired) expired.add(entry.key);
    }
    for (final name in expired) {
      _timers.remove(name);
    }
    if (_timers.isEmpty) return const ToolResult.ok('No active timers');
    return ToolResult.ok(
      _timers.entries
          .map(
            (e) =>
                '- ${e.key}: ${e.value.remainingSeconds}s remaining '
                '(${e.value.durationSeconds}s total)',
          )
          .join('\n'),
    );
  }
}
