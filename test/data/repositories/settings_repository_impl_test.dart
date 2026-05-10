import 'package:aios/data/repositories/settings_repository_impl.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsRepositoryImpl', () {
    late SettingsRepositoryImpl repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = SettingsRepositoryImpl();
      await repository.init();
    });

    test('defaults_returnExpectedValues', () {
      expect(repository.maxTokens, SettingsRepository.defaultMaxTokens);
      expect(repository.temperature, SettingsRepository.defaultTemperature);
      expect(repository.topP, SettingsRepository.defaultTopP);
      expect(
        repository.agentMaxIterations,
        SettingsRepository.defaultAgentMaxIterations,
      );
      expect(repository.providerConfig, isNull);
    });

    test('setTemperature_persistsValue', () async {
      await repository.setTemperature(0.5);

      expect(repository.temperature, 0.5);

      final repo2 = SettingsRepositoryImpl();
      await repo2.init();
      expect(repo2.temperature, 0.5);
    });

    test('setTopP_persistsValue', () async {
      await repository.setTopP(0.8);

      expect(repository.topP, 0.8);

      final repo2 = SettingsRepositoryImpl();
      await repo2.init();
      expect(repo2.topP, 0.8);
    });

    test('setMaxTokens_persistsValue', () async {
      await repository.setMaxTokens(1024);

      expect(repository.maxTokens, 1024);

      final repo2 = SettingsRepositoryImpl();
      await repo2.init();
      expect(repo2.maxTokens, 1024);
    });

    test('setProviderConfig_persistsAndClears', () async {
      await repository.setProviderConfig(
        '{"type":"openai","apiKey":"key","model":"gpt-4o"}',
      );

      expect(repository.providerConfig, isNotNull);

      final repo2 = SettingsRepositoryImpl();
      await repo2.init();
      expect(repo2.providerConfig, isNotNull);

      await repository.clearProviderConfig();
      expect(repository.providerConfig, isNull);
    });

    test('onboardingCompleted_defaultIsFalse', () {
      expect(repository.onboardingCompleted, isFalse);
    });

    test('setOnboardingCompleted_persistsValue', () async {
      await repository.setOnboardingCompleted();

      expect(repository.onboardingCompleted, isTrue);

      final repo2 = SettingsRepositoryImpl();
      await repo2.init();
      expect(repo2.onboardingCompleted, isTrue);
    });
  });
}
