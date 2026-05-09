import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  late SharedPreferences _prefs;

  static const String _keyContextSize = 'context_size';
  static const String _keyMaxTokens = 'max_tokens';
  static const String _keyTemperature = 'temperature';
  static const String _keyTopK = 'top_k';
  static const String _keyTopP = 'top_p';
  static const String _keyRepeatPenalty = 'repeat_penalty';
  static const String _keyAgentMaxIterations = 'agent_max_iterations';
  static const String _keyLastModelPath = 'last_model_path';
  static const String _keyOnboardingCompleted = 'onboarding_completed';


  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  int get contextSize =>
      _prefs.getInt(_keyContextSize) ?? SettingsRepository.defaultContextSize;

  @override
  int get maxTokens =>
      _prefs.getInt(_keyMaxTokens) ?? SettingsRepository.defaultMaxTokens;

  @override
  double get temperature =>
      _prefs.getDouble(_keyTemperature) ??
      SettingsRepository.defaultTemperature;

  @override
  int get topK =>
      _prefs.getInt(_keyTopK) ?? SettingsRepository.defaultTopK;

  @override
  double get topP =>
      _prefs.getDouble(_keyTopP) ?? SettingsRepository.defaultTopP;

  @override
  double get repeatPenalty =>
      _prefs.getDouble(_keyRepeatPenalty) ??
      SettingsRepository.defaultRepeatPenalty;

  @override
  int get agentMaxIterations =>
      _prefs.getInt(_keyAgentMaxIterations) ??
      SettingsRepository.defaultAgentMaxIterations;

  @override
  String? get lastModelPath => _prefs.getString(_keyLastModelPath);

  @override
  Future<void> setContextSize(int value) =>
      _prefs.setInt(_keyContextSize, value);

  @override
  Future<void> setMaxTokens(int value) =>
      _prefs.setInt(_keyMaxTokens, value);

  @override
  Future<void> setTemperature(double value) =>
      _prefs.setDouble(_keyTemperature, value);

  @override
  Future<void> setTopK(int value) => _prefs.setInt(_keyTopK, value);

  @override
  Future<void> setTopP(double value) => _prefs.setDouble(_keyTopP, value);

  @override
  Future<void> setRepeatPenalty(double value) =>
      _prefs.setDouble(_keyRepeatPenalty, value);

  @override
  Future<void> setAgentMaxIterations(int value) =>
      _prefs.setInt(_keyAgentMaxIterations, value);

  @override
  Future<void> setLastModelPath(String path) =>
      _prefs.setString(_keyLastModelPath, path);

  @override
  Future<void> clearLastModelPath() => _prefs.remove(_keyLastModelPath);

  @override
  bool get onboardingCompleted =>
      _prefs.getBool(_keyOnboardingCompleted) ?? false;

  @override
  Future<void> setOnboardingCompleted() =>
      _prefs.setBool(_keyOnboardingCompleted, true);

}
