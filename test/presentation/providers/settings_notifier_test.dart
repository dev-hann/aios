import 'dart:async';

import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/model_info.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/domain/repositories/model_repository.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:aios/presentation/providers/settings_notifier.dart';
import 'package:flutter/material.dart';
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
  Future<void> setRepeatPenalty(double value) async => _repeatPenalty = value;
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
  final _tokenController = StreamController<String>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  bool modelLoaded = false;
  String? lastModelPath;
  int? lastContextSize;

  @override
  Stream<ServiceState> get state => _stateController.stream;

  @override
  Stream<String> get tokenStream => _tokenController.stream;

  @override
  Stream<double> get loadProgress => _progressController.stream;

  @override
  Future<bool> loadModel(String path, {int? contextSize}) async {
    lastModelPath = path;
    lastContextSize = contextSize;
    modelLoaded = true;
    return true;
  }

  @override
  Future<void> releaseModel() async {
    modelLoaded = false;
  }

  @override
  bool get isModelLoaded => modelLoaded;

  @override
  String getModelInfo() => 'MockModel';

  @override
  String getContextUsage() => '0/2048';

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
  final List<ModelInfo> _models = [];
  final List<ModelInfo> _externalModels = [];
  Object? _scanError;
  bool _importShouldFail = false;
  Object? _importError;

  void addTestModel(ModelInfo model) => _models.add(model);

  void addExternalModel(ModelInfo model) => _externalModels.add(model);

  void setScanError(Object error) => _scanError = error;

  void setImportFail() => _importShouldFail = true;

  void setImportError(Object error) => _importError = error;

  @override
  List<ModelInfo> scanModels() {
    if (_scanError != null) throw _scanError!;
    return List.unmodifiable(_models);
  }

  @override
  List<ModelInfo> scanExternalDirs() => List.unmodifiable(_externalModels);

  @override
  bool restoreModel(String name) => _models.any((m) => m.name == name);

  @override
  Future<bool> importModelFromUri(String sourcePath, String fileName) async {
    if (_importError != null) throw _importError!;
    if (_importShouldFail) return false;
    _models.add(ModelInfo(name: fileName, size: 1024, path: sourcePath));
    return true;
  }
}

class _FailingLlmRepository implements LlmRepository {
  bool _shouldFail = true;
  final _stateController = StreamController<ServiceState>.broadcast();
  final _tokenController = StreamController<String>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  void setSucceed() => _shouldFail = false;

  @override
  Stream<ServiceState> get state => _stateController.stream;

  @override
  Stream<String> get tokenStream => _tokenController.stream;

  @override
  Stream<double> get loadProgress => _progressController.stream;

  @override
  Future<bool> loadModel(String path, {int? contextSize}) async {
    if (_shouldFail) return false;
    _stateController.add(ServiceState.ready);
    return true;
  }

  @override
  Future<void> releaseModel() async {}

  @override
  bool get isModelLoaded => !_shouldFail;

  @override
  String getModelInfo() => 'Mock';

  @override
  String getContextUsage() => '0/2048';

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

  void dispose() {
    _stateController.close();
    _tokenController.close();
    _progressController.close();
  }
}

class _ErrorLlmRepository implements LlmRepository {
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
  Future<bool> loadModel(String path, {int? contextSize}) async {
    throw Exception('Load failed');
  }

  @override
  Future<void> releaseModel() async {}

  @override
  bool get isModelLoaded => false;

  @override
  String getModelInfo() => 'Mock';

  @override
  String getContextUsage() => '0/2048';

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

  void dispose() {
    _stateController.close();
    _tokenController.close();
    _progressController.close();
  }
}

