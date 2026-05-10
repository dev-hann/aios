import 'package:aios/domain/agent/loop_detector.dart';
import 'package:aios/domain/agent/tool_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LoopDetector detector;

  setUp(() {
    detector = LoopDetector();
  });

  group('record', () {
    test('record_firstCall_returnsOk', () {
      final result = detector.record(
        'calculator',
        '{}',
        ToolResult.ok('result'),
      );
      expect(result, isA<LoopOk>());
    });

    test('record_differentActions_returnsOk', () {
      detector.record('calculator', '{}', ToolResult.ok('5'));
      detector.record('timer', '{"seconds": 5}', ToolResult.ok('done'));
      final result = detector.record(
        'notepad',
        '{"action": "list"}',
        ToolResult.ok('none'),
      );
      expect(result, isA<LoopOk>());
    });

    test('record_threeConsecutiveSameActions_returnsWarning', () {
      detector.record(
        'calculator',
        '{"expression": "1+1"}',
        ToolResult.ok('result 1'),
      );
      detector.record(
        'calculator',
        '{"expression": "1+1"}',
        ToolResult.ok('result 2'),
      );
      final result = detector.record(
        'calculator',
        '{"expression": "1+1"}',
        ToolResult.ok('result 3'),
      );
      expect(result, isA<LoopWarning>());
      final warning = result as LoopWarning;
      expect(warning.toolName, 'calculator');
      expect(warning.count, 3);
    });

    test('record_warningThenRepeat_returnsForceBreak', () {
      detector.record(
        'calculator',
        '{"expression": "1+1"}',
        ToolResult.ok('a'),
      );
      detector.record(
        'calculator',
        '{"expression": "1+1"}',
        ToolResult.ok('b'),
      );
      final warning = detector.record(
        'calculator',
        '{"expression": "1+1"}',
        ToolResult.ok('c'),
      );
      expect(warning, isA<LoopWarning>());

      final force = detector.record(
        'calculator',
        '{"expression": "1+1"}',
        ToolResult.ok('d'),
      );
      expect(force, isA<LoopForceBreak>());
    });

    test('record_identicalObservations_returnsForceBreak', () {
      detector.record(
        'screen_action',
        '{"action": "tap", "x": 1}',
        ToolResult.ok('same'),
      );
      final warning = detector.record(
        'screen_action',
        '{"action": "tap", "x": 2}',
        ToolResult.ok('same'),
      );
      expect(warning, isA<LoopWarning>());
    });

    test('record_scrollRepeats_returnsOk', () {
      detector.record(
        'screen_action',
        '{"action": "scroll"}',
        ToolResult.ok('scrolled 1'),
      );
      detector.record(
        'screen_action',
        '{"action": "scroll"}',
        ToolResult.ok('scrolled 2'),
      );
      final result = detector.record(
        'screen_action',
        '{"action": "scroll"}',
        ToolResult.ok('scrolled 3'),
      );
      expect(result, isA<LoopOk>());
    });

    test('record_swipeRepeats_returnsOk', () {
      detector.record(
        'screen_action',
        '{"action": "swipe"}',
        ToolResult.ok('swiped 1'),
      );
      detector.record(
        'screen_action',
        '{"action": "swipe"}',
        ToolResult.ok('swiped 2'),
      );
      final result = detector.record(
        'screen_action',
        '{"action": "swipe"}',
        ToolResult.ok('swiped 3'),
      );
      expect(result, isA<LoopOk>());
    });
  });

  group('shouldNudge', () {
    test('shouldNudge_threeIterationsWithoutAnswer_returnsTrue', () {
      expect(detector.shouldNudge(3, false), true);
    });

    test('shouldNudge_answerExists_returnsFalse', () {
      expect(detector.shouldNudge(5, true), false);
    });

    test('shouldNudge_lessThanThreeIterations_returnsFalse', () {
      expect(detector.shouldNudge(2, false), false);
    });

    test('shouldNudge_afterWarningGiven_returnsFalse', () {
      detector.record('calc', '{}', ToolResult.ok('a'));
      detector.record('calc', '{}', ToolResult.ok('b'));
      detector.record('calc', '{}', ToolResult.ok('c'));
      expect(detector.shouldNudge(4, false), false);
    });
  });

  group('reset', () {
    test('reset_clearsHistoryAndWarningState', () {
      detector.record('calc', '{"a": 1}', ToolResult.ok('x'));
      detector.record('calc', '{"a": 1}', ToolResult.ok('y'));
      expect(
        detector.record('calc', '{"a": 1}', ToolResult.ok('z')),
        isA<LoopWarning>(),
      );

      detector.reset();

      final result = detector.record('calc', '{"a": 1}', ToolResult.ok('v'));
      expect(result, isA<LoopOk>());
    });
  });

  group('edge cases', () {
    test('record_exactlyTwoCalls_returnsOk', () {
      detector.record('calc', '{}', ToolResult.ok('a'));
      final result = detector.record('calc', '{}', ToolResult.ok('b'));
      expect(result, isA<LoopOk>());
    });

    test('record_sameToolDifferentArgs_returnsOk', () {
      detector.record('calc', '{"expression": "1+1"}', ToolResult.ok('2'));
      detector.record('calc', '{"expression": "3+4"}', ToolResult.ok('7'));
      final result = detector.record(
        'calc',
        '{"expression": "5+5"}',
        ToolResult.ok('10'),
      );
      expect(result, isA<LoopOk>());
    });

    test('record_globalActionRepeats_returnsOk', () {
      detector.record(
        'screen_action',
        '{"action": "global"}',
        ToolResult.ok('done 1'),
      );
      detector.record(
        'screen_action',
        '{"action": "global"}',
        ToolResult.ok('done 2'),
      );
      final result = detector.record(
        'screen_action',
        '{"action": "global"}',
        ToolResult.ok('done 3'),
      );
      expect(result, isA<LoopOk>());
    });

    test('record_interleavedDifferentTools_returnsOk', () {
      detector.record('calc', '{}', ToolResult.ok('a'));
      detector.record('timer', '{}', ToolResult.ok('b'));
      detector.record('calc', '{}', ToolResult.ok('c'));
      final result = detector.record('calc', '{}', ToolResult.ok('d'));
      expect(result, isA<LoopOk>());
    });

    test('shouldNudge_atExactly3Iterations_returnsTrue', () {
      expect(detector.shouldNudge(3, false), true);
    });

    test('shouldNudge_atHighIterationCount_returnsTrue', () {
      expect(detector.shouldNudge(10, false), true);
    });

    test('reset_preservesNoSideEffects', () {
      detector.record('a', '{}', ToolResult.ok('x'));
      detector.record('a', '{}', ToolResult.ok('y'));
      detector.record('a', '{}', ToolResult.ok('z'));

      detector.reset();

      expect(detector.shouldNudge(1, false), false);
    });
  });
}
