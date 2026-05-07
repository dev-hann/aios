import 'package:aios/domain/entities/model_info.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/domain/repositories/model_repository.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:aios/presentation/providers/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsNotifier extends StateNotifier<SettingsState> {
  static const String _tag = 'AIOS-Settings';

  final SettingsRepository _settingsRepository;
  final LlmRepository _llmRepository;
  final ModelRepository _modelRepository;

  SettingsNotifier(
    this._settingsRepository,
    this._llmRepository,
    this._modelRepository,
  ) : super(SettingsState.initial()) {
    _init();
  }

  Future<void> _init() async {
    await loadSettings();
    await _autoLoadLastModel();
  }

  Future<void> loadSettings() async {
    try {
      state = SettingsState(
        temperature: _settingsRepository.temperature,
        contextSize: _settingsRepository.contextSize,
        maxTokens: _settingsRepository.maxTokens,
        topK: _settingsRepository.topK,
        topP: _settingsRepository.topP,
        repeatPenalty: _settingsRepository.repeatPenalty,
        agentMaxIterations: _settingsRepository.agentMaxIterations,
        lastModelPath: _settingsRepository.lastModelPath,
        availableModels: _modelRepository.scanModels(),
        themeMode: _parseThemeMode(_settingsRepository.themeMode),
        onboardingCompleted: _settingsRepository.onboardingCompleted,
      );
      print('[$_tag] Settings loaded');
    } catch (e) {
      print('[$_tag] ERROR: loadSettings failed - $e');
    }
  }

  ThemeMode _parseThemeMode(String mode) {
    return switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  String _themeModeToString(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    await _settingsRepository.setThemeMode(_themeModeToString(mode));
    state = state.copyWith(themeMode: mode);
  }

  Future<void> completeOnboarding() async {
    await _settingsRepository.setOnboardingCompleted();
    state = state.copyWith(onboardingCompleted: true);
  }

  Future<void> _autoLoadLastModel() async {
    final path = _settingsRepository.lastModelPath;
    if (path == null) return;
    final models = state.availableModels;
    final exists = models.any((m) => m.path == path);
    if (!exists) {
      print('[$_tag] WARN: Last model not found: $path');
      return;
    }
    print('[$_tag] Auto-loading last model: $path');
    await loadModel(path);
  }

  Future<void> updateTemperature(double value) async {
    await _settingsRepository.setTemperature(value);
    state = state.copyWith(temperature: value);
  }

  Future<void> updateContextSize(int value) async {
    await _settingsRepository.setContextSize(value);
    state = state.copyWith(contextSize: value);
  }

  Future<void> updateMaxTokens(int value) async {
    await _settingsRepository.setMaxTokens(value);
    state = state.copyWith(maxTokens: value);
  }

  Future<void> updateTopK(int value) async {
    await _settingsRepository.setTopK(value);
    state = state.copyWith(topK: value);
  }

  Future<void> updateTopP(double value) async {
    await _settingsRepository.setTopP(value);
    state = state.copyWith(topP: value);
  }

  Future<void> updateRepeatPenalty(double value) async {
    await _settingsRepository.setRepeatPenalty(value);
    state = state.copyWith(repeatPenalty: value);
  }

  Future<void> updateAgentMaxIterations(int value) async {
    await _settingsRepository.setAgentMaxIterations(value);
    state = state.copyWith(agentMaxIterations: value);
  }

  List<ModelInfo> scanModels() {
    final models = _modelRepository.scanModels();
    state = state.copyWith(availableModels: models);
    return models;
  }

  List<ModelInfo> scanImportableModels() {
    return _modelRepository.scanExternalDirs();
  }

  Future<bool> importModel(String sourcePath, String fileName) async {
    try {
      final success =
          await _modelRepository.importModelFromUri(sourcePath, fileName);
      if (success) {
        scanModels();
        print('[$_tag] Model imported: $fileName');
      }
      return success;
    } catch (e) {
      print('[$_tag] ERROR: importModel failed - $e');
      return false;
    }
  }

  Future<bool> loadModel(String path) async {
    state = state.copyWith(isLoadingModel: true);
    try {
      final success = await _llmRepository.loadModel(
        path,
        contextSize: state.contextSize,
      );
      if (success) {
        await _settingsRepository.setLastModelPath(path);
        state = state.copyWith(
          lastModelPath: path,
          isLoadingModel: false,
        );
        print('[$_tag] Model loaded: $path');
      } else {
        state = state.copyWith(isLoadingModel: false);
        print('[$_tag] WARN: Model load failed: $path');
      }
      return success;
    } catch (e) {
      state = state.copyWith(isLoadingModel: false);
      print('[$_tag] ERROR: loadModel error - $e');
      return false;
    }
  }
}
