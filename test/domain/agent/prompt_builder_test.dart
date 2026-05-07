import 'package:aios/domain/agent/prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late PromptBuilder builder;

  setUp(() {
    builder = PromptBuilder();
  });

  group('buildRoutingPrompt', () {
    test('contains tool manifest', () {
      final prompt =
          builder.buildRoutingPrompt('- app_launcher: open apps');

      expect(prompt, contains('app_launcher'));
      expect(prompt, contains('open apps'));
      expect(prompt, contains('TOOLS:'));
    });

    test('contains format instructions', () {
      final prompt = builder.buildRoutingPrompt('');

      expect(prompt, contains('Action:'));
      expect(prompt, contains('Answer:'));
    });

    test('contains role description', () {
      final prompt = builder.buildRoutingPrompt('');

      expect(prompt, contains('AIOS'));
      expect(prompt, contains('AI assistant'));
    });

    test('contains rules', () {
      final prompt = builder.buildRoutingPrompt('');

      expect(prompt, contains('Max 5 tool calls'));
      expect(prompt, contains('Match user language'));
    });

    test('with empty manifest still contains structure', () {
      final prompt = builder.buildRoutingPrompt('');

      expect(prompt, contains('TOOLS:'));
      expect(prompt, contains('Rules:'));
    });

    test('with long manifest includes full text', () {
      final manifest =
          List.generate(50, (i) => '- tool$i: desc$i').join('\n');
      final prompt = builder.buildRoutingPrompt(manifest);

      expect(prompt, contains('tool0'));
      expect(prompt, contains('tool49'));
    });

    test('contains screen_action examples', () {
      final prompt = builder.buildRoutingPrompt('');

      expect(prompt, contains('screen_action'));
    });

    test('contains screen_reader examples', () {
      final prompt = builder.buildRoutingPrompt('');

      expect(prompt, contains('screen_reader'));
    });

    test('contains sms_sender examples', () {
      final prompt = builder.buildRoutingPrompt('');

      expect(prompt, contains('sms_sender'));
    });

    test('contains phone_caller examples', () {
      final prompt = builder.buildRoutingPrompt('');

      expect(prompt, contains('phone_caller'));
    });

    test('contains contact_search examples', () {
      final prompt = builder.buildRoutingPrompt('');

      expect(prompt, contains('contact_search'));
    });

    test('contains calculator examples', () {
      final prompt = builder.buildRoutingPrompt('');

      expect(prompt, contains('calculator'));
    });

    test('contains chaining examples', () {
      final prompt = builder.buildRoutingPrompt('');

      expect(prompt, contains('연락처에서'));
      expect(prompt, contains('찾아서'));
    });

    test('contains chaining rule', () {
      final prompt = builder.buildRoutingPrompt('');

      expect(
        prompt,
        contains('previous'),
      );
    });
  });

  group('buildToolPrompt', () {
    test('contains tool detail', () {
      final prompt = builder.buildToolPrompt(
        'app_launcher',
        'Open apps. Parameters: {action, package_name}',
      );

      expect(prompt, contains('app_launcher'));
      expect(prompt, contains('Open apps'));
      expect(prompt, contains('Parameters:'));
    });

    test('contains format instruction', () {
      final prompt = builder.buildToolPrompt('app_launcher', 'detail');

      expect(prompt, contains('Action: app_launcher'));
      expect(prompt, contains('Args:'));
    });

    test('without extra context has no app list', () {
      final prompt = builder.buildToolPrompt('app_launcher', 'detail');

      expect(prompt, isNot(contains('Installed apps')));
    });

    test('with extra context includes app list', () {
      final prompt = builder.buildToolPrompt(
        'app_launcher',
        'detail',
        extraContext: '1. YouTube (com.google.youtube)',
      );

      expect(prompt, contains('Installed apps'));
      expect(prompt, contains('YouTube'));
    });
  });

  group('addUserMessage', () {
    test('adds to history', () {
      builder.addUserMessage('Hello');

      final history = builder.getHistory();
      expect(history, hasLength(1));
      expect(history.first.role, 'user');
      expect(history.first.content, 'Hello');
    });

    test('multiple messages maintain order', () {
      builder.addUserMessage('First');
      builder.addUserMessage('Second');
      builder.addUserMessage('Third');

      final history = builder.getHistory();
      expect(history, hasLength(3));
      expect(history[0].content, 'First');
      expect(history[1].content, 'Second');
      expect(history[2].content, 'Third');
    });

    test('empty string adds to history', () {
      builder.addUserMessage('');

      final history = builder.getHistory();
      expect(history, hasLength(1));
      expect(history.first.content, isEmpty);
    });
  });

  group('addAssistantMessage', () {
    test('adds to history', () {
      builder.addAssistantMessage('Response');

      final history = builder.getHistory();
      expect(history, hasLength(1));
      expect(history.first.role, 'assistant');
      expect(history.first.content, 'Response');
    });

    test('interleaved with user', () {
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
    test('adds as user role', () {
      builder.addObservation('Screen text: Home');

      final history = builder.getHistory();
      expect(history, hasLength(1));
      expect(history.first.role, 'user');
      expect(history.first.content, 'Screen text: Home');
    });

    test('mixed with messages maintains order', () {
      builder.addUserMessage('Read screen');
      builder.addAssistantMessage('Action: screen_reader');
      builder.addObservation('Observation: Home Screen');

      final history = builder.getHistory();
      expect(history[2].role, 'user');
      expect(history[2].content, 'Observation: Home Screen');
    });
  });

  group('getHistory', () {
    test('empty returns empty list', () {
      expect(builder.getHistory(), isEmpty);
    });

    test('after messages returns all in order', () {
      builder.addUserMessage('Hello');
      builder.addAssistantMessage('Action: calculator');
      builder.addObservation('Observation: 42');

      final history = builder.getHistory();

      expect(history, hasLength(3));
      expect(history[0], (role: 'user', content: 'Hello'));
      expect(
          history[1], (role: 'assistant', content: 'Action: calculator'));
      expect(history[2], (role: 'user', content: 'Observation: 42'));
    });

    test('returns unmodifiable list', () {
      builder.addUserMessage('test');

      final history = builder.getHistory();

      expect(
          () => history.add((role: 'hacker', content: 'injected')),
          throwsA(isA<UnsupportedError>()));
    });
  });

  group('clearHistory', () {
    test('removes all entries', () {
      builder.addUserMessage('First');
      builder.addAssistantMessage('Second');
      builder.addObservation('Third');

      expect(builder.getHistory(), hasLength(3));

      builder.clearHistory();

      expect(builder.getHistory(), isEmpty);
    });

    test('allows new entries', () {
      builder.addUserMessage('Old');
      builder.clearHistory();
      builder.addUserMessage('New');

      final history = builder.getHistory();
      expect(history, hasLength(1));
      expect(history.first.content, 'New');
    });

    test('idempotent', () {
      builder.clearHistory();
      builder.clearHistory();

      expect(builder.getHistory(), isEmpty);
    });
  });

  group('buildRoutingPrompt with context', () {
    test('with conversationContext_includesHistory', () {
      final prompt = builder.buildRoutingPrompt(
        '- test: desc',
        conversationContext:
            'CONVERSATION HISTORY:\nUser: Hello\nAssistant: Hi',
      );

      expect(prompt, contains('CONVERSATION HISTORY'));
      expect(prompt, contains('User: Hello'));
      expect(prompt, contains('Assistant: Hi'));
    });

    test('with toolPreferences_includesPreferences', () {
      final prompt = builder.buildRoutingPrompt(
        '- test: desc',
        toolPreferences:
            'FREQUENTLY USED TOOLS:\n- calculator (5 uses)',
      );

      expect(prompt, contains('FREQUENTLY USED TOOLS'));
      expect(prompt, contains('calculator'));
    });

    test('with both_contextAndPreferences_includesBoth', () {
      final prompt = builder.buildRoutingPrompt(
        '- test: desc',
        conversationContext:
            'CONVERSATION HISTORY:\nUser: Q\nAssistant: A',
        toolPreferences:
            'FREQUENTLY USED TOOLS:\n- timer (3 uses)',
      );

      expect(prompt, contains('CONVERSATION HISTORY'));
      expect(prompt, contains('FREQUENTLY USED TOOLS'));
    });

    test('without_context_noExtraSections', () {
      final prompt = builder.buildRoutingPrompt('- test: desc');

      expect(prompt, isNot(contains('CONVERSATION HISTORY')));
      expect(prompt, isNot(contains('FREQUENTLY USED TOOLS')));
    });

    test('with empty_context_noExtraSections', () {
      final prompt = builder.buildRoutingPrompt(
        '- test: desc',
        conversationContext: '',
        toolPreferences: '',
      );

      expect(prompt, isNot(contains('CONVERSATION HISTORY')));
      expect(prompt, isNot(contains('FREQUENTLY USED TOOLS')));
    });

    test('context_appearsBefore_formatInstructions', () {
      final prompt = builder.buildRoutingPrompt(
        '- test: desc',
        conversationContext:
            'CONVERSATION HISTORY:\nUser: Q\nAssistant: A',
      );

      final contextIndex = prompt.indexOf('CONVERSATION HISTORY');
      final formatIndex =
          prompt.indexOf('You MUST respond');
      expect(contextIndex, lessThan(formatIndex));
    });
  });

  group('getConversationContext', () {
    test('empty returns empty', () {
      final context = builder.getConversationContext();

      expect(context, isEmpty);
    });

    test('formats single message', () {
      builder.addUserMessage('Hello');

      final context = builder.getConversationContext();

      expect(context, contains('user: Hello'));
    });

    test('formats multiple messages', () {
      builder.addUserMessage('Question');
      builder.addAssistantMessage('Answer');

      final context = builder.getConversationContext();

      expect(context, contains('user: Question'));
      expect(context, contains('assistant: Answer'));
    });

    test('preserves order', () {
      builder.addUserMessage('First');
      builder.addAssistantMessage('Second');

      final context = builder.getConversationContext();
      final firstIndex = context.indexOf('First');
      final secondIndex = context.indexOf('Second');

      expect(firstIndex, lessThan(secondIndex));
    });

    test('with long content', () {
      final longContent = 'A' * 10000;
      builder.addUserMessage(longContent);

      final context = builder.getConversationContext();

      expect(context, contains(longContent));
    });

    test('with multiline content', () {
      builder.addUserMessage('Line 1\nLine 2\nLine 3');

      final context = builder.getConversationContext();

      expect(context, contains('Line 1\nLine 2\nLine 3'));
    });
  });
}
