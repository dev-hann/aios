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
    testWidgets('showsTextFieldAndSendButton', (tester) async {
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

    testWidgets('tappingSend_callsOnSubmitted', (tester) async {
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

    testWidgets('showsStopButton_whenGenerating', (tester) async {
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

    testWidgets('disablesInput_whenGenerating', (tester) async {
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
  });
}
