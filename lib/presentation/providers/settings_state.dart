import 'package:aios/domain/entities/model_info.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_state.freezed.dart';

@freezed
class SettingsState with _$SettingsState {
  const factory SettingsState({
    required double temperature,
    required int contextSize,
    required int maxTokens,
    required int topK,
    required double topP,
    required double repeatPenalty,
    required int agentMaxIterations,
    String? lastModelPath,
    @Default([]) List<ModelInfo> availableModels,
    @Default(false) bool isLoadingModel,
    @Default(false) bool onboardingCompleted,
  }) = _SettingsState;

  factory SettingsState.initial() => SettingsState(
        temperature: SettingsRepository.defaultTemperature,
        contextSize: SettingsRepository.defaultContextSize,
        maxTokens: SettingsRepository.defaultMaxTokens,
        topK: SettingsRepository.defaultTopK,
        topP: SettingsRepository.defaultTopP,
        repeatPenalty: SettingsRepository.defaultRepeatPenalty,
        agentMaxIterations: SettingsRepository.defaultAgentMaxIterations,
      );
}
