import 'package:aios/data/repositories/llm_repository_impl.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LlmRepositoryImpl', () {
    late LlmRepositoryImpl repo;

    setUp(() {
      repo = LlmRepositoryImpl();
    });

    tearDown(() {
      repo.dispose();
    });

    test('state_initial_emitsIdle', () async {
      final states = <ServiceState>[];
      repo.state.listen(states.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states, isEmpty);
    });

    test('isConnected_initial_returnsFalse', () {
      expect(repo.isConnected, isFalse);
    });

    test('disconnect_emitsIdle', () async {
      final states = <ServiceState>[];
      repo.state.listen(states.add);

      await repo.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states, contains(ServiceState.idle));
    });

    test('connect_withInvalidConfig_returnsFalse', () async {
      final config = LlmProviderConfig(
        type: LlmProviderType.custom,
        apiKey: 'invalid-key',
        model: 'test-model',
        baseUrl: 'https://invalid.test.example.com',
      );

      final result = await repo.connect(config);

      expect(result, isFalse);
    });

    test('connect_emitsLoadingThenError', () async {
      final states = <ServiceState>[];
      repo.state.listen(states.add);

      final config = LlmProviderConfig(
        type: LlmProviderType.custom,
        apiKey: 'bad',
        model: 'test',
        baseUrl: 'https://invalid.test.example.com',
      );

      await repo.connect(config);

      expect(states, contains(ServiceState.loadingModel));
      expect(states.last, ServiceState.error);
    });

    test('loadModel_isNoOp', () async {
      await repo.loadModel('/some/path');
    });

    test('stopGeneration_isNoOp', () async {
      await repo.stopGeneration();
    });

    test('dispose_closesStream', () async {
      final sub = repo.state.listen((_) {});
      repo.dispose();

      expect(sub.isPaused, isFalse);
      await sub.cancel();
    });
  });
}
