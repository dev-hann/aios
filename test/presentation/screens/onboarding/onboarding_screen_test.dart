import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/model_info.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/domain/repositories/model_repository.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/model_provider.dart';
import 'package:aios/presentation/providers/settings_notifier.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:async';

class _MockSettingsRepository implements SettingsRepository {
  double _temperature = SettingsRepository.defaultTemperature;
  int _contextSize = SettingsRepository.defaultContextSize;
  int _maxTokens = SettingsRepository.defaultMaxTokens;
  int _topK = SettingsRepository.defaultTopK;
  double _topP = SettingsRepository.defaultTopP;
  double _repeatPenalty = SettingsRepository.defaultRepeatPenalty;
  int _agentMaxIterations = SettingsRepository.defaultAgentMaxIterations;
  String? _lastModelPath;
  String _themeMode = 'dark';
  bool _onboardingCompleted = false;

  @override
  double get temperature => _temperature;
  @override
  int get contextSize => _contextSize;
  @override
  int get maxTokens => _maxTokens;
  @override
  int get topK => _topK;
  @override
  double get topP => _topP;
  @override
  double get repeatPenalty => _repeatPenalty;
  @override
  int get agentMaxIterations => _agentMaxIterations;
  @override
  String? get lastModelPath => _lastModelPath;
  @override
  String get themeMode => _themeMode;
  @override
  bool get onboardingCompleted => _onboardingCompleted;

  @override
  Future<void> setTemperature(double value) async => _temperature = value;
  @override
  Future<void> setContextSize(int value) async => _contextSize = value;
  @override
  Future<void> setMaxTokens(int value) async => _maxTokens = value;
  @override
  Future<void> setTopK(int value) async => _topK = value;
  @override
  Future<void> setTopP(double value) async => _topP = value;
  @override
  Future<void> setRepeatPenalty(double value) async =>
      _repeatPenalty = value;
  @override
  Future<void> setAgentMaxIterations(int value) async =>
      _agentMaxIterations = value;
  @override
  Future<void> setLastModelPath(String path) async => _lastModelPath = path;
  @override
  Future<void> clearLastModelPath() async => _lastModelPath = null;
  @override
  Future<void> setThemeMode(String mode) async => _themeMode = mode;
  @override
  Future<void> setOnboardingCompleted() async =>
      _onboardingCompleted = true;
}

class _MockLlmRepository implements LlmRepository {
  final _stateController = StreamController<ServiceState>.broadcast();

  @override
  Stream<ServiceState> get state => _stateController.stream;

  @override
  Stream<String> get tokenStream => const Stream.empty();

  @override
  Stream<double> get loadProgress => const Stream.empty();

  @override
  Future<bool> loadModel(String path, {int? contextSize}) async => true;

  @override
  Future<void> releaseModel() async {}

  @override
  bool get isModelLoaded => false;

  @override
  String getModelInfo() => '';

  @override
  String getContextUsage() => '';

  @override
  Future<void> resetContext() async {}

  @override
  Future<void> sendMessage(
    List<ChatMessage> history, {
    required String userMessage,
    double? temperature,
    int? maxTokens,
    int? topK,
    double? topP,
    double? repeatPenalty,
  }) async {}

  @override
  Future<void> stopGeneration() async {}

  @override
  Future<void> saveSession(String path) async {}

  @override
  Future<void> loadSession(String path) async {}
}

class _MockModelRepository implements ModelRepository {
  @override
  List<ModelInfo> scanModels() => [];

  @override
  List<ModelInfo> scanExternalDirs() => [];

  @override
  bool restoreModel(String name) => false;

  @override
  Future<bool> importModelFromUri(
    String sourcePath,
    String fileName,
  ) async =>
      false;
}

Widget _createTestWidget() {
  final settingsRepo = _MockSettingsRepository();
  final llmRepo = _MockLlmRepository();
  final modelRepo = _MockModelRepository();

  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(settingsRepo),
      llmRepositoryProvider.overrideWithValue(llmRepo),
      modelRepositoryProvider.overrideWithValue(modelRepo),
      settingsProvider.overrideWith(
        (ref) => SettingsNotifier(settingsRepo, llmRepo, modelRepo),
      ),
    ],
    child: const MaterialApp(home: OnboardingScreen()),
  );
}

void main() {
  group('OnboardingScreen', () {
    testWidgets('render_showsWelcomePage', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Welcome to AIOS'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('render_showsPageIndicator', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Welcome to AIOS'), findsOneWidget);
    });

    testWidgets('tapNext_showsModelSetupPage', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Set Up Your AI Model'), findsOneWidget);
    });

    testWidgets('tapNextTwice_showsPermissionPage', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Permissions'), findsOneWidget);
    });

    testWidgets('tapNextThreeTimes_showsReadyPage', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text("You're All Set!"), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('render_showsFeatureItems', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Local AI'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Smart Agent'), findsOneWidget);
    });
  });
}
