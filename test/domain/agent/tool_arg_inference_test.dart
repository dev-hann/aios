import 'package:aios/domain/agent/tool_arg_inference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('inferToolArgs', () {
    group('calculator', () {
      test('calculator_mathExpression_returnsExpression', () {
        final result = inferToolArgs('calculator', 'calculate 2+3');
        expect(result, isNotNull);
        expect(result!['expression'], contains('+'));
      });

      test('calculator_whatIs_returnsExpression', () {
        final result = inferToolArgs('calculator', 'what is 5 times 3');
        expect(result, isNotNull);
        expect(result!['expression'], isNotEmpty);
      });

      test('calculator_noMath_returnsNull', () {
        final result = inferToolArgs('calculator', 'hello world');
        expect(result, isNull);
      });

      test('calculator_division_returnsExpression', () {
        final result = inferToolArgs('calculator', 'what is 10 divided by 2');
        expect(result, isNotNull);
        expect(result!['expression'], contains('/'));
      });

      test('calculator_subtraction_returnsExpression', () {
        final result = inferToolArgs('calculator', '100 minus 45');
        expect(result, isNotNull);
        expect(result!['expression'], contains('-'));
      });
    });

    group('notepad', () {
      test('notepad_writeAction_returnsWriteArgs', () {
        final result = inferToolArgs('notepad', 'write meeting notes');
        expect(result, isNotNull);
        expect(result!['action'], 'write');
        expect(result['content'], contains('meeting notes'));
        expect(result['key'], startsWith('note_'));
      });

      test('notepad_saveAction_returnsWriteArgs', () {
        final result = inferToolArgs('notepad', 'save my grocery list');
        expect(result, isNotNull);
        expect(result!['action'], 'write');
        expect(result['content'], contains('grocery list'));
      });

      test('notepad_recordAction_returnsWriteArgs', () {
        final result = inferToolArgs('notepad', 'record this idea');
        expect(result, isNotNull);
        expect(result!['action'], 'write');
      });

      test('notepad_noWriteKeyword_returnsList', () {
        final result = inferToolArgs('notepad', 'show my notes');
        expect(result, isNotNull);
        expect(result!['action'], 'list');
      });
    });

    group('timer', () {
      test('timer_seconds_returnsSetArgs', () {
        final result = inferToolArgs('timer', 'set timer for 30 seconds');
        expect(result, isNotNull);
        expect(result!['action'], 'set');
        expect(result['seconds'], 30);
      });

      test('timer_minutes_convertsToSeconds', () {
        final result = inferToolArgs('timer', '5 minute timer');
        expect(result, isNotNull);
        expect(result!['action'], 'set');
        expect(result['seconds'], 300);
      });

      test('timer_noDuration_returnsNull', () {
        final result = inferToolArgs('timer', 'set a timer');
        expect(result, isNull);
      });

      test('timer_secAbbreviation_returnsSeconds', () {
        final result = inferToolArgs('timer', '10 sec timer');
        expect(result, isNotNull);
        expect(result!['seconds'], 10);
      });
    });

    group('unknown tool', () {
      test('unknownTool_returnsNull', () {
        final result = inferToolArgs('screen_action', 'tap the button');
        expect(result, isNull);
      });

      test('emptyToolName_returnsNull', () {
        final result = inferToolArgs('', 'do something');
        expect(result, isNull);
      });
    });
  });

  group('extractMathExpr', () {
    test('plus_returnsExpression', () {
      final result = extractMathExpr('calculate 5 plus 3');
      expect(result, contains('+'));
    });

    test('minus_returnsExpression', () {
      final result = extractMathExpr('what is 10 minus 4');
      expect(result, contains('-'));
    });

    test('times_returnsExpression', () {
      final result = extractMathExpr('what is 6 times 7');
      expect(result, contains('*'));
    });

    test('dividedBy_returnsExpression', () {
      final result = extractMathExpr('calculate 20 divided by 5');
      expect(result, contains('/'));
    });

    test('over_returnsExpression', () {
      final result = extractMathExpr('what is 100 over 4');
      expect(result, contains('/'));
    });

    test('x_returnsExpression', () {
      final result = extractMathExpr('what is 5 x 3');
      expect(result, contains('*'));
    });

    test('computeKeyword_stripsPrefix', () {
      final result = extractMathExpr('compute 2+2');
      expect(result, isNotNull);
      expect(result, contains('+'));
    });

    test('noOperators_returnsNull', () {
      final result = extractMathExpr('just a number 42');
      expect(result, isNull);
    });

    test('noDigits_returnsNull', () {
      final result = extractMathExpr('hello world');
      expect(result, isNull);
    });

    test('subtractKeyword_returnsExpression', () {
      final result = extractMathExpr('subtract 5 from 20');
      expect(result, contains('-'));
    });

    test('addedTo_returnsExpression', () {
      final result = extractMathExpr('3 added to 7');
      expect(result, contains('+'));
    });

    test('multipliedBy_returnsExpression', () {
      final result = extractMathExpr('4 multiplied by 3');
      expect(result, contains('*'));
    });

    test('lessKeyword_returnsExpression', () {
      final result = extractMathExpr('10 less 3');
      expect(result, contains('-'));
    });

    test('andKeyword_returnsExpression', () {
      final result = extractMathExpr('2 and 3');
      expect(result, contains('+'));
    });

    test('parentheses_preserved', () {
      final result = extractMathExpr('calculate (2+3)*4');
      expect(result, isNotNull);
      expect(result, contains('('));
      expect(result, contains(')'));
    });
  });
}
