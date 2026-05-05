import 'package:aios/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ChatScreen', () {
    testWidgets(
      'shows welcome view and input on launch',
      (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.text('AIOS'), findsOneWidget);
        expect(find.text('Your on-device AI assistant'), findsOneWidget);
        expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.send), findsOneWidget);
      },
    );

    testWidgets(
      'shows idle status and settings button',
      (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.text('Idle'), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);
      },
    );

    testWidgets(
      'can type text in input field',
      (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 5));

        await tester.enterText(find.byType(TextField), 'Hello AIOS');
        await tester.pump();

        expect(find.text('Hello AIOS'), findsOneWidget);
      },
    );
  });

  group('SettingsScreen', () {
    Future<void> _navigateToSettings(WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    Future<void> _scrollTo(
      WidgetTester tester,
      Finder target,
    ) async {
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'shows settings header and model section',
      (tester) async {
        await _navigateToSettings(tester);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Model Management'), findsOneWidget);
        expect(find.text('No models found'), findsOneWidget);
        expect(find.text('Scan'), findsOneWidget);
        expect(find.text('Import'), findsOneWidget);
      },
    );

    testWidgets(
      'shows inference parameters and sliders',
      (tester) async {
        await _navigateToSettings(tester);
        expect(find.text('Inference Parameters'), findsOneWidget);
        expect(find.text('Context Size'), findsOneWidget);
        expect(find.text('Temperature'), findsOneWidget);
        expect(find.text('Max Tokens'), findsOneWidget);
        expect(find.text('Top-K'), findsOneWidget);
        expect(find.text('Top-P'), findsOneWidget);
        expect(find.text('Repeat Penalty'), findsOneWidget);
        expect(find.byType(Slider), findsAtLeast(6));
      },
    );

    testWidgets(
      'shows agent and app info sections after scroll',
      (tester) async {
        await _navigateToSettings(tester);

        await _scrollTo(tester, find.text('Agent Settings'));
        expect(find.text('Agent Settings'), findsOneWidget);
        expect(find.text('Max Iterations'), findsOneWidget);

        await _scrollTo(tester, find.text('App Info'));
        expect(find.text('App Info'), findsOneWidget);
        expect(find.text('Version'), findsOneWidget);
      },
    );

    testWidgets(
      'shows update check and about sections after scroll',
      (tester) async {
        await _navigateToSettings(tester);

        await _scrollTo(tester, find.text('Check for Updates'));
        expect(find.text('Check for Updates'), findsOneWidget);

        await _scrollTo(tester, find.text('About'));
        expect(find.text('About'), findsOneWidget);
        expect(find.text('GitHub'), findsOneWidget);
      },
    );

    testWidgets(
      'scan and import buttons work without crash',
      (tester) async {
        await _navigateToSettings(tester);

        await tester.tap(find.text('Scan'));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(find.text('Model Management'), findsOneWidget);

        await tester.tap(find.text('Import'));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(
          find.text('Model import not yet implemented'),
          findsOneWidget,
        );
      },
    );
  });

  group('Navigation', () {
    testWidgets(
      'settings has back button and returns to chat',
      (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 5));

        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.text('Settings'), findsOneWidget);
        expect(find.byType(BackButton), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('AIOS'), findsOneWidget);
      },
    );
  });
}
