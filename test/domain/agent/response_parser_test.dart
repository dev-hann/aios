import 'package:aios/domain/agent/response_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ResponseParser parser;

  group('parseResponse_actionWithArgs', () {
    setUp(() {
      parser = ResponseParser({'calculator', 'screen_action'});
    });

    test('parse_actionWithJsonArgs_returnsAction', () {
      final result = parser.parse(
        'Action: calculator\nArgs: {"expression": "2+3"}',
      );
      expect(result, isA<ParseAction>());
      final action = result as ParseAction;
      expect(action.toolName, 'calculator');
      expect(action.args, contains('expression'));
      expect(action.args, contains('2+3'));
    });

    test('parse_actionWithoutArgs_returnsEmptyJsonArgs', () {
      final result = parser.parse('Action: calculator');
      expect(result, isA<ParseAction>());
      final action = result as ParseAction;
      expect(action.toolName, 'calculator');
      expect(action.args, '{}');
    });

    test('parse_answer_returnsAnswer', () {
      final result = parser.parse('Answer: The result is 42');
      expect(result, isA<ParseAnswer>());
      expect((result as ParseAnswer).text, 'The result is 42');
    });

    test('parse_plainText_returnsEmpty', () {
      final result =
          parser.parse('Just some random text without action or answer');
      expect(result, isA<ParseEmpty>());
    });

    test('parse_caseInsensitiveAction_returnsAction', () {
      final result = parser.parse('ACTION: calculator\nARGS: {"seconds": 5}');
      expect(result, isA<ParseAction>());
      expect((result as ParseAction).toolName, 'calculator');
    });

    test('parse_caseInsensitiveAnswer_returnsAnswer', () {
      final result = parser.parse('ANSWER: yes it works');
      expect(result, isA<ParseAnswer>());
      expect((result as ParseAnswer).text, 'yes it works');
    });

    test('parse_mixedCaseAction_returnsAction', () {
      final result = parser.parse('AcTiOn: calculator\nArGs: {}');
      expect(result, isA<ParseAction>());
      expect((result as ParseAction).toolName, 'calculator');
    });

    test('parse_multilineActionWithComplexArgs_returnsAction', () {
      final result = parser.parse(
        'Action: screen_action\nArgs: {"action": "tap", "x": 100, "y": 200}',
      );
      expect(result, isA<ParseAction>());
      final action = result as ParseAction;
      expect(action.toolName, 'screen_action');
      expect(action.args, contains('tap'));
      expect(action.args, contains('100'));
      expect(action.args, contains('200'));
    });

    test('parse_nestedJsonArgs_handlesBalancedBraces', () {
      final result = parser.parse(
        'Action: screen_action\nArgs: {"action": "type", "target": {"x": 100}}',
      );
      expect(result, isA<ParseAction>());
      final action = result as ParseAction;
      expect(action.args, endsWith('}}'));
      expect(action.args, contains('type'));
    });

    test('parse_whitespaceAroundColon_returnsAction', () {
      final result = parser
          .parse('Action :  calculator  \n Args : {"expression": "1+1"}');
      expect(result, isA<ParseAction>());
      final action = result as ParseAction;
      expect(action.toolName, 'calculator');
      expect(action.args, '{"expression": "1+1"}');
    });

    test('parse_emptyString_returnsEmpty', () {
      expect(parser.parse(''), isA<ParseEmpty>());
    });

    test('parse_whitespaceOnly_returnsEmpty', () {
      expect(parser.parse('   \n\t  '), isA<ParseEmpty>());
    });

    test('parse_multilineAnswer_returnsMultilineText', () {
      final result =
          parser.parse('Answer: First line\nSecond line\nThird line');
      expect(result, isA<ParseAnswer>());
      expect(
        (result as ParseAnswer).text,
        'First line\nSecond line\nThird line',
      );
    });

    test('parse_unknownToolName_returnsEmpty', () {
      final result =
          parser.parse('Action: nonexistent_tool\nArgs: {}');
      expect(result, isA<ParseEmpty>());
    });

    test('parse_veryLongResponse_returnsAnswer', () {
      final longText = 'A' * 10000;
      final result = parser.parse('Answer: $longText');
      expect(result, isA<ParseAnswer>());
      expect((result as ParseAnswer).text, longText);
    });

    test('parse_responseWithBothActionAndAnswer_actionWins', () {
      final result = parser.parse(
        'Action: calculator\nArgs: {}\nAnswer: never reached',
      );
      expect(result, isA<ParseAction>());
    });

    test('parse_actionWithUnicodeArgs_returnsAction', () {
      final result = parser.parse(
        'Action: calculator\nArgs: {"expression": "안녕"}',
      );
      expect(result, isA<ParseAction>());
      expect((result as ParseAction).args, contains('안녕'));
    });

    test('parse_answerWithSpecialCharacters_returnsAnswer', () {
      final result = parser.parse(
        'Answer: <script>alert("xss")</script>',
      );
      expect(result, isA<ParseAnswer>());
      expect((result as ParseAnswer).text, contains('<script>'));
    });

    test('parse_actionWithNewlinesBeforeArg_returnsAction', () {
      final result = parser.parse(
        'Action: calculator\n\nArgs: {"expression": "1+1"}',
      );
      expect(result, isA<ParseAction>());
    });

    test('parse_emptyToolNames_returnsEmpty', () {
      final emptyParser = ResponseParser({});
      final result = emptyParser.parse('Action: anything\nArgs: {}');
      expect(result, isA<ParseEmpty>());
    });

    test('parse_multipleActionLines_usesFirst', () {
      final result = parser.parse(
        'Action: calculator\nArgs: {"expression": "1"}\n'
        'Action: calculator\nArgs: {"expression": "2"}',
      );
      expect(result, isA<ParseAction>());
      expect((result as ParseAction).args, contains('1'));
    });
  });
}
