import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:aios/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AIOS E2E', () {
    testWidgets('app launches and shows AIOS title', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      expect(find.text('AIOS'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
    });

    testWidgets('model picker bottom sheet opens', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.folder_open));
      await tester.pumpAndSettle();

      expect(find.text('Available Models'), findsOneWidget);
    });

    testWidgets('refresh button in sheet works', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.folder_open));
      await tester.pumpAndSettle();

      final refreshBtns = find.byIcon(Icons.refresh);
      expect(refreshBtns, findsWidgets);

      await tester.tap(refreshBtns.last);
      await tester.pumpAndSettle();

      expect(find.text('Available Models'), findsOneWidget);
    });

    testWidgets('send button disabled when no model loaded', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      expect(tester.widget<TextField>(textField).enabled, isFalse);
    });

    testWidgets('close model picker sheet', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.folder_open));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Available Models'), findsNothing);
    });
  });
}
