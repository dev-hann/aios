import 'dart:async';

import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/model_info.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/entities/update_info.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/domain/repositories/model_repository.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:aios/domain/repositories/update_repository.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/model_provider.dart';
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
  int _contextSize = SettingsRepository.defaultContextSize;
  int _maxTokens = SettingsRepository.defaultMaxTokens;
  int _topK = SettingsRepository.defaultTopK;
  double _topP = SettingsRepository.defaultTopP;
  double _repeatPenalty = SettingsRepository.defaultRepeatPenalty;
  int _agentMaxIterations = SettingsRepository.defaultAgentMaxIterations;
  String? _lastModelPath;
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
  Future<void> setRepeatPenalty(double value) async => _repeatPenalty = value;
  @override
  Future<void> setAgentMaxIterations(int value) async =>
      _agentMaxIterations = value;
  @override
  Future<void> setLastModelPath(String path) async => _lastModelPath = path;
  @override
  Future<void> clearLastModelPath() async => _lastModelPath = null;
  @override
  Future<void> setOnboardingCompleted() async =>
      _onboardingCompleted = true;
}

class _MockLlmRepository implements LlmRepository {
  final _stateController = StreamController<ServiceState>.broadcast();
  final _tokenController = StreamController<String>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  @override
  Stream<ServiceState> get state => _stateController.stream;
  @override
  Stream<String> get tokenStream => _tokenController.stream;
  @override
  Stream<double> get loadProgress => _progressController.stream;
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
    String? grammar,
  }) async {}
  @override
  Future<void> stopGeneration() async {}
  @override
  Future<void> saveSession(String path) async {}
  @override
  Future<void> loadSession(String path) async {}
}

class _MockModelRepository implements ModelRepository {
  final List<ModelInfo> _models = [];
  final List<ModelInfo> _externalModels = [];

  void addExternalModel(ModelInfo model) => _externalModels.add(model);

  @override
  List<ModelInfo> scanModels() => List.unmodifiable(_models);
  @override
  List<ModelInfo> scanExternalDirs() => List.unmodifiable(_externalModels);
  @override
  bool restoreModel(String name) => false;
  @override
  Future<bool> importModelFromUri(String sourcePath, String fileName) async {
    _models.add(ModelInfo(name: fileName, size: 1024, path: sourcePath));
    return true;
  }
}

class _MockUpdateRepository implements UpdateRepository {
  @override
  Future<UpdateResult> checkForUpdate() async {
    return const UpdateResult.notAvailable();
  }

  @override
  Future<String?> downloadApk(String url, String fileName,
      {void Function(double)? onProgress}) async {
    return '/tmp/fake.apk';
  }

  @override
  Future<bool> installApk(String apkPath) async => true;
}

Widget _createTestWidget({_MockModelRepository? modelRepo}) {
  final settingsRepo = _MockSettingsRepository();
  final llmRepo = _MockLlmRepository();
  final mRepo = modelRepo ?? _MockModelRepository();
  final updateRepo = _MockUpdateRepository();

  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(settingsRepo),
      llmRepositoryProvider.overrideWithValue(llmRepo),
      modelRepositoryProvider.overrideWithValue(mRepo),
      settingsProvider.overrideWith(
        (ref) => SettingsNotifier(settingsRepo, llmRepo, mRepo),
      ),
      updateRepositoryProvider.overrideWithValue(updateRepo),
      currentVersionProvider.overrideWithValue('1.0.0'),
    ],
    child: const MaterialApp(
      home: SettingsScreen(),
    ),
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
    testWidgets('shows_model_section', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Model'), findsOneWidget);
      expect(find.text('No model loaded'), findsOneWidget);
    });

    testWidgets('shows_inference_section', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Inference'), findsOneWidget);
    });

    testWidgets('shows_permissions_section', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Permissions'), findsOneWidget);
    });

    testWidgets('shows_update_check_button', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Check for Updates'), findsOneWidget);
    });

    testWidgets('shows_version_info', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Version'), findsOneWidget);
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

      final updateButton = find.widgetWithText(
        OutlinedButton,
        'Check for Updates',
      );
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
