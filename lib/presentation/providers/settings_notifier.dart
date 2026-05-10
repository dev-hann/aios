import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:aios/presentation/providers/settings_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(
    this._settingsRepository,
    this._llmRepository, {
    void Function(LlmProviderConfig config)? onProviderConnected,
  }) : _onProviderConnected = onProviderConnected,
       super(SettingsState.initial()) {
    _init();
  }
  static const String _tag = 'AIOS-Settings';

  final SettingsRepository _settingsRepository;
  final LlmRepository _llmRepository;
  final void Function(LlmProviderConfig config)? _onProviderConnected;

  Future<void> _init() async {
    await loadSettings();
    await _autoConnect();
  }

  Future<void> loadSettings() async {
    try {
      final configJson = _settingsRepository.providerConfig;
      LlmProviderConfig? config;
      if (configJson != null) {
        config = LlmProviderConfig.fromJson(configJson);
      }

      state = SettingsState(
        temperature: _settingsRepository.temperature,
        topP: _settingsRepository.topP,
        maxTokens: _settingsRepository.maxTokens,
        agentMaxIterations: _settingsRepository.agentMaxIterations,
        providerConfig: config,
        onboardingCompleted: _settingsRepository.onboardingCompleted,
      );
      print('[$_tag] Settings loaded');
    } on Object catch (e) {
      print('[$_tag] ERROR: loadSettings failed - $e');
    }
  }

  Future<void> completeOnboarding() async {
    await _settingsRepository.setOnboardingCompleted();
    state = state.copyWith(onboardingCompleted: true);
  }

  Future<void> _autoConnect() async {
    final config = state.providerConfig;
    if (config == null) return;
    print('[$_tag] Auto-connecting: ${config.model}');
    await connect(config);
  }

  Future<void> updateTemperature(double value) async {
    await _settingsRepository.setTemperature(value);
    state = state.copyWith(temperature: value);
  }

  Future<void> updateTopP(double value) async {
    await _settingsRepository.setTopP(value);
    state = state.copyWith(topP: value);
  }

  Future<void> updateMaxTokens(int value) async {
    await _settingsRepository.setMaxTokens(value);
    state = state.copyWith(maxTokens: value);
  }

  Future<void> updateAgentMaxIterations(int value) async {
    await _settingsRepository.setAgentMaxIterations(value);
    state = state.copyWith(agentMaxIterations: value);
  }

  Future<bool> connect(LlmProviderConfig config) async {
    state = state.copyWith(isTestingConnection: true);
    final ok = await _llmRepository.connect(config);
    if (!mounted) return false;

    state = state.copyWith(isTestingConnection: false);

    if (ok) {
      await _settingsRepository.setProviderConfig(config.toJson());
      state = state.copyWith(providerConfig: config);
      _onProviderConnected?.call(config);
      print('[$_tag] Connected: ${config.model}');
      await fetchModels(config);
    }
    return ok;
  }

  Future<void> fetchModels(LlmProviderConfig config) async {
    state = state.copyWith(isLoadingModels: true);
    final models = await _llmRepository.fetchModels(config);
    if (!mounted) return;
    state = state.copyWith(availableModels: models, isLoadingModels: false);
  }

  Future<bool> testConnection(LlmProviderConfig config) async {
    return _llmRepository.testConnection(config);
  }

  Future<void> disconnect() async {
    await _llmRepository.disconnect();
    await _settingsRepository.clearProviderConfig();
    state = state.copyWith(providerConfig: null, availableModels: []);
  }
}
