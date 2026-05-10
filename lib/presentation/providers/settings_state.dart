import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_state.freezed.dart';

@freezed
class SettingsState with _$SettingsState {
  const factory SettingsState({
    required double temperature,
    required double topP,
    required int maxTokens,
    required int agentMaxIterations,
    LlmProviderConfig? providerConfig,
    @Default([]) List<LlmModelInfo> availableModels,
    @Default(false) bool isLoadingModels,
    @Default(false) bool isTestingConnection,
    @Default(false) bool onboardingCompleted,
  }) = _SettingsState;

  factory SettingsState.initial() => const SettingsState(
    temperature: SettingsRepository.defaultTemperature,
    topP: SettingsRepository.defaultTopP,
    maxTokens: SettingsRepository.defaultMaxTokens,
    agentMaxIterations: SettingsRepository.defaultAgentMaxIterations,
  );
}
