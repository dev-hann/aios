abstract class SettingsRepository {
  double get temperature;
  double get topP;
  int get maxTokens;
  int get agentMaxIterations;
  String? get providerConfig;
  bool get onboardingCompleted;

  Future<void> setTemperature(double value);
  Future<void> setTopP(double value);
  Future<void> setMaxTokens(int value);
  Future<void> setAgentMaxIterations(int value);
  Future<void> setProviderConfig(String json);
  Future<void> clearProviderConfig();
  Future<void> setOnboardingCompleted();

  static const double defaultTemperature = 1.0;
  static const double defaultTopP = 0.95;
  static const int defaultMaxTokens = 512;
  static const int defaultAgentMaxIterations = 8;
}
