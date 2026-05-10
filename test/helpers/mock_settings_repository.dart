import 'package:aios/domain/repositories/settings_repository.dart';

class MockSettingsRepository implements SettingsRepository {
  double _temperature;
  int _maxTokens;
  double _topP;
  int _agentMaxIterations;
  String? _providerConfig;
  bool _onboardingCompleted;

  MockSettingsRepository({
    double? temperature,
    int? maxTokens,
    double? topP,
    int? agentMaxIterations,
    String? providerConfig,
    bool onboardingCompleted = true,
  }) : _temperature = temperature ?? SettingsRepository.defaultTemperature,
       _maxTokens = maxTokens ?? SettingsRepository.defaultMaxTokens,
       _topP = topP ?? SettingsRepository.defaultTopP,
       _agentMaxIterations =
           agentMaxIterations ?? SettingsRepository.defaultAgentMaxIterations,
       _providerConfig = providerConfig,
       _onboardingCompleted = onboardingCompleted;

  @override
  double get temperature => _temperature;

  @override
  int get maxTokens => _maxTokens;

  @override
  double get topP => _topP;

  @override
  int get agentMaxIterations => _agentMaxIterations;

  @override
  String? get providerConfig => _providerConfig;

  @override
  bool get onboardingCompleted => _onboardingCompleted;

  @override
  Future<void> setTemperature(double value) async => _temperature = value;

  @override
  Future<void> setMaxTokens(int value) async => _maxTokens = value;

  @override
  Future<void> setTopP(double value) async => _topP = value;

  @override
  Future<void> setAgentMaxIterations(int value) async =>
      _agentMaxIterations = value;

  @override
  Future<void> setProviderConfig(String json) async => _providerConfig = json;

  @override
  Future<void> clearProviderConfig() async => _providerConfig = null;

  @override
  Future<void> setOnboardingCompleted() async => _onboardingCompleted = true;
}
