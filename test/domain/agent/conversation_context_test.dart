import 'package:aios/domain/agent/conversation_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConversationContext', () {
    late ConversationContext context;

    setUp(() {
      context = ConversationContext();
    });

    group('addTurn', () {
      test('adds_singleTurn_stored', () {
        context.addTurn('Hello', 'Hi there!');

        expect(context.length, 1);
      });

      test('adds_multipleTurns_storedInOrder', () {
        context.addTurn('Q1', 'A1', toolUsed: 'calculator');
        context.addTurn('Q2', 'A2');
        context.addTurn('Q3', 'A3', toolUsed: 'app_launcher');

        expect(context.length, 3);
        final turns = context.getRecentTurns();
        expect(turns[0].userMessage, 'Q1');
        expect(turns[1].userMessage, 'Q2');
        expect(turns[2].userMessage, 'Q3');
      });

      test('respects_maxTurns_dropsOldest', () {
        context = ConversationContext(maxTurns: 3);

        context.addTurn('Q1', 'A1');
        context.addTurn('Q2', 'A2');
        context.addTurn('Q3', 'A3');
        context.addTurn('Q4', 'A4');
        context.addTurn('Q5', 'A5');

        expect(context.length, 3);
        final turns = context.getRecentTurns();
        expect(turns[0].userMessage, 'Q3');
        expect(turns[1].userMessage, 'Q4');
        expect(turns[2].userMessage, 'Q5');
      });
    });

    group('getRecentTurns', () {
      test('returns_empty_whenNoTurns', () {
        expect(context.getRecentTurns(), isEmpty);
      });

      test('returns_all_whenCountExceedsLength', () {
        context.addTurn('Q1', 'A1');
        context.addTurn('Q2', 'A2');

        final turns = context.getRecentTurns(10);

        expect(turns, hasLength(2));
      });

      test('returns_lastN_whenCountSpecified', () {
        context.addTurn('Q1', 'A1');
        context.addTurn('Q2', 'A2');
        context.addTurn('Q3', 'A3');
        context.addTurn('Q4', 'A4');

        final turns = context.getRecentTurns(2);

        expect(turns, hasLength(2));
        expect(turns[0].userMessage, 'Q3');
        expect(turns[1].userMessage, 'Q4');
      });
    });

    group('toPromptContext', () {
      test('returns_empty_whenNoTurns', () {
        expect(context.toPromptContext(), isEmpty);
      });

      test('formats_singleTurn', () {
        context.addTurn('What is 2+2?', '4', toolUsed: 'calculator');

        final prompt = context.toPromptContext();

        expect(prompt, contains('User: What is 2+2?'));
        expect(prompt, contains('Assistant: 4'));
      });

      test('formats_multipleTurns', () {
        context.addTurn('Q1', 'A1');
        context.addTurn('Q2', 'A2', toolUsed: 'timer');

        final prompt = context.toPromptContext();

        expect(prompt, contains('User: Q1'));
        expect(prompt, contains('Assistant: A1'));
        expect(prompt, contains('User: Q2'));
        expect(prompt, contains('Assistant: A2'));
      });

      test('truncates_longResponse', () {
        final longResponse = 'A' * 500;
        context = ConversationContext(maxResponseLength: 100);
        context.addTurn('Q', longResponse);

        final prompt = context.toPromptContext();

        expect(prompt, contains('...'));
        expect(prompt.length, lessThan(longResponse.length));
      });
    });

    group('isEmpty', () {
      test('true_initially', () {
        expect(context.isEmpty, isTrue);
      });

      test('false_afterAddTurn', () {
        context.addTurn('Q', 'A');

        expect(context.isEmpty, isFalse);
      });
    });

    group('clear', () {
      test('removes_allTurns', () {
        context.addTurn('Q1', 'A1');
        context.addTurn('Q2', 'A2');

        context.clear();

        expect(context.isEmpty, isTrue);
        expect(context.length, 0);
      });

      test('allows_new_turns_after_clear', () {
        context.addTurn('Old', 'Old response');
        context.clear();
        context.addTurn('New', 'New response');

        expect(context.length, 1);
        expect(context.getRecentTurns().first.userMessage, 'New');
      });
    });

    group('defaultMaxTurns', () {
      test('defaults_to_5', () {
        context = ConversationContext();
        for (var i = 0; i < 10; i++) {
          context.addTurn('Q$i', 'A$i');
        }

        expect(context.length, 5);
      });
    });

    group('ConversationTurn', () {
      test('stores_all_fields', () {
        const turn = ConversationTurn(
          userMessage: 'Hello',
          assistantResponse: 'Hi',
          toolUsed: 'app_launcher',
        );

        expect(turn.userMessage, 'Hello');
        expect(turn.assistantResponse, 'Hi');
        expect(turn.toolUsed, 'app_launcher');
      });

      test('toolUsed_canBeNull', () {
        const turn = ConversationTurn(
          userMessage: 'Hello',
          assistantResponse: 'Hi',
          toolUsed: null,
        );

        expect(turn.toolUsed, isNull);
      });
    });
  });
}
