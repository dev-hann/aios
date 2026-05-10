import 'package:aios/agent/tools/calculator_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CalculatorTool tool;

  setUp(() {
    tool = CalculatorTool();
  });

  group('execute_basicArithmetic', () {
    test('execute_addition_returnsCorrectResult', () async {
      final result = await tool.execute('{"expression": "2+3"}');
      expect(result.output, '5.0000');
    });

    test('execute_subtraction_returnsCorrectResult', () async {
      final result = await tool.execute('{"expression": "10-4"}');
      expect(result.output, '6.0000');
    });

    test('execute_multiplication_returnsCorrectResult', () async {
      final result = await tool.execute('{"expression": "3*7"}');
      expect(result.output, '21.0000');
    });

    test('execute_division_returnsCorrectResult', () async {
      final result = await tool.execute('{"expression": "10/4"}');
      expect(result.output, '2.5000');
    });
  });

  group('execute_operatorPrecedence', () {
    test('execute_multiplicationBeforeAddition_returnsCorrectResult', () async {
      final result = await tool.execute('{"expression": "2+3*4"}');
      expect(result.output, '14.0000');
    });

    test(
      'execute_parenthesesOverridePrecedence_returnsCorrectResult',
      () async {
        final result = await tool.execute('{"expression": "(2+3)*4"}');
        expect(result.output, '20.0000');
      },
    );
  });

  group('execute_decimalNumbers', () {
    test('execute_decimalArithmetic_returnsCorrectResult', () async {
      final result = await tool.execute('{"expression": "1.5+2.5"}');
      expect(result.output, '4.0000');
    });

    test('execute_decimalDivision_returnsCorrectResult', () async {
      final result = await tool.execute('{"expression": "7/2"}');
      expect(result.output, '3.5000');
    });
  });

  group('execute_complexExpressions', () {
    test('execute_nestedParentheses_returnsCorrectResult', () async {
      final result = await tool.execute('{"expression": "((2+3)*4-5)/3"}');
      expect(result.output, '5.0000');
    });

    test('execute_largeNumbers_returnsCorrectResult', () async {
      final result = await tool.execute('{"expression": "385*22"}');
      expect(result.output, '8470.0000');
    });

    test('execute_percentage_returnsCorrectResult', () async {
      final result = await tool.execute('{"expression": "200*0.15"}');
      expect(result.output, '30.0000');
    });
  });

  group('execute_errorHandling', () {
    test('execute_emptyExpression_returnsError', () async {
      final result = await tool.execute('{"expression": ""}');
      expect(result.toContent(), "Error: 'expression' required");
    });

    test('execute_missingExpressionKey_returnsError', () async {
      final result = await tool.execute('{}');
      expect(result.toContent(), "Error: 'expression' required");
    });

    test('execute_malformedJson_returnsError', () async {
      final result = await tool.execute('not json');
      expect(result.isError, isTrue);
    });

    test('execute_unsafeCharacters_sanitized', () async {
      final result = await tool.execute('{"expression": "2+3;import os"}');
      expect(result.output, '5.0000');
    });

    test('execute_divisionByZero_returnsInfinity', () async {
      final result = await tool.execute('{"expression": "1/0"}');
      expect(result.output, double.infinity.toStringAsFixed(4));
    });
  });

  group('name_andMetadata', () {
    test('name_returnsCalculator', () async {
      expect(tool.name, 'calculator');
    });

    test('description_isNotEmpty', () async {
      expect(tool.description.isNotEmpty, isTrue);
    });

    test('parameters_isNotEmpty', () async {
      expect(tool.parameters.isNotEmpty, isTrue);
    });

    test('toolPrompt_containsKoreanConversion', () async {
      expect(tool.toolPrompt, contains('곱하기'));
      expect(tool.toolPrompt, contains('나누기'));
    });

    test('toolPrompt_containsExpressionRules', () async {
      expect(tool.toolPrompt, contains('expression'));
    });
  });
}
