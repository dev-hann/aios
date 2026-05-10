import 'package:aios/agent/tools/timer_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TimerTool tool;
  late Map<String, TimerEntry> timers;

  setUp(() {
    timers = {};
    tool = TimerTool(timers);
  });

  group('execute_set', () {
    test('execute_setWithSeconds_succeeds', () async {
      final result = await tool.execute('{"action": "set", "seconds": 60}');
      expect(result.output, contains('Timer'));
      expect(result.output, contains('60'));
      expect(timers.containsKey('default'), isTrue);
      expect(timers['default']!.durationSeconds, 60);
    });

    test('execute_setWithCustomName_succeeds', () async {
      final result = await tool.execute(
        '{"action": "set", "seconds": 30, "name": "egg"}',
      );
      expect(result.output, contains('30'));
      expect(timers.containsKey('egg'), isTrue);
    });

    test('execute_setOneSecond_succeeds', () async {
      final result = await tool.execute('{"action": "set", "seconds": 1}');
      expect(result.isError, isFalse);
    });

    test('execute_set300Seconds_succeeds', () async {
      final result = await tool.execute('{"action": "set", "seconds": 300}');
      expect(result.isError, isFalse);
    });

    test('execute_setZeroSeconds_returnsError', () async {
      final result = await tool.execute('{"action": "set", "seconds": 0}');
      expect(result.toContent(), "Error: 'seconds' must be 1-300");
    });

    test('execute_setNegativeSeconds_returnsError', () async {
      final result = await tool.execute('{"action": "set", "seconds": -1}');
      expect(result.toContent(), "Error: 'seconds' must be 1-300");
    });

    test('execute_setOver300Seconds_returnsError', () async {
      final result = await tool.execute('{"action": "set", "seconds": 301}');
      expect(result.toContent(), "Error: 'seconds' must be 1-300");
    });

    test('execute_setMissingSeconds_returnsError', () async {
      final result = await tool.execute('{"action": "set"}');
      expect(result.toContent(), "Error: 'seconds' must be 1-300");
    });

    test('execute_setOverwritesExistingTimer', () async {
      timers['default'] = TimerEntry(
        startedAt: DateTime.now(),
        durationSeconds: 10,
      );
      final result = await tool.execute('{"action": "set", "seconds": 60}');
      expect(result.isError, isFalse);
      expect(timers['default']!.durationSeconds, 60);
    });
  });

  group('execute_check', () {
    test('execute_checkActiveTimer_returnsRemaining', () async {
      timers['default'] = TimerEntry(
        startedAt: DateTime.now(),
        durationSeconds: 60,
      );
      final result = await tool.execute('{"action": "check"}');
      expect(result.output, contains('remaining'));
    });

    test('execute_checkNamedTimer_returnsRemaining', () async {
      timers['egg'] = TimerEntry(
        startedAt: DateTime.now(),
        durationSeconds: 30,
      );
      final result = await tool.execute('{"action": "check", "name": "egg"}');
      expect(result.output, contains('remaining'));
    });

    test('execute_checkNonExistentTimer_returnsError', () async {
      final result = await tool.execute('{"action": "check"}');
      expect(result.toContent(), "Error: No timer found");
    });

    test('execute_checkExpiredTimer_returnsExpired', () async {
      timers['default'] = TimerEntry(
        startedAt: DateTime.now().subtract(const Duration(seconds: 60)),
        durationSeconds: 30,
      );
      final result = await tool.execute('{"action": "check"}');
      expect(result.output, contains('expired'));
    });
  });

  group('execute_cancel', () {
    test('execute_cancelExistingTimer_succeeds', () async {
      timers['default'] = TimerEntry(
        startedAt: DateTime.now(),
        durationSeconds: 60,
      );
      final result = await tool.execute('{"action": "cancel"}');
      expect(result.output, contains('Cancelled'));
      expect(timers.containsKey('default'), isFalse);
    });

    test('execute_cancelNamedTimer_succeeds', () async {
      timers['egg'] = TimerEntry(
        startedAt: DateTime.now(),
        durationSeconds: 30,
      );
      final result = await tool.execute('{"action": "cancel", "name": "egg"}');
      expect(result.output, contains('Cancelled'));
      expect(timers.containsKey('egg'), isFalse);
    });

    test('execute_cancelNonExistentTimer_returnsError', () async {
      final result = await tool.execute('{"action": "cancel"}');
      expect(result.toContent(), "Error: No timer found");
    });
  });

  group('execute_list', () {
    test('execute_listEmpty_returnsNoTimers', () async {
      final result = await tool.execute('{"action": "list"}');
      expect(result.output, 'No active timers');
    });

    test('execute_listWithTimers_returnsFormatted', () async {
      timers['default'] = TimerEntry(
        startedAt: DateTime.now(),
        durationSeconds: 60,
      );
      timers['egg'] = TimerEntry(
        startedAt: DateTime.now(),
        durationSeconds: 30,
      );
      final result = await tool.execute('{"action": "list"}');
      expect(result.output, contains('default'));
      expect(result.output, contains('egg'));
    });
  });

  group('execute_unknownAction', () {
    test('execute_unknownAction_returnsError', () async {
      final result = await tool.execute('{"action": "unknown"}');
      expect(result.toContent(), contains("Error: Unknown action 'unknown'"));
      expect(result.toContent(), contains('set'));
    });
  });

  group('execute_malformedInput', () {
    test('execute_malformedJson_returnsError', () async {
      final result = await tool.execute('not json');
      expect(result.isError, isTrue);
    });

    test('execute_stringSeconds_parsesCorrectly', () async {
      final result = await tool.execute('{"action": "set", "seconds": "60"}');
      expect(result.isError, isFalse);
    });
  });

  group('name_andMetadata', () {
    test('name_returnsTimer', () {
      expect(tool.name, 'timer');
    });

    test('description_isNotEmpty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });

    test('parameters_isNotEmpty', () {
      expect(tool.parameters.isNotEmpty, isTrue);
    });

    test('toolPrompt_containsActionTypes', () {
      expect(tool.toolPrompt, contains('set'));
      expect(tool.toolPrompt, contains('check'));
      expect(tool.toolPrompt, contains('cancel'));
      expect(tool.toolPrompt, contains('list'));
    });

    test('toolPrompt_containsKoreanTimeConversion', () {
      expect(tool.toolPrompt, contains('분'));
      expect(tool.toolPrompt, contains('초'));
    });

    test('toolPrompt_containsSecondsRange', () {
      expect(tool.toolPrompt, contains('300'));
    });

    test('toolPrompt_containsParameters', () {
      expect(tool.toolPrompt, contains('Parameters'));
    });
  });
}
