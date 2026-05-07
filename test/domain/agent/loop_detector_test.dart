import 'package:aios/domain/agent/loop_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LoopDetector detector;

  setUp(() {
    detector = LoopDetector();
  });

  group('record', () {
    test('record_firstCall_returnsOk', () {
      final result = detector.record('calculator', '{}', 'result');
      expect(result, isA<LoopOk>());
    });

    test('record_differentActions_returnsOk', () {
      detector.record('calculator', '{}', '5');
      detector.record('timer', '{"seconds": 5}', 'done');
      final result = detector.record('notepad', '{"action": "list"}', 'none');
      expect(result, isA<LoopOk>());
    });

    test('record_threeConsecutiveSameActions_returnsWarning', () {
      detector.record('calculator', '{"expression": "1+1"}', 'result 1');
      detector.record('calculator', '{"expression": "1+1"}', 'result 2');
      final result =
          detector.record('calculator', '{"expression": "1+1"}', 'result 3');
      expect(result, isA<LoopWarning>());
      final warning = result as LoopWarning;
      expect(warning.toolName, 'calculator');
      expect(warning.count, 3);
    });

    test('record_warningThenRepeat_returnsForceBreak', () {
      detector.record('calculator', '{"expression": "1+1"}', 'a');
      detector.record('calculator', '{"expression": "1+1"}', 'b');
      final warning =
          detector.record('calculator', '{"expression": "1+1"}', 'c');
      expect(warning, isA<LoopWarning>());

      final force =
          detector.record('calculator', '{"expression": "1+1"}', 'd');
      expect(force, isA<LoopForceBreak>());
    });

    test('record_identicalObservations_returnsForceBreak', () {
      detector.record('screen_action', '{"action": "tap", "x": 1}', 'same');
      final warning = detector.record(
        'screen_action',
        '{"action": "tap", "x": 2}',
        'same',
      );
      expect(warning, isA<LoopWarning>());
    });

    test('record_scrollRepeats_returnsOk', () {
      detector.record('screen_action', '{"action": "scroll"}', 'scrolled 1');
      detector.record('screen_action', '{"action": "scroll"}', 'scrolled 2');
      final result =
          detector.record(
            'screen_action',
            '{"action": "scroll"}',
            'scrolled 3',
          );
      expect(result, isA<LoopOk>());
    });

    test('record_swipeRepeats_returnsOk', () {
      detector.record('screen_action', '{"action": "swipe"}', 'swiped 1');
      detector.record('screen_action', '{"action": "swipe"}', 'swiped 2');
      final result =
          detector.record(
            'screen_action',
            '{"action": "swipe"}',
            'swiped 3',
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
      detector.record('calc', '{}', 'a');
      detector.record('calc', '{}', 'b');
      detector.record('calc', '{}', 'c');
      expect(detector.shouldNudge(4, false), false);
    });
  });

  group('reset', () {
    test('reset_clearsHistoryAndWarningState', () {
      detector.record('calc', '{"a": 1}', 'x');
      detector.record('calc', '{"a": 1}', 'y');
      expect(
        detector.record('calc', '{"a": 1}', 'z'),
        isA<LoopWarning>(),
      );

      detector.reset();

      final result = detector.record('calc', '{"a": 1}', 'v');
      expect(result, isA<LoopOk>());
    });
  });

  group('edge cases', () {
    test('record_exactlyTwoCalls_returnsOk', () {
      detector.record('calc', '{}', 'a');
      final result = detector.record('calc', '{}', 'b');
      expect(result, isA<LoopOk>());
    });

    test('record_sameToolDifferentArgs_returnsOk', () {
      detector.record('calc', '{"expression": "1+1"}', '2');
      detector.record('calc', '{"expression": "3+4"}', '7');
      final result =
          detector.record('calc', '{"expression": "5+5"}', '10');
      expect(result, isA<LoopOk>());
    });

    test('record_globalActionRepeats_returnsOk', () {
      detector.record('screen_action', '{"action": "global"}', 'done 1');
      detector.record('screen_action', '{"action": "global"}', 'done 2');
      final result =
          detector.record('screen_action', '{"action": "global"}', 'done 3');
      expect(result, isA<LoopOk>());
    });

    test('record_interleavedDifferentTools_returnsOk', () {
      detector.record('calc', '{}', 'a');
      detector.record('timer', '{}', 'b');
      detector.record('calc', '{}', 'c');
      final result = detector.record('calc', '{}', 'd');
      expect(result, isA<LoopOk>());
    });

    test('shouldNudge_atExactly3Iterations_returnsTrue', () {
      expect(detector.shouldNudge(3, false), true);
    });

    test('shouldNudge_atHighIterationCount_returnsTrue', () {
      expect(detector.shouldNudge(10, false), true);
    });

    test('reset_preservesNoSideEffects', () {
      detector.record('a', '{}', 'x');
      detector.record('a', '{}', 'y');
      detector.record('a', '{}', 'z');

      detector.reset();

      expect(detector.shouldNudge(1, false), false);
    });
  });
}
