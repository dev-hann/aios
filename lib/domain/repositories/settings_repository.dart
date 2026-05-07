abstract class SettingsRepository {
  int get contextSize;
  int get maxTokens;
  double get temperature;
  int get topK;
  double get topP;
  double get repeatPenalty;
  int get agentMaxIterations;
  String? get lastModelPath;

  Future<void> setContextSize(int value);
  Future<void> setMaxTokens(int value);
  Future<void> setTemperature(double value);
  Future<void> setTopK(int value);
  Future<void> setTopP(double value);
  Future<void> setRepeatPenalty(double value);
  Future<void> setAgentMaxIterations(int value);
  Future<void> setLastModelPath(String path);
  Future<void> clearLastModelPath();
  String get themeMode;
  Future<void> setThemeMode(String mode);
  bool get onboardingCompleted;
  Future<void> setOnboardingCompleted();

  static const int defaultContextSize = 2048;
  static const int defaultMaxTokens = 512;
  static const double defaultTemperature = 0.7;
  static const int defaultTopK = 40;
  static const double defaultTopP = 0.9;
  static const double defaultRepeatPenalty = 1.1;
  static const int defaultAgentMaxIterations = 8;
}