void main() {
  group('SettingsNotifier', () {
    late _MockSettingsRepository settingsRepo;
    late _MockLlmRepository llmRepo;
    late _MockModelRepository modelRepo;
    late SettingsNotifier notifier;

    setUp(() {
      settingsRepo = _MockSettingsRepository();
      llmRepo = _MockLlmRepository();
      modelRepo = _MockModelRepository();
      notifier = SettingsNotifier(settingsRepo, llmRepo, modelRepo);
    });

    test('initial_state_hasDefaultValues', () {
      final state = notifier.state;

      expect(state.temperature, SettingsRepository.defaultTemperature);
      expect(state.contextSize, SettingsRepository.defaultContextSize);
      expect(state.maxTokens, SettingsRepository.defaultMaxTokens);
      expect(state.topK, SettingsRepository.defaultTopK);
      expect(state.topP, SettingsRepository.defaultTopP);
      expect(state.repeatPenalty, SettingsRepository.defaultRepeatPenalty);
      expect(
        state.agentMaxIterations,
        SettingsRepository.defaultAgentMaxIterations,
      );
      expect(state.lastModelPath, isNull);
      expect(state.availableModels, isEmpty);
      expect(state.isLoadingModel, isFalse);
    });

    test('updateTemperature_persistsAndUpdatesState', () async {
      await notifier.updateTemperature(0.5);

      expect(notifier.state.temperature, 0.5);
      expect(settingsRepo.temperature, 0.5);
    });

    test('updateContextSize_persistsAndUpdatesState', () async {
      await notifier.updateContextSize(4096);

      expect(notifier.state.contextSize, 4096);
      expect(settingsRepo.contextSize, 4096);
    });

    test('updateMaxTokens_persistsAndUpdatesState', () async {
      await notifier.updateMaxTokens(1024);

      expect(notifier.state.maxTokens, 1024);
      expect(settingsRepo.maxTokens, 1024);
    });

    test('updateTopK_persistsAndUpdatesState', () async {
      await notifier.updateTopK(20);

      expect(notifier.state.topK, 20);
      expect(settingsRepo.topK, 20);
    });

    test('updateTopP_persistsAndUpdatesState', () async {
      await notifier.updateTopP(0.8);

      expect(notifier.state.topP, 0.8);
      expect(settingsRepo.topP, 0.8);
    });

    test('updateRepeatPenalty_persistsAndUpdatesState', () async {
      await notifier.updateRepeatPenalty(1.2);

      expect(notifier.state.repeatPenalty, 1.2);
      expect(settingsRepo.repeatPenalty, 1.2);
    });

    test('updateAgentMaxIterations_persistsAndUpdatesState', () async {
      await notifier.updateAgentMaxIterations(12);

      expect(notifier.state.agentMaxIterations, 12);
      expect(settingsRepo.agentMaxIterations, 12);
    });

    test('scanModels_returnsAvailableModels', () {
      modelRepo.addTestModel(
        const ModelInfo(name: 'test.gguf', size: 1024, path: '/test.gguf'),
      );

      final models = notifier.scanModels();

      expect(models.length, 1);
      expect(models.first.name, 'test.gguf');
      expect(notifier.state.availableModels.length, 1);
    });

    test('scanModels_returnsOnlyInternalModels', () {
      modelRepo.addTestModel(
        const ModelInfo(name: 'internal.gguf', size: 1024, path: '/models/internal.gguf'),
      );
      modelRepo.addExternalModel(
        const ModelInfo(name: 'external.gguf', size: 2048, path: '/sdcard/Download/external.gguf'),
      );

      final models = notifier.scanModels();

      expect(models.length, 1);
      expect(models.first.name, 'internal.gguf');
    });

    test('scanImportableModels_returnsExternalModels', () {
      modelRepo.addExternalModel(
        const ModelInfo(
          name: 'download.gguf',
          size: 2048,
          path: '/sdcard/Download/download.gguf',
        ),
      );

      final models = notifier.scanImportableModels();

      expect(models.length, 1);
      expect(models.first.name, 'download.gguf');
    });

    test('scanImportableModels_returnsEmptyWhenNoExternal', () {
      final models = notifier.scanImportableModels();

      expect(models, isEmpty);
    });

    test('loadModel_delegatesToLlmRepository', () async {
      final result = await notifier.loadModel('/path/to/model.gguf');

      expect(result, isTrue);
      expect(llmRepo.lastModelPath, '/path/to/model.gguf');
      expect(
        llmRepo.lastContextSize,
        SettingsRepository.defaultContextSize,
      );
      expect(notifier.state.lastModelPath, '/path/to/model.gguf');
      expect(notifier.state.isLoadingModel, isFalse);
    });

    test('loadModel_passesContextSizeFromState', () async {
      await notifier.updateContextSize(8192);

      await notifier.loadModel('/path/to/model.gguf');

      expect(llmRepo.lastContextSize, 8192);
    });

    test('loadModel_setsIsLoadingDuringOperation', () async {
      expect(notifier.state.isLoadingModel, isFalse);

      final future = notifier.loadModel('/path/to/model.gguf');
      expect(notifier.state.isLoadingModel, isTrue);

      await future;
      expect(notifier.state.isLoadingModel, isFalse);
    });

    test('loadSettings_readsFromRepository', () async {
      await settingsRepo.setTemperature(0.3);
      await settingsRepo.setContextSize(4096);
      modelRepo.addTestModel(
        const ModelInfo(name: 'm.gguf', size: 2048, path: '/m.gguf'),
      );

      await notifier.loadSettings();

      expect(notifier.state.temperature, 0.3);
      expect(notifier.state.contextSize, 4096);
      expect(notifier.state.availableModels.length, 1);
    });

    test('loadSettings_exception_doesNotThrow', () async {
      modelRepo.setScanError(Exception('scan failed'));

      await notifier.loadSettings();

      expect(notifier.state.temperature, SettingsRepository.defaultTemperature);
    });

    test('loadModel_failure_setsIsLoadingFalse', () async {
      final failingLlmRepo = _FailingLlmRepository();
      final failingNotifier = SettingsNotifier(
        settingsRepo,
        failingLlmRepo,
        modelRepo,
      );

      final result =
          await failingNotifier.loadModel('/path/to/model.gguf');

      expect(result, isFalse);
      expect(failingNotifier.state.isLoadingModel, isFalse);

      failingLlmRepo.dispose();
    });

    test('loadModel_exception_returnsFalse', () async {
      final errorLlmRepo = _ErrorLlmRepository();
      final errorNotifier = SettingsNotifier(
        settingsRepo,
        errorLlmRepo,
        modelRepo,
      );

      final result = await errorNotifier.loadModel('/path/to/model.gguf');

      expect(result, isFalse);
      expect(errorNotifier.state.isLoadingModel, isFalse);

      errorLlmRepo.dispose();
    });

    group('importModel', () {
      test('importModel_success_returnsTrueAndRefreshesModels', () async {
        final result = await notifier.importModel(
          '/sdcard/Download/model.gguf',
          'model.gguf',
        );

        expect(result, isTrue);
        expect(notifier.state.availableModels, isNotEmpty);
        expect(
          notifier.state.availableModels.any(
            (m) => m.name == 'model.gguf',
          ),
          isTrue,
        );
      });

      test('importModel_failure_returnsFalse', () async {
        modelRepo.setImportFail();

        final result = await notifier.importModel(
          '/sdcard/Download/model.gguf',
          'model.gguf',
        );

        expect(result, isFalse);
        expect(notifier.state.availableModels, isEmpty);
      });

      test('importModel_exception_returnsFalse', () async {
        modelRepo.setImportError(Exception('copy failed'));

        final result = await notifier.importModel(
          '/sdcard/Download/model.gguf',
          'model.gguf',
        );

        expect(result, isFalse);
        expect(notifier.state.availableModels, isEmpty);
      });
    });

    group('themeMode', () {
      test('updateThemeMode_persistsAndUpdatesState', () async {
        await notifier.updateThemeMode(ThemeMode.light);

        expect(notifier.state.themeMode, ThemeMode.light);
        expect(settingsRepo.themeMode, 'light');
      });

      test('updateThemeMode_dark_persistsAndUpdatesState', () async {
        await notifier.updateThemeMode(ThemeMode.dark);

        expect(notifier.state.themeMode, ThemeMode.dark);
        expect(settingsRepo.themeMode, 'dark');
      });

      test('updateThemeMode_system_persistsAndUpdatesState', () async {
        await notifier.updateThemeMode(ThemeMode.system);

        expect(notifier.state.themeMode, ThemeMode.system);
        expect(settingsRepo.themeMode, 'system');
      });
    });

    group('onboarding', () {
      test('completeOnboarding_persistsAndUpdatesState', () async {
        expect(notifier.state.onboardingCompleted, isFalse);

        await notifier.completeOnboarding();

        expect(notifier.state.onboardingCompleted, isTrue);
        expect(settingsRepo.onboardingCompleted, isTrue);
      });
    });
  });
}
