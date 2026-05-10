import 'dart:async';

import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import '../../helpers/mock_llm_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockLlmRepository extends MockLlmRepository {
  @override
  Future<List<LlmModelInfo>> fetchModels(LlmProviderConfig config) async {
    return [const LlmModelInfo(id: 'gpt-4o', displayName: 'GPT-4o')];
  }
}

void main() {
  group('LlmRepository', () {
    late _MockLlmRepository repository;

    setUp(() {
      repository = _MockLlmRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('connect_returnsTrue_and_setsConnected', () async {
      final config = LlmProviderConfig(
        type: LlmProviderType.openai,
        apiKey: 'test-key',
        model: 'gpt-4o',
      );

      final result = await repository.connect(config);

      expect(result, isTrue);
      expect(repository.isConnected, isTrue);
    });

    test('connect_emitsReadyState', () async {
      final states = <ServiceState>[];
      repository.state.listen(states.add);

      final config = LlmProviderConfig(
        type: LlmProviderType.openai,
        apiKey: 'test-key',
        model: 'gpt-4o',
      );
      await repository.connect(config);

      expect(states, contains(ServiceState.ready));
    });

    test('disconnect_setsNotConnected', () async {
      final config = LlmProviderConfig(
        type: LlmProviderType.openai,
        apiKey: 'test-key',
        model: 'gpt-4o',
      );
      await repository.connect(config);
      expect(repository.isConnected, isTrue);

      await repository.disconnect();

      expect(repository.isConnected, isFalse);
    });

    test('disconnect_emitsIdleState', () async {
      final states = <ServiceState>[];
      repository.state.listen(states.add);

      await repository.disconnect();

      expect(states, contains(ServiceState.idle));
    });

    test('testConnection_returnsTrue', () async {
      final config = LlmProviderConfig(
        type: LlmProviderType.openai,
        apiKey: 'test-key',
        model: 'gpt-4o',
      );

      final result = await repository.testConnection(config);

      expect(result, isTrue);
    });

    test('fetchModels_returnsList', () async {
      final config = LlmProviderConfig(
        type: LlmProviderType.openai,
        apiKey: 'test-key',
        model: 'gpt-4o',
      );

      final models = await repository.fetchModels(config);

      expect(models, isNotEmpty);
      expect(models.first.id, 'gpt-4o');
    });

    test('stopGeneration_completes', () async {
      await repository.stopGeneration();
    });
  });
}
