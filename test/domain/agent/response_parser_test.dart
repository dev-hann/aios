import 'package:aios/domain/agent/response_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ResponseParser parser;

  setUp(() {
    parser = ResponseParser({'calculator', 'app_launcher', 'screen_action'});
  });

  group('parseIntent', () {
    test('parseIntent_conversation_returnsIsConversationTrue', () {
      final result = parser.parseIntent('CONVERSATION');
      expect(result, isA<ParseIntent>());
      expect((result as ParseIntent).isConversation, isTrue);
    });

    test('parseIntent_task_returnsIsConversationFalse', () {
      final result = parser.parseIntent('TASK');
      expect(result, isA<ParseIntent>());
      expect((result as ParseIntent).isConversation, isFalse);
    });

    test('parseIntent_lowercase_conversationDetected', () {
      final result = parser.parseIntent('conversation');
      expect((result as ParseIntent).isConversation, isTrue);
    });

    test('parseIntent_mixedCase_taskDetected', () {
      final result = parser.parseIntent('Task');
      expect((result as ParseIntent).isConversation, isFalse);
    });

    test('parseIntent_embeddedInSentence_conversationDetected', () {
      final result = parser.parseIntent('This is a conversation request');
      expect((result as ParseIntent).isConversation, isTrue);
    });

    test('parseIntent_embeddedInSentence_taskDetected', () {
      final result = parser.parseIntent('This is a task request');
      expect((result as ParseIntent).isConversation, isFalse);
    });

    test('parseIntent_empty_defaultsToTask', () {
      final result = parser.parseIntent('');
      expect((result as ParseIntent).isConversation, isFalse);
    });

    test('parseIntent_whitespace_defaultsToTask', () {
      final result = parser.parseIntent('   ');
      expect((result as ParseIntent).isConversation, isFalse);
    });

    test('parseIntent_unknownWord_defaultsToTask', () {
      final result = parser.parseIntent('something else');
      expect((result as ParseIntent).isConversation, isFalse);
    });

    test('parseIntent_conversationPrioritizedOverTask', () {
      final result =
          parser.parseIntent('This is a conversation about a task');
      expect((result as ParseIntent).isConversation, isTrue);
    });
  });

  group('parse', () {
    test('parse_actionWithValidTool_returnsParseAction', () {
      final result = parser.parse('Action: calculator');
      expect(result, isA<ParseAction>());
      expect((result as ParseAction).toolName, equals('calculator'));
    });

    test('parse_actionWithArgs_returnsArgs', () {
      final result = parser.parse('Action: calculator\nArgs: {"expression": "2+2"}');
      expect(result, isA<ParseAction>());
      final action = result as ParseAction;
      expect(action.toolName, equals('calculator'));
      expect(action.args, contains('expression'));
    });

    test('parse_actionWithInlineJson_extractsArgs', () {
      final result =
          parser.parse('Action: app_launcher {"target": "youtube"}');
      expect(result, isA<ParseAction>());
      final action = result as ParseAction;
      expect(action.toolName, equals('app_launcher'));
      expect(action.args, contains('target'));
    });

    test('parse_answer_returnsParseAnswer', () {
      final result = parser.parse('Answer: Hello! How can I help?');
      expect(result, isA<ParseAnswer>());
      expect((result as ParseAnswer).text, equals('Hello! How can I help?'));
    });

    test('parse_empty_returnsParseEmpty', () {
      final result = parser.parse('');
      expect(result, isA<ParseEmpty>());
    });

    test('parse_whitespaceOnly_returnsParseEmpty', () {
      final result = parser.parse('   ');
      expect(result, isA<ParseEmpty>());
    });

    test('parse_gibberish_returnsParseEmpty', () {
      final result = parser.parse('asdfghjkl');
      expect(result, isA<ParseEmpty>());
    });

    test('parse_caseInsensitiveAction_parsed', () {
      final result = parser.parse('action: CALCULATOR');
      expect(result, isA<ParseAction>());
      expect((result as ParseAction).toolName, equals('calculator'));
    });

    test('parse_caseInsensitiveAnswer_parsed', () {
      final result = parser.parse('answer: Some response');
      expect(result, isA<ParseAnswer>());
    });

    test('parse_actionWithUnknownTool_returnsParseEmpty', () {
      final result = parser.parse('Action: unknown_tool');
      expect(result, isA<ParseEmpty>());
    });

    test('parse_answerBeforeAction_actionTakesPriority', () {
      final result =
          parser.parse('Answer: hi\nAction: calculator');
      expect(result, isA<ParseAction>());
    });

    test('parse_nestedJson_extractsCorrectly', () {
      final result = parser.parse(
        'Action: app_launcher {"target": "youtube", "data": {"key": "val"}}',
      );
      expect(result, isA<ParseAction>());
      final action = result as ParseAction;
      expect(action.args, contains('target'));
      expect(action.args, contains('data'));
    });

    test('parse_escapedQuotesInJson_handled', () {
      final result = parser.parse(
        'Action: app_launcher {"target": "hello \\"world\\""}',
      );
      expect(result, isA<ParseAction>());
    });
  });

  group('_extractJsonArgs', () {
    test('parse_simpleJson_extractsFullObject', () {
      final result = parser.parse(
        'Action: calculator {"expression": "2+3"}',
      );
      expect(result, isA<ParseAction>());
      expect((result as ParseAction).args, equals('{"expression": "2+3"}'));
    });

    test('parse_incompleteJson_returnsPartial', () {
      final result = parser.parse(
        'Action: calculator {"expression": "2+3"',
      );
      expect(result, isA<ParseAction>());
      expect((result as ParseAction).args, contains('expression'));
    });

    test('parse_emptyJsonObject_extractsBraces', () {
      final result = parser.parse('Action: calculator {}');
      expect(result, isA<ParseAction>());
      expect((result as ParseAction).args, equals('{}'));
    });

    test('parse_jsonWithBracesInString_handled', () {
      final result = parser.parse(
        'Action: app_launcher {"target": "a{b}c"}',
      );
      expect(result, isA<ParseAction>());
    });
  });
}
