import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/presentation/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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

    testWidgets('assistant_message_rendersMarkdownBody', (tester) async {
      final message = _makeMessage(role: 'assistant', content: 'Hi there');

      await tester.pumpWidget(_wrapWithMaterial(MessageBubble(message: message)));

      expect(find.byType(MarkdownBody), findsOneWidget);
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

      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.text('screen_action'), findsOneWidget);
      expect(find.text('{"action": "click"}'), findsOneWidget);
      expect(find.text('Success'), findsOneWidget);
    });

    testWidgets('emptyContent_showsTimestampOnly', (tester) async {
      final message = _makeMessage(role: 'user', content: '');

      await tester.pumpWidget(_wrapWithMaterial(MessageBubble(message: message)));

      expect(find.byType(MarkdownBody), findsNothing);
      final timestampFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('1/1'),
      );
      expect(timestampFinder, findsOneWidget);
    });

    testWidgets('longText_rendersForAssistant', (tester) async {
      final longText = 'A' * 500;
      final message = _makeMessage(role: 'assistant', content: longText);

      await tester.pumpWidget(_wrapWithMaterial(MessageBubble(message: message)));

      expect(find.byType(MarkdownBody), findsOneWidget);
    });

    testWidgets('message_showsTimestamp', (tester) async {
      final message = _makeMessage(role: 'user', content: 'Hello');

      await tester.pumpWidget(_wrapWithMaterial(MessageBubble(message: message)));

      final timestampFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('1/1'),
      );
      expect(timestampFinder, findsOneWidget);
    });

    testWidgets('longPress_copiesToClipboard', (tester) async {
      final message = _makeMessage(role: 'user', content: 'Copy me');

      await tester.pumpWidget(_wrapWithMaterial(MessageBubble(message: message)));

      await tester.longPress(find.text('Copy me'));
      await tester.pumpAndSettle();

      expect(find.text('Copied to clipboard'), findsOneWidget);
    });

    testWidgets('assistantMessage_hasMarkdownBody', (tester) async {
      final message = _makeMessage(
        role: 'assistant',
        content: '# Title\n\n- item 1\n- item 2',
      );

      await tester.pumpWidget(_wrapWithMaterial(MessageBubble(message: message)));

      expect(find.byType(MarkdownBody), findsOneWidget);
    });

    testWidgets('userMessage_showsPlainText', (tester) async {
      final message = _makeMessage(role: 'user', content: 'Plain text');

      await tester.pumpWidget(_wrapWithMaterial(MessageBubble(message: message)));

      expect(find.text('Plain text'), findsOneWidget);
      expect(find.byType(MarkdownBody), findsNothing);
    });
  });
}
