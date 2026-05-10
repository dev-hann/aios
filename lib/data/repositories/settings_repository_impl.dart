import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  late SharedPreferences _prefs;

  static const String _keyTemperature = 'temperature';
  static const String _keyTopP = 'top_p';
  static const String _keyMaxTokens = 'max_tokens';
  static const String _keyAgentMaxIterations = 'agent_max_iterations';
  static const String _keyProviderConfig = 'provider_config';
  static const String _keyOnboardingCompleted = 'onboarding_completed';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  double get temperature =>
      _prefs.getDouble(_keyTemperature) ??
      SettingsRepository.defaultTemperature;

  @override
  double get topP =>
      _prefs.getDouble(_keyTopP) ?? SettingsRepository.defaultTopP;

  @override
  int get maxTokens =>
      _prefs.getInt(_keyMaxTokens) ?? SettingsRepository.defaultMaxTokens;

  @override
  int get agentMaxIterations =>
      _prefs.getInt(_keyAgentMaxIterations) ??
      SettingsRepository.defaultAgentMaxIterations;

  @override
  String? get providerConfig => _prefs.getString(_keyProviderConfig);

  @override
  bool get onboardingCompleted =>
      _prefs.getBool(_keyOnboardingCompleted) ?? false;

  @override
  Future<void> setTemperature(double value) =>
      _prefs.setDouble(_keyTemperature, value);

  @override
  Future<void> setTopP(double value) => _prefs.setDouble(_keyTopP, value);

  @override
  Future<void> setMaxTokens(int value) => _prefs.setInt(_keyMaxTokens, value);

  @override
  Future<void> setAgentMaxIterations(int value) =>
      _prefs.setInt(_keyAgentMaxIterations, value);

  @override
  Future<void> setProviderConfig(String json) =>
      _prefs.setString(_keyProviderConfig, json);

  @override
  Future<void> clearProviderConfig() => _prefs.remove(_keyProviderConfig);

  @override
  Future<void> setOnboardingCompleted() =>
      _prefs.setBool(_keyOnboardingCompleted, true);
}
