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
      expect(repository.contextSize, SettingsRepository.defaultContextSize);
      expect(repository.maxTokens, SettingsRepository.defaultMaxTokens);
      expect(repository.temperature, SettingsRepository.defaultTemperature);
      expect(repository.topK, SettingsRepository.defaultTopK);
      expect(repository.topP, SettingsRepository.defaultTopP);
      expect(repository.repeatPenalty, SettingsRepository.defaultRepeatPenalty);
      expect(
        repository.agentMaxIterations,
        SettingsRepository.defaultAgentMaxIterations,
      );
      expect(repository.lastModelPath, isNull);
    });

    test('setContextSize_persistsValue', () async {
      await repository.setContextSize(4096);

      expect(repository.contextSize, 4096);

      final repo2 = SettingsRepositoryImpl();
      await repo2.init();
      expect(repo2.contextSize, 4096);
    });

    test('setTemperature_persistsValue', () async {
      await repository.setTemperature(0.5);

      expect(repository.temperature, 0.5);

      final repo2 = SettingsRepositoryImpl();
      await repo2.init();
      expect(repo2.temperature, 0.5);
    });

    test('setTopK_persistsValue', () async {
      await repository.setTopK(20);

      expect(repository.topK, 20);

      final repo2 = SettingsRepositoryImpl();
      await repo2.init();
      expect(repo2.topK, 20);
    });

    test('setTopP_persistsValue', () async {
      await repository.setTopP(0.8);

      expect(repository.topP, 0.8);

      final repo2 = SettingsRepositoryImpl();
      await repo2.init();
      expect(repo2.topP, 0.8);
    });

    test('setRepeatPenalty_persistsValue', () async {
      await repository.setRepeatPenalty(1.2);

      expect(repository.repeatPenalty, 1.2);

      final repo2 = SettingsRepositoryImpl();
      await repo2.init();
      expect(repo2.repeatPenalty, 1.2);
    });

    test('setMaxTokens_persistsValue', () async {
      await repository.setMaxTokens(1024);

      expect(repository.maxTokens, 1024);

      final repo2 = SettingsRepositoryImpl();
      await repo2.init();
      expect(repo2.maxTokens, 1024);
    });

    test('setLastModelPath_persistsAndClears', () async {
      await repository.setLastModelPath('/path/to/model.gguf');

      expect(repository.lastModelPath, '/path/to/model.gguf');

      final repo2 = SettingsRepositoryImpl();
      await repo2.init();
      expect(repo2.lastModelPath, '/path/to/model.gguf');

      await repository.clearLastModelPath();
      expect(repository.lastModelPath, isNull);
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
