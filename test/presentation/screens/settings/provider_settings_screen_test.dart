import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/settings_notifier.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/screens/settings/provider_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/mock_llm_repository.dart';
import '../../../helpers/mock_settings_repository.dart';

Widget _createTestWidget({
  MockSettingsRepository? settingsRepo,
  MockLlmRepository? llmRepo,
}) {
  final sRepo = settingsRepo ?? MockSettingsRepository();
  final lRepo = llmRepo ?? MockLlmRepository();

  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(sRepo),
      llmRepositoryProvider.overrideWithValue(lRepo),
      settingsProvider.overrideWith((ref) => SettingsNotifier(sRepo, lRepo)),
    ],
    child: const MaterialApp(home: ProviderSettingsScreen()),
  );
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -500));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('build_rendersAppBarTitle', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.provider.title), findsOneWidget);
  });

  testWidgets('build_rendersProviderTypeSection', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.provider.selectProvider), findsOneWidget);
  });

  testWidgets('build_rendersApiKeyField', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.provider.apiKey), findsOneWidget);
  });

  testWidgets('build_rendersTestConnectionButton', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.provider.testConnection), findsOneWidget);
  });

  testWidgets('build_rendersModelSection', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();
    await _scrollToBottom(tester);

    expect(find.text(Strings.provider.model), findsOneWidget);
  });

  testWidgets('build_rendersSaveButton', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();
    await _scrollToBottom(tester);

    expect(find.text(Strings.provider.saveConnect), findsOneWidget);
  });

  testWidgets('build_rendersAllProviderTypes', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    for (final type in LlmProviderType.values) {
      expect(find.text(Strings.provider.nameForType(type)), findsOneWidget);
    }
  });

  testWidgets('build_hasApiKeyInput', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    expect(textFields, findsAtLeast(1));
  });

  testWidgets('build_displaysEnterApiKeyHint', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.provider.enterApiKey), findsOneWidget);
  });

  testWidgets('build_showsEnterApiKeyToLoad_forModels', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();
    await _scrollToBottom(tester);

    expect(find.text(Strings.provider.enterApiKeyToLoad), findsOneWidget);
  });

  testWidgets('save_showsError_whenApiKeyEmpty', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();
    await _scrollToBottom(tester);

    final saveButton = find.text(Strings.provider.saveConnect);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text(Strings.provider.requiredFields), findsOneWidget);
  });

  testWidgets('build_hasRefreshButton', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();
    await _scrollToBottom(tester);

    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('build_disconnectedState_noDisconnectButton', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();
    await _scrollToBottom(tester);

    expect(find.text(Strings.provider.disconnect), findsNothing);
  });

  testWidgets('build_testConnectionButton_hasCallback', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    final button = find.widgetWithText(
      OutlinedButton,
      Strings.provider.testConnection,
    );
    expect(button, findsOneWidget);

    final widget = tester.widget<OutlinedButton>(button);
    expect(widget.onPressed, isNotNull);
  });

  testWidgets('build_customType_showsBaseUrlField', (tester) async {
    final llmRepo = MockLlmRepository();
    llmRepo.modelsToReturn = [
      const LlmModelInfo(id: 'test-model', displayName: 'Test Model'),
    ];
    final settingsRepo = MockSettingsRepository(
      providerConfig: const LlmProviderConfig(
        type: LlmProviderType.custom,
        apiKey: 'test-key',
        model: 'test-model',
        baseUrl: 'https://api.example.com/v1',
      ).toJson(),
    );

    await tester.pumpWidget(
      _createTestWidget(settingsRepo: settingsRepo, llmRepo: llmRepo),
    );
    await tester.pumpAndSettle();

    expect(find.text(Strings.provider.baseUrl), findsOneWidget);
  });

  testWidgets('build_withProviderConfig_showsDisconnect', (tester) async {
    final llmRepo = MockLlmRepository();
    llmRepo.modelsToReturn = [
      const LlmModelInfo(id: 'test-model', displayName: 'Test Model'),
    ];
    final settingsRepo = MockSettingsRepository(
      providerConfig: const LlmProviderConfig(
        type: LlmProviderType.zai,
        apiKey: 'test-key',
        model: 'test-model',
      ).toJson(),
    );

    await tester.pumpWidget(
      _createTestWidget(settingsRepo: settingsRepo, llmRepo: llmRepo),
    );
    await tester.pumpAndSettle();
    await _scrollToBottom(tester);

    expect(find.text(Strings.provider.disconnect), findsOneWidget);
  });
}
