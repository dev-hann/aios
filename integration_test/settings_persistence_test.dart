import 'package:aios/data/repositories/settings_repository_impl.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsRepository integration', () {
    late SettingsRepositoryImpl repo;

    setUp(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      repo = SettingsRepositoryImpl();
      await repo.init();
    });

    group('defaults', () {
      testWidgets('all settings have correct defaults', (tester) async {
        expect(repo.maxTokens, SettingsRepository.defaultMaxTokens);
        expect(repo.temperature, SettingsRepository.defaultTemperature);
        expect(repo.topP, SettingsRepository.defaultTopP);
        expect(
          repo.agentMaxIterations,
          SettingsRepository.defaultAgentMaxIterations,
        );
        expect(repo.providerConfig, isNull);
      });
    });

    group('persistence', () {
      testWidgets('maxTokens persists across instances', (tester) async {
        await repo.setMaxTokens(1024);
        expect(repo.maxTokens, 1024);

        final repo2 = SettingsRepositoryImpl();
        await repo2.init();
        expect(repo2.maxTokens, 1024);
      });

      testWidgets('temperature persists across instances', (tester) async {
        await repo.setTemperature(0.5);
        expect(repo.temperature, 0.5);

        final repo2 = SettingsRepositoryImpl();
        await repo2.init();
        expect(repo2.temperature, 0.5);
      });

      testWidgets('topP persists across instances', (tester) async {
        await repo.setTopP(0.95);
        expect(repo.topP, 0.95);

        final repo2 = SettingsRepositoryImpl();
        await repo2.init();
        expect(repo2.topP, 0.95);
      });

      testWidgets('agentMaxIterations persists', (tester) async {
        await repo.setAgentMaxIterations(12);
        expect(repo.agentMaxIterations, 12);

        final repo2 = SettingsRepositoryImpl();
        await repo2.init();
        expect(repo2.agentMaxIterations, 12);
      });

      testWidgets('providerConfig persists and clears', (tester) async {
        await repo.setProviderConfig(
          '{"type":"openai","apiKey":"test","model":"gpt-4o"}',
        );
        expect(repo.providerConfig, isNotNull);

        final repo2 = SettingsRepositoryImpl();
        await repo2.init();
        expect(repo2.providerConfig, isNotNull);

        await repo2.clearProviderConfig();
        expect(repo2.providerConfig, isNull);

        final repo3 = SettingsRepositoryImpl();
        await repo3.init();
        expect(repo3.providerConfig, isNull);
      });

      testWidgets('all settings persist together', (tester) async {
        await repo.setMaxTokens(2048);
        await repo.setTemperature(1.0);
        await repo.setTopP(0.8);
        await repo.setAgentMaxIterations(5);
        await repo.setProviderConfig(
          '{"type":"openai","apiKey":"key","model":"gpt-4o"}',
        );

        final repo2 = SettingsRepositoryImpl();
        await repo2.init();

        expect(repo2.maxTokens, 2048);
        expect(repo2.temperature, 1.0);
        expect(repo2.topP, 0.8);
        expect(repo2.agentMaxIterations, 5);
        expect(repo2.providerConfig, isNotNull);
      });
    });
  });
}
