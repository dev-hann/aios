import 'dart:developer' as developer;

import 'package:aios/domain/entities/model_info.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/domain/repositories/model_repository.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:aios/presentation/providers/settings_state.dart';
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
  ) : super(SettingsState.initial());

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
      );
      developer.log('Settings loaded', name: _tag);
    } catch (e) {
      developer.log('loadSettings failed',
          name: _tag, error: e, level: 1000);
    }
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
    final internal = _modelRepository.scanModels();
    final external = _modelRepository.scanExternalDirs();
    final all = <String, ModelInfo>{};
    for (final m in [...internal, ...external]) {
      all[m.path] = m;
    }
    final models = all.values.toList();
    state = state.copyWith(availableModels: models);
    return models;
  }

  Future<bool> loadModel(String path) async {
    state = state.copyWith(isLoadingModel: true);
    try {
      final success = await _llmRepository.loadModel(path);
      if (success) {
        await _settingsRepository.setLastModelPath(path);
        state = state.copyWith(
          lastModelPath: path,
          isLoadingModel: false,
        );
        developer.log('Model loaded: $path', name: _tag);
      } else {
        state = state.copyWith(isLoadingModel: false);
        developer.log('Model load failed: $path',
            name: _tag, level: 900);
      }
      return success;
    } catch (e) {
      state = state.copyWith(isLoadingModel: false);
      developer.log('loadModel error', name: _tag, error: e, level: 1000);
      return false;
    }
  }
}
