import 'package:aios/domain/agent/prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late PromptBuilder builder;

  setUp(() {
    builder = PromptBuilder();
  });

  group('buildIntentPrompt', () {
    test('buildIntentPrompt_containsManifest', () {
      final prompt = builder.buildIntentPrompt('- calculator: math\n- timer: time');
      expect(prompt, contains('calculator'));
      expect(prompt, contains('timer'));
    });

    test('buildIntentPrompt_containsTaskKeyword', () {
      final prompt = builder.buildIntentPrompt('tools');
      expect(prompt, contains('TASK'));
    });

    test('buildIntentPrompt_containsConversationKeyword', () {
      final prompt = builder.buildIntentPrompt('tools');
      expect(prompt, contains('CONVERSATION'));
    });

    test('buildIntentPrompt_containsReplyOnly', () {
      final prompt = builder.buildIntentPrompt('tools');
      expect(prompt, contains('Reply ONLY'));
    });
  });

  group('buildAnswerPrompt', () {
    test('buildAnswerPrompt_containsAIOS', () {
      final prompt = builder.buildAnswerPrompt();
      expect(prompt, contains('AIOS'));
    });

    test('buildAnswerPrompt_containsConcisely', () {
      final prompt = builder.buildAnswerPrompt();
      expect(prompt, contains('concisely'));
    });
  });

  group('buildRoutingPrompt', () {
    test('buildRoutingPrompt_containsManifest', () {
      final prompt = builder.buildRoutingPrompt('- calculator: math');
      expect(prompt, contains('calculator'));
    });

    test('buildRoutingPrompt_containsActionFormat', () {
      final prompt = builder.buildRoutingPrompt('tools');
      expect(prompt, contains('Action:'));
    });

    test('buildRoutingPrompt_containsAnswerFormat', () {
      final prompt = builder.buildRoutingPrompt('tools');
      expect(prompt, contains('Answer:'));
    });

    test('buildRoutingPrompt_withContext_includesContext', () {
      final prompt = builder.buildRoutingPrompt(
        'tools',
        conversationContext: 'Previous: user asked about weather',
      );
      expect(prompt, contains('Previous: user asked about weather'));
    });

    test('buildRoutingPrompt_withoutContext_noExtraSection', () {
      final prompt = builder.buildRoutingPrompt(
        'tools',
        conversationContext: null,
      );
      expect(prompt, contains('Respond ONLY'));
    });

    test('buildRoutingPrompt_withPreferences_includesPreferences', () {
      final prompt = builder.buildRoutingPrompt(
        'tools',
        toolPreferences: 'Frequently used: calculator',
      );
      expect(prompt, contains('Frequently used: calculator'));
    });

    test('buildRoutingPrompt_emptyContext_omitsSection', () {
      final prompt = builder.buildRoutingPrompt(
        'tools',
        conversationContext: '',
      );
      expect(prompt, contains('Respond ONLY'));
    });
  });

  group('buildToolPrompt', () {
    test('buildToolPrompt_containsToolPrompt', () {
      final prompt = builder.buildToolPrompt(
        'calculator',
        'Evaluate math expressions.',
      );
      expect(prompt, contains('Evaluate math expressions.'));
    });

    test('buildToolPrompt_containsJsonInstruction', () {
      final prompt = builder.buildToolPrompt('calculator', 'math tool');
      expect(prompt, contains('JSON only'));
    });

    test('buildToolPrompt_withExtraContext_includesContext', () {
      final prompt = builder.buildToolPrompt(
        'app_launcher',
        'Open apps',
        extraContext: 'YouTube, Firefox, Chrome',
      );
      expect(prompt, contains('Installed apps'));
      expect(prompt, contains('YouTube'));
    });

    test('buildToolPrompt_withoutExtraContext_noInstalledApps', () {
      final prompt = builder.buildToolPrompt('calculator', 'math tool');
      expect(prompt, isNot(contains('Installed apps')));
    });
  });

  group('history management', () {
    test('addUserMessage_historyContainsMessage', () {
      builder.addUserMessage('hello');
      final history = builder.getHistory();
      expect(history, hasLength(1));
      expect(history.first.role, equals('user'));
      expect(history.first.content, equals('hello'));
    });

    test('addAssistantMessage_historyContainsMessage', () {
      builder.addAssistantMessage('hi there');
      final history = builder.getHistory();
      expect(history, hasLength(1));
      expect(history.first.role, equals('assistant'));
      expect(history.first.content, equals('hi there'));
    });

    test('addObservation_addedAsUserRole', () {
      builder.addObservation('result: 42');
      final history = builder.getHistory();
      expect(history.first.role, equals('user'));
      expect(history.first.content, equals('result: 42'));
    });

    test('getHistory_multipleMessages_returnsAll', () {
      builder.addUserMessage('q1');
      builder.addAssistantMessage('a1');
      builder.addUserMessage('q2');
      expect(builder.getHistory(), hasLength(3));
    });

    test('clearHistory_emptiesHistory', () {
      builder.addUserMessage('hello');
      builder.addAssistantMessage('hi');
      builder.clearHistory();
      expect(builder.getHistory(), isEmpty);
    });

    test('getConversationContext_formatsCorrectly', () {
      builder.addUserMessage('what is 2+2?');
      builder.addAssistantMessage('4');
      final ctx = builder.getConversationContext();
      expect(ctx, contains('user: what is 2+2?'));
      expect(ctx, contains('assistant: 4'));
    });

    test('getHistory_returnsUnmodifiableList', () {
      builder.addUserMessage('hello');
      final history = builder.getHistory();
      expect(() => (history as List).add((role: 'x', content: 'y')),
          throwsA(anything));
    });
  });
}
