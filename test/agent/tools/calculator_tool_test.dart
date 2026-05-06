import 'package:aios/agent/tools/calculator_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CalculatorTool tool;

  setUp(() {
    tool = CalculatorTool();
  });

  group('execute_basicArithmetic', () {
    test('addition returns correct result', () {
      final result = tool.execute('{"expression": "2+3"}');
      expect(result, '5.0000');
    });

    test('subtraction returns correct result', () {
      final result = tool.execute('{"expression": "10-4"}');
      expect(result, '6.0000');
    });

    test('multiplication returns correct result', () {
      final result = tool.execute('{"expression": "3*7"}');
      expect(result, '21.0000');
    });

    test('division returns correct result', () {
      final result = tool.execute('{"expression": "10/4"}');
      expect(result, '2.5000');
    });
  });

  group('execute_operatorPrecedence', () {
    test('multiplication before addition', () {
      final result = tool.execute('{"expression": "2+3*4"}');
      expect(result, '14.0000');
    });

    test('parentheses override precedence', () {
      final result = tool.execute('{"expression": "(2+3)*4"}');
      expect(result, '20.0000');
    });
  });

  group('execute_decimalNumbers', () {
    test('decimal arithmetic works', () {
      final result = tool.execute('{"expression": "1.5+2.5"}');
      expect(result, '4.0000');
    });

    test('decimal division works', () {
      final result = tool.execute('{"expression": "7/2"}');
      expect(result, '3.5000');
    });
  });

  group('execute_errorHandling', () {
    test('empty expression returns error', () {
      final result = tool.execute('{"expression": ""}');
      expect(result, 'Error: empty expression');
    });

    test('missing expression key returns error', () {
      final result = tool.execute('{}');
      expect(result, 'Error: empty expression');
    });

    test('malformed JSON returns error', () {
      final result = tool.execute('not json');
      expect(result.startsWith('Error:'), isTrue);
    });

    test('unsafe characters are sanitized', () {
      final result =
          tool.execute('{"expression": "2+3;import os"}');
      expect(result, '5.0000');
    });

    test('division by zero returns infinity', () {
      final result = tool.execute('{"expression": "1/0"}');
      expect(result, double.infinity.toStringAsFixed(4));
    });
  });

  group('name_andMetadata', () {
    test('name is calculator', () {
      expect(tool.name, 'calculator');
    });

    test('description is not empty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });

    test('parameters is not empty', () {
      expect(tool.parameters.isNotEmpty, isTrue);
    });
  });
}
