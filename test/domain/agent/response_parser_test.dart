import 'package:aios/domain/agent/response_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ResponseParser parser;

  group('parseResponse_actionWithArgs', () {
    setUp(() {
      parser = ResponseParser({'calculator', 'screen_action'});
    });

    test('action with JSON args', () {
      final result = parser.parse(
        'Action: calculator\nArgs: {"expression": "2+3"}',
      );
      expect(result, isA<ParseAction>());
      final action = result as ParseAction;
      expect(action.toolName, 'calculator');
      expect(action.args, contains('expression'));
      expect(action.args, contains('2+3'));
    });

    test('action without args returns default empty json', () {
      final result = parser.parse('Action: calculator');
      expect(result, isA<ParseAction>());
      final action = result as ParseAction;
      expect(action.toolName, 'calculator');
      expect(action.args, '{}');
    });

    test('answer', () {
      final result = parser.parse('Answer: The result is 42');
      expect(result, isA<ParseAnswer>());
      expect((result as ParseAnswer).text, 'The result is 42');
    });

    test('plain text returns empty', () {
      final result =
          parser.parse('Just some random text without action or answer');
      expect(result, isA<ParseEmpty>());
    });

    test('case insensitive action', () {
      final result = parser.parse('ACTION: calculator\nARGS: {"seconds": 5}');
      expect(result, isA<ParseAction>());
      expect((result as ParseAction).toolName, 'calculator');
    });

    test('case insensitive answer', () {
      final result = parser.parse('ANSWER: yes it works');
      expect(result, isA<ParseAnswer>());
      expect((result as ParseAnswer).text, 'yes it works');
    });

    test('mixed case action', () {
      final result = parser.parse('AcTiOn: calculator\nArGs: {}');
      expect(result, isA<ParseAction>());
      expect((result as ParseAction).toolName, 'calculator');
    });

    test('multiline action with complex json args', () {
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

    test('nested json in args handles balanced braces', () {
      final result = parser.parse(
        'Action: screen_action\nArgs: {"action": "type", "target": {"x": 100}}',
      );
      expect(result, isA<ParseAction>());
      final action = result as ParseAction;
      expect(action.args, endsWith('}}'));
      expect(action.args, contains('type'));
    });

    test('whitespace around colon', () {
      final result = parser
          .parse('Action :  calculator  \n Args : {"expression": "1+1"}');
      expect(result, isA<ParseAction>());
      final action = result as ParseAction;
      expect(action.toolName, 'calculator');
      expect(action.args, '{"expression": "1+1"}');
    });

    test('empty string returns empty', () {
      expect(parser.parse(''), isA<ParseEmpty>());
    });

    test('whitespace only returns empty', () {
      expect(parser.parse('   \n\t  '), isA<ParseEmpty>());
    });

    test('answer with multiline content', () {
      final result =
          parser.parse('Answer: First line\nSecond line\nThird line');
      expect(result, isA<ParseAnswer>());
      expect(
        (result as ParseAnswer).text,
        'First line\nSecond line\nThird line',
      );
    });

    test('unknown tool name returns empty', () {
      final result =
          parser.parse('Action: nonexistent_tool\nArgs: {}');
      expect(result, isA<ParseEmpty>());
    });
  });
}
