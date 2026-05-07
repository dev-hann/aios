import 'package:aios/agent/tools/timer_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TimerTool tool;

  setUp(() {
    tool = TimerTool();
  });

  group('execute_validSeconds', () {
    test('execute_validSeconds_returnsTimerMessage', () async {
      final result = await tool.execute('{"seconds": 5}');
      expect(result.contains('5'), isTrue);
      expect(result.startsWith('Error:'), isFalse);
    });

    test('execute_minBoundaryOneSecond_returnsTimerMessage', () async {
      final result = await tool.execute('{"seconds": 1}');
      expect(result.startsWith('Error:'), isFalse);
    });

    test('execute_maxBoundary300Seconds_returnsTimerMessage', () async {
      final result = await tool.execute('{"seconds": 300}');
      expect(result.startsWith('Error:'), isFalse);
    });
  });

  group('execute_invalidSeconds', () {
    test('execute_zeroSeconds_returnsError', () async {
      final result = await tool.execute('{"seconds": 0}');
      expect(result, "Error: 'seconds' must be 1-300");
    });

    test('execute_negativeSeconds_returnsError', () async {
      final result = await tool.execute('{"seconds": -1}');
      expect(result, "Error: 'seconds' must be 1-300");
    });

    test('execute_over300Seconds_returnsError', () async {
      final result = await tool.execute('{"seconds": 301}');
      expect(result, "Error: 'seconds' must be 1-300");
    });

    test('execute_missingSeconds_defaultsToZeroReturnsError', () async {
      final result = await tool.execute('{}');
      expect(result, "Error: 'seconds' must be 1-300");
    });
  });

  group('execute_malformedInput', () {
    test('execute_malformedJson_returnsError', () async {
      final result = await tool.execute('not json');
      expect(result.startsWith('Error:'), isTrue);
    });
  });

  group('name_andMetadata', () {
    test('name_returnsTimer', () async {
      expect(tool.name, 'timer');
    });

    test('description_isNotEmpty', () async {
      expect(tool.description.isNotEmpty, isTrue);
    });
  });
}
