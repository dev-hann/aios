import 'package:aios/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ChatScreen semantics smoke', () {
    testWidgets('render_hasCoreSemanticsLabels', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.bySemanticsLabel('drawer_open_menu'), findsOneWidget);
      expect(find.bySemanticsLabel('new_conversation_button'), findsOneWidget);
      expect(find.bySemanticsLabel('chat_input_textfield'), findsOneWidget);
      expect(find.bySemanticsLabel('chat_send_button'), findsOneWidget);
    });

    testWidgets('drawer_opensWithSemanticsLabels', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.bySemanticsLabel('drawer_open_menu'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.bySemanticsLabel('drawer_settings_tile'), findsOneWidget);
    });

    testWidgets('input_acceptsText', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.enterText(
        find.bySemanticsLabel('chat_input_textfield'),
        'hello integration',
      );
      await tester.pump();

      expect(find.text('hello integration'), findsOneWidget);
    });
  });

  group('SettingsScreen semantics smoke', () {
    Future<void> navigateToSettings(WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.tap(find.bySemanticsLabel('drawer_open_menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('drawer_settings_tile'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    testWidgets('render_hasSettingsSemanticsLabels', (tester) async {
      await navigateToSettings(tester);

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'provider_settings_button',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('settings_inference_tile'), findsOneWidget);
      expect(
        find.bySemanticsLabel('settings_permissions_tile'),
        findsOneWidget,
      );
    });
  });
}
