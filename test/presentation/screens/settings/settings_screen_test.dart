import 'dart:async';

import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/entities/update_info.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:aios/domain/repositories/update_repository.dart';
import '../../../helpers/mock_llm_repository.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/settings_notifier.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/providers/update_notifier.dart';
import 'package:aios/presentation/providers/update_provider.dart';
import 'package:aios/presentation/providers/update_state.dart';
import 'package:aios/presentation/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockSettingsRepository implements SettingsRepository {
  double _temperature = SettingsRepository.defaultTemperature;
  int _maxTokens = SettingsRepository.defaultMaxTokens;
  double _topP = SettingsRepository.defaultTopP;
  int _agentMaxIterations = SettingsRepository.defaultAgentMaxIterations;
  String? _providerConfig;
  bool _onboardingCompleted = false;

  @override
  double get temperature => _temperature;
  @override
  int get maxTokens => _maxTokens;
  @override
  double get topP => _topP;
  @override
  int get agentMaxIterations => _agentMaxIterations;
  @override
  String? get providerConfig => _providerConfig;
  @override
  bool get onboardingCompleted => _onboardingCompleted;

  @override
  Future<void> setTemperature(double value) async => _temperature = value;
  @override
  Future<void> setMaxTokens(int value) async => _maxTokens = value;
  @override
  Future<void> setTopP(double value) async => _topP = value;
  @override
  Future<void> setAgentMaxIterations(int value) async =>
      _agentMaxIterations = value;
  @override
  Future<void> setProviderConfig(String json) async => _providerConfig = json;
  @override
  Future<void> clearProviderConfig() async => _providerConfig = null;
  @override
  Future<void> setOnboardingCompleted() async => _onboardingCompleted = true;
}

typedef _MockLlmRepository = MockLlmRepository;

class _MockUpdateRepository implements UpdateRepository {
  @override
  Future<UpdateResult> checkForUpdate() async {
    return const UpdateResult.notAvailable();
  }

  @override
  Future<String?> downloadApk(
    String url,
    String fileName, {
    void Function(double)? onProgress,
  }) async {
    return '/tmp/fake.apk';
  }

  @override
  Future<bool> installApk(String apkPath) async => true;
}

Widget _createTestWidget() {
  final settingsRepo = _MockSettingsRepository();
  final llmRepo = _MockLlmRepository();
  final updateRepo = _MockUpdateRepository();

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
