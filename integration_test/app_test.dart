import 'package:aios/main.dart' as app;
import 'package:aios/presentation/providers/chat_providers.dart';
import 'package:aios/presentation/screens/chat/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ChatScreen', () {
    testWidgets('shows welcome view and input on launch', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('AIOS'), findsOneWidget);
      expect(find.text('Your on-device AI assistant'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('shows settings button in app bar', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('can type text in input field', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.enterText(find.byType(TextField), 'Hello AIOS');
      await tester.pump();

      expect(find.text('Hello AIOS'), findsOneWidget);
    });
  });

  group('SettingsScreen', () {
    Future<void> _navigateToSettings(WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    Future<void> _scrollTo(WidgetTester tester, Finder target) async {
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows settings header and model section', (tester) async {
      await _navigateToSettings(tester);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Provider'), findsOneWidget);
      expect(find.text('No provider configured'), findsOneWidget);
      expect(find.text('Setup Provider'), findsOneWidget);
    });

    testWidgets('shows inference and permissions nav tiles', (tester) async {
      await _navigateToSettings(tester);
      expect(find.text('Inference'), findsOneWidget);
      expect(find.text('Permissions'), findsOneWidget);
    });

    testWidgets('shows app info section after scroll', (tester) async {
      await _navigateToSettings(tester);

      await _scrollTo(tester, find.text('App Info'));
      expect(find.text('App Info'), findsOneWidget);
      expect(find.text('Version'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
    });

    testWidgets('shows update check after scroll', (tester) async {
      await _navigateToSettings(tester);

      await _scrollTo(tester, find.text('Check for Updates'));
      expect(find.text('Check for Updates'), findsOneWidget);
    });

    testWidgets('add model button works without crash', (tester) async {
      await _navigateToSettings(tester);

      await tester.tap(find.text('Setup Provider'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  });

  group('Navigation', () {
    testWidgets('settings has back button and returns to chat', (tester) async {
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
    });
  });

  group('ChatScreen UI', () {
    testWidgets('shows menu and new chat buttons in app bar', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byIcon(Icons.add_comment_outlined), findsOneWidget);
    });

    testWidgets('does not show error bar initially', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('shows error bar when errorMessage is set via provider', (
      tester,
    ) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final element = tester.element(find.byType(ChatScreen));
      final container = ProviderScope.containerOf(element);
      container.read(chatStateProvider.notifier).state = container
          .read(chatStateProvider)
          .copyWith(errorMessage: 'Test error message');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
