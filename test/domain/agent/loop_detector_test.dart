import 'package:aios/domain/agent/loop_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LoopDetector detector;

  setUp(() {
    detector = LoopDetector();
  });

  group('record', () {
    test('ok on first call', () {
      final result = detector.record('calculator', '{}', 'result');
      expect(result, isA<LoopOk>());
    });

    test('ok on different actions', () {
      detector.record('calculator', '{}', '5');
      detector.record('timer', '{"seconds": 5}', 'done');
      final result = detector.record('notepad', '{"action": "list"}', 'none');
      expect(result, isA<LoopOk>());
    });

    test('warning after 3 consecutive same actions', () {
      detector.record('calculator', '{"expression": "1+1"}', 'result 1');
      detector.record('calculator', '{"expression": "1+1"}', 'result 2');
      final result =
          detector.record('calculator', '{"expression": "1+1"}', 'result 3');
      expect(result, isA<LoopWarning>());
      final warning = result as LoopWarning;
      expect(warning.toolName, 'calculator');
      expect(warning.count, 3);
    });

    test('force break after warning then repeat', () {
      detector.record('calculator', '{"expression": "1+1"}', 'a');
      detector.record('calculator', '{"expression": "1+1"}', 'b');
      final warning =
          detector.record('calculator', '{"expression": "1+1"}', 'c');
      expect(warning, isA<LoopWarning>());

      final force =
          detector.record('calculator', '{"expression": "1+1"}', 'd');
      expect(force, isA<LoopForceBreak>());
    });

    test('force break on identical observations', () {
      detector.record('screen_action', '{"action": "tap", "x": 1}', 'same');
      final warning = detector.record(
        'screen_action',
        '{"action": "tap", "x": 2}',
        'same',
      );
      expect(warning, isA<LoopWarning>());
    });

    test('allowed repeated actions for scroll', () {
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

    test('allowed repeated actions for swipe', () {
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
    test('nudge after 3 iterations without answer', () {
      expect(detector.shouldNudge(3, false), true);
    });

    test('no nudge when answer exists', () {
      expect(detector.shouldNudge(5, true), false);
    });

    test('no nudge before 3 iterations', () {
      expect(detector.shouldNudge(2, false), false);
    });

    test('no nudge after warning given', () {
      detector.record('calc', '{}', 'a');
      detector.record('calc', '{}', 'b');
      detector.record('calc', '{}', 'c');
      expect(detector.shouldNudge(4, false), false);
    });
  });

  group('reset', () {
    test('clears history and warning state', () {
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
}
