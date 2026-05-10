import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockSettingsRepository implements SettingsRepository {
  double _temperature = SettingsRepository.defaultTemperature;
  int _maxTokens = SettingsRepository.defaultMaxTokens;
  double _topP = SettingsRepository.defaultTopP;
  int _agentMaxIterations = SettingsRepository.defaultAgentMaxIterations;
  String? _providerConfig;
  bool _onboardingCompleted = false;

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

void main() {
  group('SettingsRepository', () {
    late _MockSettingsRepository repository;

    setUp(() {
      repository = _MockSettingsRepository();
    });

    test('defaults_matchConstants', () {
      expect(repository.maxTokens, SettingsRepository.defaultMaxTokens);
      expect(repository.temperature, SettingsRepository.defaultTemperature);
      expect(repository.topP, SettingsRepository.defaultTopP);
      expect(
        repository.agentMaxIterations,
        SettingsRepository.defaultAgentMaxIterations,
      );
    });

    test('providerConfig_initiallyNull', () {
      expect(repository.providerConfig, isNull);
    });

    test('set_maxTokens_updatesValue', () async {
      await repository.setMaxTokens(1024);

      expect(repository.maxTokens, 1024);
    });

    test('set_temperature_updatesValue', () async {
      await repository.setTemperature(0.5);

      expect(repository.temperature, 0.5);
    });

    test('set_topP_updatesValue', () async {
      await repository.setTopP(0.8);

      expect(repository.topP, 0.8);
    });

    test('set_agentMaxIterations_updatesValue', () async {
      await repository.setAgentMaxIterations(12);

      expect(repository.agentMaxIterations, 12);
    });

    test('set_providerConfig_updatesValue', () async {
      await repository.setProviderConfig('{"type":"openai"}');

      expect(repository.providerConfig, '{"type":"openai"}');
    });

    test('clear_providerConfig_setsNull', () async {
      await repository.setProviderConfig('{"type":"openai"}');
      expect(repository.providerConfig, isNotNull);

      await repository.clearProviderConfig();

      expect(repository.providerConfig, isNull);
    });

    test('onboardingCompleted_defaultIsFalse', () {
      expect(repository.onboardingCompleted, isFalse);
    });

    test('setOnboardingCompleted_setsTrue', () async {
      await repository.setOnboardingCompleted();

      expect(repository.onboardingCompleted, isTrue);
    });
  });

  group('SettingsRepository constants', () {
    test('default_values_areExpected', () {
      expect(SettingsRepository.defaultMaxTokens, 512);
      expect(SettingsRepository.defaultTemperature, 1.0);
      expect(SettingsRepository.defaultTopP, 0.95);
      expect(SettingsRepository.defaultAgentMaxIterations, 8);
    });
  });
}
