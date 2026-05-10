import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/settings_notifier.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/screens/settings/inference_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/mock_llm_repository.dart';
import '../../../helpers/mock_settings_repository.dart';

Widget _createTestWidget() {
  final settingsRepo = MockSettingsRepository();
  final llmRepo = MockLlmRepository();

  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(settingsRepo),
      llmRepositoryProvider.overrideWithValue(llmRepo),
      settingsProvider.overrideWith(
        (ref) => SettingsNotifier(settingsRepo, llmRepo),
      ),
    ],
    child: const MaterialApp(home: InferenceSettingsScreen()),
  );
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -500));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('build_rendersTemperatureSlider', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.inference.temperature), findsOneWidget);
  });

  testWidgets('build_rendersTopPSlider', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.inference.topP), findsOneWidget);
  });

  testWidgets('build_rendersMaxTokensSlider', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.inference.maxTokens), findsOneWidget);
  });

  testWidgets('build_rendersMaxIterationsSlider', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();
    await _scrollToBottom(tester);

    expect(find.text(Strings.inference.maxIterations), findsOneWidget);
  });

  testWidgets('build_rendersResetDefaultsButton', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();
    await _scrollToBottom(tester);

    expect(find.text(Strings.inference.resetDefaults), findsOneWidget);
  });

  testWidgets('build_rendersSamplingSection', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.inference.sampling), findsOneWidget);
  });

  testWidgets('build_rendersOutputSection', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.inference.output), findsOneWidget);
  });

  testWidgets('build_rendersAgentSection', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();
    await _scrollToBottom(tester);

    expect(find.text(Strings.inference.agent), findsOneWidget);
  });

  testWidgets('build_displaysSliderWidgets', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsAtLeast(2));
  });

  testWidgets('build_hasAppBarTitle', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.inference.title), findsOneWidget);
  });

  testWidgets('resetDefaults_hasOnPressed', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();
    await _scrollToBottom(tester);

    final button = find.widgetWithText(
      OutlinedButton,
      Strings.inference.resetDefaults,
    );
    expect(button, findsOneWidget);

    final widget = tester.widget<OutlinedButton>(button);
    expect(widget.onPressed, isNotNull);
  });

  testWidgets('build_hasFourSliders_total', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();
    await _scrollToBottom(tester);

    expect(find.byType(Slider), findsNWidgets(4));
  });
}
