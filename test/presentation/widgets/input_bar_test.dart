import 'package:aios/presentation/widgets/input_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapWithMaterial(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFF6C63FF),
        surface: const Color(0xFF1A1A2E),
      ),
      scaffoldBackgroundColor: const Color(0xFF0D0D1A),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('InputBar', () {
    testWidgets('render_displaysTextFieldAndSendButton', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          InputBar(
            onSubmitted: (_) {},
            onStop: () {},
            isGenerating: false,
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('tapSend_callsOnSubmitted', (tester) async {
      String? submittedText;

      await tester.pumpWidget(
        _wrapWithMaterial(
          InputBar(
            onSubmitted: (text) => submittedText = text,
            onStop: () {},
            isGenerating: false,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Hello AIOS');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(submittedText, 'Hello AIOS');
    });

    testWidgets('render_generating_showsStopButton', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          InputBar(
            onSubmitted: (_) {},
            onStop: () {},
            isGenerating: true,
          ),
        ),
      );

      expect(find.byIcon(Icons.stop_circle), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);
    });

    testWidgets('render_generating_disablesInput', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          InputBar(
            onSubmitted: (_) {},
            onStop: () {},
            isGenerating: true,
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);
    });

    testWidgets('tapStop_callsOnStop', (tester) async {
      var stopCalled = false;

      await tester.pumpWidget(
        _wrapWithMaterial(
          InputBar(
            onSubmitted: (_) {},
            onStop: () => stopCalled = true,
            isGenerating: true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.stop_circle));
      await tester.pumpAndSettle();

      expect(stopCalled, isTrue);
    });

    testWidgets('submit_emptyText_doesNotCallOnSubmitted', (tester) async {
      var submitted = false;

      await tester.pumpWidget(
        _wrapWithMaterial(
          InputBar(
            onSubmitted: (_) => submitted = true,
            onStop: () {},
            isGenerating: false,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(submitted, isFalse);
    });

    testWidgets('submit_whitespaceOnly_doesNotCallOnSubmitted',
        (tester) async {
      var submitted = false;

      await tester.pumpWidget(
        _wrapWithMaterial(
          InputBar(
            onSubmitted: (_) => submitted = true,
            onStop: () {},
            isGenerating: false,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(submitted, isFalse);
    });

    testWidgets('submit_textIsTrimmed', (tester) async {
      String? submittedText;

      await tester.pumpWidget(
        _wrapWithMaterial(
          InputBar(
            onSubmitted: (text) => submittedText = text,
            onStop: () {},
            isGenerating: false,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '  Hello  ');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(submittedText, 'Hello');
    });

    testWidgets('submit_clearsTextField', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          InputBar(
            onSubmitted: (_) {},
            onStop: () {},
            isGenerating: false,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('render_notGenerating_showsHintText', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          InputBar(
            onSubmitted: (_) {},
            onStop: () {},
            isGenerating: false,
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.hintText, 'Type a message...');
    });

    testWidgets('render_generating_showsGeneratingHint', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          InputBar(
            onSubmitted: (_) {},
            onStop: () {},
            isGenerating: true,
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.hintText, 'Generating...');
    });

    testWidgets('render_textInputActionIsNewline', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          InputBar(
            onSubmitted: (_) {},
            onStop: () {},
            isGenerating: false,
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textInputAction, TextInputAction.newline);
    });

    testWidgets('render_multiline_maxLines', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          InputBar(
            onSubmitted: (_) {},
            onStop: () {},
            isGenerating: false,
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLines, 5);
      expect(textField.minLines, 1);
    });

    testWidgets('render_generating_onSubmittedIsNull', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          InputBar(
            onSubmitted: (_) {},
            onStop: () {},
            isGenerating: true,
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.onSubmitted, isNull);
    });
  });
}
