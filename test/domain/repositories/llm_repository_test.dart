import 'dart:async';

import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockLlmRepository implements LlmRepository {
  final _stateController = StreamController<ServiceState>.broadcast();

  bool connected = false;

  @override
  Stream<ServiceState> get state => _stateController.stream;

  @override
  Future<bool> connect(LlmProviderConfig config) async {
    connected = true;
    _stateController.add(ServiceState.ready);
    return true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
    _stateController.add(ServiceState.idle);
  }

  @override
  bool get isConnected => connected;

  @override
  Future<List<LlmModelInfo>> fetchModels(LlmProviderConfig config) async {
    return [const LlmModelInfo(id: 'gpt-4o', displayName: 'GPT-4o')];
  }

  @override
  Future<bool> testConnection(LlmProviderConfig config) async {
    return true;
  }

  @override
  Future<void> stopGeneration() async {}

  @override
  Future<void> loadModel(String path, {int? contextSize}) async {}

  void emitState(ServiceState s) => _stateController.add(s);

  void dispose() {
    _stateController.close();
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
