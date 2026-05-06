import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/presentation/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _makeMessage({
  required String role,
  required String content,
  String? toolName,
  String? toolArgs,
  String? toolResult,
}) {
  return ChatMessage(
    id: '${role}_${content.hashCode}',
    role: role,
    content: content,
    createdAt: DateTime(2026, 1, 1),
    toolName: toolName,
    toolArgs: toolArgs,
    toolResult: toolResult,
  );
}

Widget _wrapWithMaterial(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFF9146FF),
        surface: const Color(0xFF18181B),
      ),
      scaffoldBackgroundColor: const Color(0xFF0E0E10),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('MessageBubble', () {
    testWidgets('user_message_showsWithPrimaryColor', (tester) async {
      final message = _makeMessage(role: 'user', content: 'Hello');

      await tester.pumpWidget(_wrapWithMaterial(MessageBubble(message: message)));

      expect(find.text('Hello'), findsOneWidget);
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('Hello'),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, const Color(0xFF9146FF));
    });

    testWidgets('assistant_message_showsWithSurfaceColor', (tester) async {
      final message = _makeMessage(role: 'assistant', content: 'Hi there');

      await tester.pumpWidget(_wrapWithMaterial(MessageBubble(message: message)));

      expect(find.text('Hi there'), findsOneWidget);
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('Hi there'),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, const Color(0xFF1F1F23));
    });

    testWidgets('messageWithToolInfo_showsToolDetails', (tester) async {
      final message = _makeMessage(
        role: 'assistant',
        content: 'Done',
        toolName: 'screen_action',
        toolArgs: '{"action": "click"}',
        toolResult: 'Success',
      );

      await tester.pumpWidget(_wrapWithMaterial(MessageBubble(message: message)));

      expect(find.text('Done'), findsOneWidget);
      expect(find.text('screen_action'), findsOneWidget);
      expect(find.text('{"action": "click"}'), findsOneWidget);
      expect(find.text('Success'), findsOneWidget);
    });

    testWidgets('emptyContent_showsNoText', (tester) async {
      final message = _makeMessage(role: 'user', content: '');

      await tester.pumpWidget(_wrapWithMaterial(MessageBubble(message: message)));

      final textWidgets = find.byType(Text);
      expect(textWidgets, findsNothing);
    });

    testWidgets('longText_wrapsCorrectly', (tester) async {
      final longText = 'A' * 500;
      final message = _makeMessage(role: 'assistant', content: longText);

      await tester.pumpWidget(_wrapWithMaterial(MessageBubble(message: message)));

      expect(find.text(longText), findsOneWidget);
      final text = tester.widget<Text>(find.text(longText));
      expect(text.maxLines, isNull);
    });
  });
}
