import 'dart:async';

import 'package:aios/data/providers/remote/openai_client.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/llm_repository.dart';

class LlmRepositoryImpl implements LlmRepository {
  final _stateController = StreamController<ServiceState>.broadcast(sync: true);

  static const _tag = 'AIOS-LlmRepo';

  @override
  Stream<ServiceState> get state => _stateController.stream;

  void _emitState(ServiceState s) {
    if (!_stateController.isClosed) _stateController.add(s);
  }

  @override
  Future<bool> connect(LlmProviderConfig config) async {
    _emitState(ServiceState.loadingModel);
    try {
      final client = OpenAiClient(config);
      final ok = await client.testConnection();
      if (ok) {
        _emitState(ServiceState.ready);
        print('[$_tag] Connected: ${config.model}@${config.effectiveBaseUrl}');
        return true;
      }
      _emitState(ServiceState.error);
      print('[$_tag] ERROR: Connection test failed');
      return false;
    } on Object catch (e) {
      _emitState(ServiceState.error);
      print('[$_tag] ERROR: connect failed - $e');
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _emitState(ServiceState.idle);
    print('[$_tag] Disconnected');
  }

  @override
  bool get isConnected =>
      !_stateController.isClosed && _stateController.hasListener;

  @override
  Future<List<LlmModelInfo>> fetchModels(LlmProviderConfig config) async {
    final client = OpenAiClient(config);
    return client.fetchModels();
  }

  @override
  Future<bool> testConnection(LlmProviderConfig config) async {
    final client = OpenAiClient(config);
    return client.testConnection();
  }

  @override
  Future<void> stopGeneration() async {
    print('[$_tag] Generation stop requested');
  }

  @override
  Future<void> loadModel(String path, {int? contextSize}) async {
    print('[AIOS-LlmRepo] loadModel: $path (remote, no-op)');
  }

  void dispose() {
    _stateController.close();
  }
}
