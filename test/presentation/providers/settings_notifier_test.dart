import 'dart:async';

import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import '../../helpers/mock_llm_repository.dart';
import '../../helpers/mock_settings_repository.dart';
import 'package:aios/presentation/providers/settings_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockLlmRepository extends MockLlmRepository {
  @override
  Future<List<LlmModelInfo>> fetchModels(LlmProviderConfig config) async {
    return [const LlmModelInfo(id: 'gpt-4o', displayName: 'GPT-4o')];
  }
}

class _FailingLlmRepository extends MockLlmRepository {
  _FailingLlmRepository() {
    connectResult = false;
    testResult = false;
  }
}

void main() {
  group('SettingsNotifier', () {
    late MockSettingsRepository settingsRepo;
    late _MockLlmRepository llmRepo;
    late SettingsNotifier notifier;

    setUp(() {
      settingsRepo = MockSettingsRepository(onboardingCompleted: false);
      llmRepo = _MockLlmRepository();
      notifier = SettingsNotifier(settingsRepo, llmRepo);
    });

    test('initial_state_hasDefaultValues', () {
      final state = notifier.state;

      expect(state.temperature, SettingsRepository.defaultTemperature);
      expect(state.maxTokens, SettingsRepository.defaultMaxTokens);
      expect(state.topP, SettingsRepository.defaultTopP);
      expect(
        state.agentMaxIterations,
        SettingsRepository.defaultAgentMaxIterations,
      );
      expect(state.providerConfig, isNull);
      expect(state.availableModels, isEmpty);
    });

    test('updateTemperature_persistsAndUpdatesState', () async {
      await notifier.updateTemperature(0.5);

      expect(notifier.state.temperature, 0.5);
      expect(settingsRepo.temperature, 0.5);
    });

    test('updateMaxTokens_persistsAndUpdatesState', () async {
      await notifier.updateMaxTokens(1024);

      expect(notifier.state.maxTokens, 1024);
      expect(settingsRepo.maxTokens, 1024);
    });

    test('updateTopP_persistsAndUpdatesState', () async {
      await notifier.updateTopP(0.8);

      expect(notifier.state.topP, 0.8);
      expect(settingsRepo.topP, 0.8);
    });

    test('updateAgentMaxIterations_persistsAndUpdatesState', () async {
      await notifier.updateAgentMaxIterations(12);

      expect(notifier.state.agentMaxIterations, 12);
      expect(settingsRepo.agentMaxIterations, 12);
    });

    test('connect_delegatesToLlmRepository', () async {
      final config = LlmProviderConfig(
        type: LlmProviderType.openai,
        apiKey: 'test-key',
        model: 'gpt-4o',
      );

      final result = await notifier.connect(config);

      expect(result, isTrue);
      expect(llmRepo.lastConfig, isNotNull);
      expect(llmRepo.lastConfig!.model, 'gpt-4o');
    });

    test('connect_fetchesModels', () async {
      final config = LlmProviderConfig(
        type: LlmProviderType.openai,
        apiKey: 'test-key',
        model: 'gpt-4o',
      );

      await notifier.connect(config);

      expect(notifier.state.availableModels, isNotEmpty);
    });

    test('connect_failure_returnsFalse', () async {
      final failingLlmRepo = _FailingLlmRepository();
      final failingNotifier = SettingsNotifier(settingsRepo, failingLlmRepo);

      final config = LlmProviderConfig(
        type: LlmProviderType.openai,
        apiKey: 'bad-key',
        model: 'nonexistent',
      );

      final result = await failingNotifier.connect(config);

      expect(result, isFalse);

      failingLlmRepo.dispose();
    });

    test('loadSettings_readsFromRepository', () async {
      await settingsRepo.setTemperature(0.3);
      await settingsRepo.setMaxTokens(2048);

      await notifier.loadSettings();

      expect(notifier.state.temperature, 0.3);
      expect(notifier.state.maxTokens, 2048);
    });

    test('disconnect_clearsProviderConfig', () async {
      final config = LlmProviderConfig(
        type: LlmProviderType.openai,
        apiKey: 'test-key',
        model: 'gpt-4o',
      );

      await notifier.connect(config);
      expect(notifier.state.providerConfig, isNotNull);

      await notifier.disconnect();
      expect(notifier.state.providerConfig, isNull);
    });

    test('testConnection_delegatesToRepository', () async {
      final config = LlmProviderConfig(
        type: LlmProviderType.openai,
        apiKey: 'test-key',
        model: 'gpt-4o',
      );

      final result = await notifier.testConnection(config);
      expect(result, isTrue);
    });

    group('onboarding', () {
      test('completeOnboarding_persistsAndUpdatesState', () async {
        expect(notifier.state.onboardingCompleted, isFalse);

        await notifier.completeOnboarding();

        expect(notifier.state.onboardingCompleted, isTrue);
        expect(settingsRepo.onboardingCompleted, isTrue);
      });
    });
  });
}
