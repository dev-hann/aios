import '../../../helpers/mock_llm_repository.dart';
import '../../../helpers/mock_settings_repository.dart';
import '../../../helpers/mock_update_repository.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/settings_notifier.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/providers/update_provider.dart';
import 'package:aios/presentation/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _createTestWidget() {
  final settingsRepo = MockSettingsRepository();
  final llmRepo = MockLlmRepository();
  final updateRepo = MockUpdateRepository();

  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(settingsRepo),
      llmRepositoryProvider.overrideWithValue(llmRepo),
      settingsProvider.overrideWith(
        (ref) => SettingsNotifier(settingsRepo, llmRepo),
      ),
      updateRepositoryProvider.overrideWithValue(updateRepo),
      currentVersionProvider.overrideWithValue('1.0.0'),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/package_info'),
          (MethodCall methodCall) async => <String, dynamic>{
            'appName': 'AIOS',
            'packageName': 'com.aios.app',
            'version': '2.0.0',
            'buildNumber': '20000',
          },
        );
  });

  group('SettingsScreen', () {
    testWidgets('shows_inference_section', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('추론 설정'), findsOneWidget);
    });

    testWidgets('shows_permissions_section', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('권한 관리'), findsOneWidget);
    });

    testWidgets('shows_update_check_button', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('업데이트 확인'), findsOneWidget);
    });

    testWidgets('shows_version_info', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('버전'), findsOneWidget);
    });

    testWidgets('shows_github_link', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('GitHub'), findsOneWidget);
    });
  });

  group('SettingsScreen Check for Updates button', () {
    testWidgets('updateButton_hasOnPressedCallback', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      final updateButton = find.widgetWithText(OutlinedButton, '업데이트 확인');
      expect(updateButton, findsOneWidget);

      final button = tester.widget<OutlinedButton>(updateButton);
      expect(button.onPressed, isNotNull);
    });
  });

  group('SettingsScreen GitHub button', () {
    testWidgets('githubTile_hasOnTapCallback', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      final githubTile = find.ancestor(
        of: find.text('GitHub'),
        matching: find.byType(ListTile),
      );
      expect(githubTile, findsOneWidget);

      final tile = tester.widget<ListTile>(githubTile);
      expect(tile.onTap, isNotNull);
    });
  });
}
