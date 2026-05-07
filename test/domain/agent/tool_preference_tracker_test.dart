import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ToolPreferenceTracker', () {
    late ToolPreferenceTracker tracker;

    setUp(() {
      tracker = ToolPreferenceTracker();
    });

    group('recordToolUse', () {
      test('records_singleToolUse', () {
        tracker.recordToolUse('calculator');

        expect(tracker.getCount('calculator'), 1);
      });

      test('records_multipleUses_sameTool', () {
        tracker.recordToolUse('app_launcher');
        tracker.recordToolUse('app_launcher');
        tracker.recordToolUse('app_launcher');

        expect(tracker.getCount('app_launcher'), 3);
      });

      test('records_multipleTools_independently', () {
        tracker.recordToolUse('calculator');
        tracker.recordToolUse('calculator');
        tracker.recordToolUse('timer');

        expect(tracker.getCount('calculator'), 2);
        expect(tracker.getCount('timer'), 1);
        expect(tracker.getCount('notepad'), 0);
      });
    });

    group('getCount', () {
      test('returns_zero_forUnusedTool', () {
        expect(tracker.getCount('unknown'), 0);
      });
    });

    group('getMostUsed', () {
      test('returns_empty_whenNoUsage', () {
        expect(tracker.getMostUsed(), isEmpty);
      });

      test('returns_singleTool', () {
        tracker.recordToolUse('calculator');

        final result = tracker.getMostUsed();

        expect(result, ['calculator']);
      });

      test('returns_sortedByCount_descending', () {
        tracker.recordToolUse('calculator');
        tracker.recordToolUse('app_launcher');
        tracker.recordToolUse('app_launcher');
        tracker.recordToolUse('app_launcher');
        tracker.recordToolUse('timer');
        tracker.recordToolUse('timer');

        final result = tracker.getMostUsed();

        expect(result[0], 'app_launcher');
        expect(result[1], 'timer');
        expect(result[2], 'calculator');
      });

      test('respects_count_limit', () {
        for (var i = 0; i < 10; i++) {
          tracker.recordToolUse('tool$i');
        }

        final result = tracker.getMostUsed(3);

        expect(result, hasLength(3));
      });
    });

    group('toPromptContext', () {
      test('returns_empty_whenNoUsage', () {
        expect(tracker.toPromptContext(), isEmpty);
      });

      test('formats_singleTool', () {
        tracker.recordToolUse('calculator');
        tracker.recordToolUse('calculator');

        final prompt = tracker.toPromptContext();

        expect(prompt, contains('calculator'));
        expect(prompt, contains('2'));
      });

      test('formats_multipleTools_sorted', () {
        tracker.recordToolUse('timer');
        tracker.recordToolUse('app_launcher');
        tracker.recordToolUse('app_launcher');
        tracker.recordToolUse('calculator');

        final prompt = tracker.toPromptContext();

        expect(prompt, contains('app_launcher'));
        expect(prompt, contains('calculator'));
        expect(prompt, contains('timer'));
      });

      test('limits_to_top3_byDefault', () {
        tracker.recordToolUse('tool1');
        tracker.recordToolUse('tool2');
        tracker.recordToolUse('tool3');
        tracker.recordToolUse('tool4');
        tracker.recordToolUse('tool5');

        final prompt = tracker.toPromptContext();

        expect(prompt, isNot(contains('tool4')));
        expect(prompt, isNot(contains('tool5')));
      });
    });

    group('clear', () {
      test('removes_allUsage', () {
        tracker.recordToolUse('calculator');
        tracker.recordToolUse('timer');

        tracker.clear();

        expect(tracker.getCount('calculator'), 0);
        expect(tracker.getCount('timer'), 0);
        expect(tracker.getMostUsed(), isEmpty);
      });
    });

    group('totalUsage', () {
      test('returns_zero_initially', () {
        expect(tracker.totalUsage, 0);
      });

      test('returns_sum_of_all_uses', () {
        tracker.recordToolUse('calculator');
        tracker.recordToolUse('calculator');
        tracker.recordToolUse('timer');

        expect(tracker.totalUsage, 3);
      });
    });
  });
}
