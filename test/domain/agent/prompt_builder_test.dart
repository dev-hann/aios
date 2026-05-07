import 'package:aios/domain/agent/prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late PromptBuilder builder;

  setUp(() {
    builder = PromptBuilder();
  });

  group('buildSystemPrompt', () {
    test('buildSystemPrompt_containsToolManifest', () {
      final prompt = builder.buildSystemPrompt('- calculator: do math');

      expect(prompt, contains('calculator'));
      expect(prompt, contains('do math'));
      expect(prompt, contains('TOOLS:'));
    });

    test('buildSystemPrompt_containsFormatInstructions', () {
      final prompt = builder.buildSystemPrompt('');

      expect(prompt, contains('Action:'));
      expect(prompt, contains('Args:'));
      expect(prompt, contains('Answer:'));
    });

    test('buildSystemPrompt_containsMandatoryRules', () {
      final prompt = builder.buildSystemPrompt('');

      expect(prompt, contains('MANDATORY RULES'));
      expect(prompt, contains('list_apps before open_app'));
      expect(prompt, contains('NEVER guess'));
      expect(prompt, contains('Max 5 tool calls'));
    });

    test('buildSystemPrompt_containsRoleDescription', () {
      final prompt = builder.buildSystemPrompt('');

      expect(prompt, contains('AIOS'));
      expect(prompt, contains('AI assistant'));
    });

    test('buildSystemPrompt_withEmptyManifest_stillContainsStructure', () {
      final prompt = builder.buildSystemPrompt('');

      expect(prompt, contains('FORMAT:'));
      expect(prompt, contains('RULES'));
    });

    test('buildSystemPrompt_withLongManifest_includesFullText', () {
      final manifest = List.generate(50, (i) => '- tool$i: desc$i').join('\n');
      final prompt = builder.buildSystemPrompt(manifest);

      expect(prompt, contains('tool0'));
      expect(prompt, contains('tool49'));
    });
  });

  group('addUserMessage', () {
    test('addUserMessage_addsToHistory', () {
      builder.addUserMessage('Hello');

      final history = builder.getHistory();
      expect(history, hasLength(1));
      expect(history.first.role, 'user');
      expect(history.first.content, 'Hello');
    });

    test('addUserMessage_multipleMessages_maintainsOrder', () {
      builder.addUserMessage('First');
      builder.addUserMessage('Second');
      builder.addUserMessage('Third');

      final history = builder.getHistory();
      expect(history, hasLength(3));
      expect(history[0].content, 'First');
      expect(history[1].content, 'Second');
      expect(history[2].content, 'Third');
    });

    test('addUserMessage_emptyString_addsToHistory', () {
      builder.addUserMessage('');

      final history = builder.getHistory();
      expect(history, hasLength(1));
      expect(history.first.content, isEmpty);
    });
  });

  group('addAssistantMessage', () {
    test('addAssistantMessage_addsToHistory', () {
      builder.addAssistantMessage('Response');

      final history = builder.getHistory();
      expect(history, hasLength(1));
      expect(history.first.role, 'assistant');
      expect(history.first.content, 'Response');
    });

    test('addAssistantMessage_interleavedWithUser', () {
      builder.addUserMessage('Q1');
      builder.addAssistantMessage('A1');
      builder.addUserMessage('Q2');

      final history = builder.getHistory();
      expect(history, hasLength(3));
      expect(history[0], (role: 'user', content: 'Q1'));
      expect(history[1], (role: 'assistant', content: 'A1'));
      expect(history[2], (role: 'user', content: 'Q2'));
    });
  });

  group('addObservation', () {
    test('addObservation_addsAsUserRole', () {
      builder.addObservation('Screen text: Home');

      final history = builder.getHistory();
      expect(history, hasLength(1));
      expect(history.first.role, 'user');
      expect(history.first.content, 'Screen text: Home');
    });

    test('addObservation_mixedWithMessages_maintainsOrder', () {
      builder.addUserMessage('Read screen');
      builder.addAssistantMessage('Action: screen_reader');
      builder.addObservation('Observation: Home Screen');

      final history = builder.getHistory();
      expect(history[2].role, 'user');
      expect(history[2].content, 'Observation: Home Screen');
    });
  });

  group('getHistory', () {
    test('getHistory_empty_returnsEmptyList', () {
      expect(builder.getHistory(), isEmpty);
    });

    test('getHistory_afterMessages_returnsAllInOrder', () {
      builder.addUserMessage('Hello');
      builder.addAssistantMessage('Action: calculator');
      builder.addObservation('Observation: 42');

      final history = builder.getHistory();

      expect(history, hasLength(3));
      expect(history[0], (role: 'user', content: 'Hello'));
      expect(history[1], (role: 'assistant', content: 'Action: calculator'));
      expect(history[2], (role: 'user', content: 'Observation: 42'));
    });

    test('getHistory_returnsUnmodifiableList', () {
      builder.addUserMessage('test');

      final history = builder.getHistory();

      expect(() => history.add((role: 'hacker', content: 'injected')),
          throwsA(isA<UnsupportedError>()));
    });
  });

  group('clearHistory', () {
    test('clearHistory_removesAllEntries', () {
      builder.addUserMessage('First');
      builder.addAssistantMessage('Second');
      builder.addObservation('Third');

      expect(builder.getHistory(), hasLength(3));

      builder.clearHistory();

      expect(builder.getHistory(), isEmpty);
    });

    test('clearHistory_allowsNewEntries', () {
      builder.addUserMessage('Old');
      builder.clearHistory();
      builder.addUserMessage('New');

      final history = builder.getHistory();
      expect(history, hasLength(1));
      expect(history.first.content, 'New');
    });

    test('clearHistory_idempotent', () {
      builder.clearHistory();
      builder.clearHistory();

      expect(builder.getHistory(), isEmpty);
    });
  });

  group('getConversationContext', () {
    test('getConversationContext_empty_returnsEmpty', () {
      final context = builder.getConversationContext();

      expect(context, isEmpty);
    });

    test('getConversationContext_formatsSingleMessage', () {
      builder.addUserMessage('Hello');

      final context = builder.getConversationContext();

      expect(context, contains('user: Hello'));
    });

    test('getConversationContext_formatsMultipleMessages', () {
      builder.addUserMessage('Question');
      builder.addAssistantMessage('Answer');

      final context = builder.getConversationContext();

      expect(context, contains('user: Question'));
      expect(context, contains('assistant: Answer'));
    });

    test('getConversationContext_preservesOrder', () {
      builder.addUserMessage('First');
      builder.addAssistantMessage('Second');

      final context = builder.getConversationContext();
      final firstIndex = context.indexOf('First');
      final secondIndex = context.indexOf('Second');

      expect(firstIndex, lessThan(secondIndex));
    });

    test('getConversationContext_withLongContent', () {
      final longContent = 'A' * 10000;
      builder.addUserMessage(longContent);

      final context = builder.getConversationContext();

      expect(context, contains(longContent));
    });

    test('getConversationContext_withMultilineContent', () {
      builder.addUserMessage('Line 1\nLine 2\nLine 3');

      final context = builder.getConversationContext();

      expect(context, contains('Line 1\nLine 2\nLine 3'));
    });
  });
}
