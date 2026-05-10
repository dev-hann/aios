import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/presentation/widgets/connection_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectionStatusBadge', () {
    Widget buildWidget({LlmProviderConfig? config, VoidCallback? onTap}) {
      return MaterialApp(
        home: Scaffold(
          body: ConnectionStatusBadge(config: config, onTap: onTap),
        ),
      );
    }

    testWidgets('build_withConfig_showsModelName', (tester) async {
      const config = LlmProviderConfig(
        type: LlmProviderType.zai,
        apiKey: 'key',
        model: 'glm-4.5-air',
        baseUrl: 'https://api.test.com',
      );

      await tester.pumpWidget(buildWidget(config: config));

      expect(find.text('glm-4.5-air'), findsOneWidget);
    });

    testWidgets('build_nullConfig_showsSettingsNeeded', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.text(Strings.chat.settingsNeeded), findsOneWidget);
    });

    testWidgets('build_withConfig_tapCallsCallback', (tester) async {
      var tapped = false;
      const config = LlmProviderConfig(
        type: LlmProviderType.zai,
        apiKey: 'key',
        model: 'test',
        baseUrl: 'https://api.test.com',
      );

      await tester.pumpWidget(
        buildWidget(config: config, onTap: () => tapped = true),
      );
      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue);
    });

    testWidgets('build_nullConfig_tapCallsCallback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(buildWidget(onTap: () => tapped = true));
      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue);
    });
  });
}
