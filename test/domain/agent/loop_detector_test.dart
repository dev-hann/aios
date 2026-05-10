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
        const ToolResult.ok('result'),
      );
      expect(result, isA<LoopOk>());
    });

    test('record_differentActions_returnsOk', () {
      detector
        ..record('calculator', '{}', const ToolResult.ok('5'))
        ..record('timer', '{"seconds": 5}', const ToolResult.ok('done'));
      final result = detector.record(
        'notepad',
        '{"action": "list"}',
        const ToolResult.ok('none'),
      );
      expect(result, isA<LoopOk>());
    });

    test('record_threeConsecutiveSameActions_returnsWarning', () {
      detector
        ..record(
          'calculator',
          '{"expression": "1+1"}',
          const ToolResult.ok('result 1'),
        )
        ..record(
          'calculator',
          '{"expression": "1+1"}',
          const ToolResult.ok('result 2'),
        );
      final result = detector.record(
        'calculator',
        '{"expression": "1+1"}',
        const ToolResult.ok('result 3'),
      );
      expect(result, isA<LoopWarning>());
      final warning = result as LoopWarning;
      expect(warning.toolName, 'calculator');
      expect(warning.count, 3);
    });

    test('record_warningThenRepeat_returnsForceBreak', () {
      detector
        ..record(
          'calculator',
          '{"expression": "1+1"}',
          const ToolResult.ok('a'),
        )
        ..record(
          'calculator',
          '{"expression": "1+1"}',
          const ToolResult.ok('b'),
        );
      final warning = detector.record(
        'calculator',
        '{"expression": "1+1"}',
        const ToolResult.ok('c'),
      );
      expect(warning, isA<LoopWarning>());

      final force = detector.record(
        'calculator',
        '{"expression": "1+1"}',
        const ToolResult.ok('d'),
      );
      expect(force, isA<LoopForceBreak>());
    });

    test('record_identicalObservations_returnsForceBreak', () {
      detector.record(
        'screen_action',
        '{"action": "tap", "x": 1}',
        const ToolResult.ok('same'),
      );
      final warning = detector.record(
        'screen_action',
        '{"action": "tap", "x": 2}',
        const ToolResult.ok('same'),
      );
      expect(warning, isA<LoopWarning>());
    });

    test('record_scrollRepeats_returnsOk', () {
      detector
        ..record(
          'screen_action',
          '{"action": "scroll"}',
          const ToolResult.ok('scrolled 1'),
        )
        ..record(
          'screen_action',
          '{"action": "scroll"}',
          const ToolResult.ok('scrolled 2'),
        );
      final result = detector.record(
        'screen_action',
        '{"action": "scroll"}',
        const ToolResult.ok('scrolled 3'),
      );
      expect(result, isA<LoopOk>());
    });

    test('record_swipeRepeats_returnsOk', () {
      detector
        ..record(
          'screen_action',
          '{"action": "swipe"}',
          const ToolResult.ok('swiped 1'),
        )
        ..record(
          'screen_action',
          '{"action": "swipe"}',
          const ToolResult.ok('swiped 2'),
        );
      final result = detector.record(
        'screen_action',
        '{"action": "swipe"}',
        const ToolResult.ok('swiped 3'),
      );
      expect(result, isA<LoopOk>());
    });
  });

  group('shouldNudge', () {
    test('shouldNudge_threeIterationsWithoutAnswer_returnsTrue', () {
      expect(detector.shouldNudge(3, hasAnswer: false), true);
    });

    test('shouldNudge_answerExists_returnsFalse', () {
      expect(detector.shouldNudge(5, hasAnswer: true), false);
    });

    test('shouldNudge_lessThanThreeIterations_returnsFalse', () {
      expect(detector.shouldNudge(2, hasAnswer: false), false);
    });

    test('shouldNudge_afterWarningGiven_returnsFalse', () {
      detector
        ..record('calc', '{}', const ToolResult.ok('a'))
        ..record('calc', '{}', const ToolResult.ok('b'))
        ..record('calc', '{}', const ToolResult.ok('c'));
      expect(detector.shouldNudge(4, hasAnswer: false), false);
    });
  });

  group('reset', () {
    test('reset_clearsHistoryAndWarningState', () {
      detector
        ..record('calc', '{"a": 1}', const ToolResult.ok('x'))
        ..record('calc', '{"a": 1}', const ToolResult.ok('y'));
      expect(
        detector.record('calc', '{"a": 1}', const ToolResult.ok('z')),
        isA<LoopWarning>(),
      );

      detector.reset();

      final result = detector.record(
        'calc',
        '{"a": 1}',
        const ToolResult.ok('v'),
      );
      expect(result, isA<LoopOk>());
    });
  });

  group('edge cases', () {
    test('record_exactlyTwoCalls_returnsOk', () {
      detector.record('calc', '{}', const ToolResult.ok('a'));
      final result = detector.record('calc', '{}', const ToolResult.ok('b'));
      expect(result, isA<LoopOk>());
    });

    test('record_sameToolDifferentArgs_returnsOk', () {
      detector
        ..record('calc', '{"expression": "1+1"}', const ToolResult.ok('2'))
        ..record('calc', '{"expression": "3+4"}', const ToolResult.ok('7'));
      final result = detector.record(
        'calc',
        '{"expression": "5+5"}',
        const ToolResult.ok('10'),
      );
      expect(result, isA<LoopOk>());
    });

    test('record_globalActionRepeats_returnsOk', () {
      detector
        ..record(
          'screen_action',
          '{"action": "global"}',
          const ToolResult.ok('done 1'),
        )
        ..record(
          'screen_action',
          '{"action": "global"}',
          const ToolResult.ok('done 2'),
        );
      final result = detector.record(
        'screen_action',
        '{"action": "global"}',
        const ToolResult.ok('done 3'),
      );
      expect(result, isA<LoopOk>());
    });

    test('record_interleavedDifferentTools_returnsOk', () {
      detector
        ..record('calc', '{}', const ToolResult.ok('a'))
        ..record('timer', '{}', const ToolResult.ok('b'))
        ..record('calc', '{}', const ToolResult.ok('c'));
      final result = detector.record('calc', '{}', const ToolResult.ok('d'));
      expect(result, isA<LoopOk>());
    });

    test('shouldNudge_atExactly3Iterations_returnsTrue', () {
      expect(detector.shouldNudge(3, hasAnswer: false), true);
    });

    test('shouldNudge_atHighIterationCount_returnsTrue', () {
      expect(detector.shouldNudge(10, hasAnswer: false), true);
    });

    test('reset_preservesNoSideEffects', () {
      detector
        ..record('a', '{}', const ToolResult.ok('x'))
        ..record('a', '{}', const ToolResult.ok('y'))
        ..record('a', '{}', const ToolResult.ok('z'))
        ..reset();

      expect(detector.shouldNudge(1, hasAnswer: false), false);
    });
  });
}
