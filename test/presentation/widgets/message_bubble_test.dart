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
    createdAt: DateTime(2026),
    toolName: toolName,
    toolArgs: toolArgs,
    toolResult: toolResult,
  );
}

Widget _wrapWithMaterial(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF9146FF),
        surface: Color(0xFF18181B),
      ),
      scaffoldBackgroundColor: const Color(0xFF0E0E10),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('MessageBubble', () {
    testWidgets('user_message_showsContent', (tester) async {
      final message = _makeMessage(role: 'user', content: 'Hello');

      await tester.pumpWidget(
        _wrapWithMaterial(MessageBubble(message: message)),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('user_message_hasBubbleColor', (tester) async {
      final message = _makeMessage(role: 'user', content: 'Hello');

      await tester.pumpWidget(
        _wrapWithMaterial(MessageBubble(message: message)),
      );

      final container = tester.widget<Container>(
        find.ancestor(of: find.text('Hello'), matching: find.byType(Container)),
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, const Color(0xFF9146FF));
    });

    testWidgets('assistant_message_showsContent', (tester) async {
      final message = _makeMessage(role: 'assistant', content: 'Hi there');

      await tester.pumpWidget(
        _wrapWithMaterial(MessageBubble(message: message)),
      );

      expect(find.text('Hi there'), findsOneWidget);
    });

    testWidgets('assistant_message_noMarkdown', (tester) async {
      final message = _makeMessage(role: 'assistant', content: 'No markdown');

      await tester.pumpWidget(
        _wrapWithMaterial(MessageBubble(message: message)),
      );

      expect(find.byType(Text), findsWidgets);
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final hasMarkdownBody = textWidgets.any(
        (t) => t.data?.contains('MarkdownBody') ?? false,
      );
      expect(hasMarkdownBody, isFalse);
    });

    testWidgets('messageWithToolInfo_showsToolDetails', (tester) async {
      final message = _makeMessage(
        role: 'assistant',
        content: 'Done',
        toolName: 'screen_action',
        toolArgs: '{"action": "click"}',
        toolResult: 'Success',
      );

      await tester.pumpWidget(
        _wrapWithMaterial(MessageBubble(message: message)),
      );

      expect(find.text('screen_action'), findsOneWidget);
      expect(find.text('{"action": "click"}'), findsOneWidget);
      expect(find.text('Success'), findsOneWidget);
    });

    testWidgets('messageWithToolInfo_noArgsResult', (tester) async {
      final message = _makeMessage(
        role: 'assistant',
        content: 'Done',
        toolName: 'calculator',
      );

      await tester.pumpWidget(
        _wrapWithMaterial(MessageBubble(message: message)),
      );

      expect(find.text('calculator'), findsOneWidget);
    });

    testWidgets('emptyContent_assistant_stillRenders', (tester) async {
      final message = _makeMessage(role: 'assistant', content: '');

      await tester.pumpWidget(
        _wrapWithMaterial(MessageBubble(message: message)),
      );

      expect(find.byType(MessageBubble), findsOneWidget);
    });

    testWidgets('message_showsTimestamp', (tester) async {
      final message = _makeMessage(role: 'assistant', content: 'Hello');

      await tester.pumpWidget(
        _wrapWithMaterial(MessageBubble(message: message)),
      );

      final timestampFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('00:00'),
      );
      expect(timestampFinder, findsOneWidget);
    });

    testWidgets('longText_rendersForAssistant', (tester) async {
      final longText = 'A' * 500;
      final message = _makeMessage(role: 'assistant', content: longText);

      await tester.pumpWidget(
        _wrapWithMaterial(MessageBubble(message: message)),
      );

      expect(find.text(longText), findsOneWidget);
    });
  });
}
