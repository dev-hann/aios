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
      expect(find.text('AI 어시스턴트'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('shows settings in drawer', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
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
    Future<void> navigateToSettings(WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    Future<void> scrollTo(WidgetTester tester, Finder target) async {
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows settings header and model section', (tester) async {
      await navigateToSettings(tester);
      expect(find.text('설정'), findsOneWidget);
      expect(find.text('AI 제공자'), findsOneWidget);
      expect(find.text('AI 제공자가 설정되지 않았습니다'), findsOneWidget);
      expect(find.text('AI 설정하기'), findsOneWidget);
    });

    testWidgets('shows inference and permissions nav tiles', (tester) async {
      await navigateToSettings(tester);
      expect(find.text('추론 설정'), findsOneWidget);
      expect(find.text('권한 관리'), findsOneWidget);
    });

    testWidgets('shows app info section after scroll', (tester) async {
      await navigateToSettings(tester);

      await scrollTo(tester, find.text('앱 정보'));
      expect(find.text('앱 정보'), findsOneWidget);
      expect(find.text('버전'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
    });

    testWidgets('shows update check after scroll', (tester) async {
      await navigateToSettings(tester);

      await scrollTo(tester, find.text('업데이트 확인'));
      expect(find.text('업데이트 확인'), findsOneWidget);
    });

    testWidgets('add model button works without crash', (tester) async {
      await navigateToSettings(tester);

      await tester.tap(find.text('AI 설정하기'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  });

  group('Navigation', () {
    testWidgets('settings has back button and returns to chat', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('설정'), findsOneWidget);
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
