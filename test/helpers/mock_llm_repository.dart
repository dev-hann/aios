import 'dart:async';

import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/llm_repository.dart';

class MockLlmRepository implements LlmRepository {
  final _stateController = StreamController<ServiceState>.broadcast();
  bool connected = false;
  LlmProviderConfig? lastConfig;
  List<LlmModelInfo> modelsToReturn = [];
  bool connectResult = true;
  bool testResult = true;

  @override
  Stream<ServiceState> get state => _stateController.stream;

  @override
  Future<bool> connect(LlmProviderConfig config) async {
    lastConfig = config;
    connected = connectResult;
    if (connectResult) {
      _stateController.add(ServiceState.ready);
    } else {
      _stateController.add(ServiceState.error);
    }
    return connectResult;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
    _stateController.add(ServiceState.idle);
  }

  @override
  bool get isConnected => connected;

  @override
  Future<List<LlmModelInfo>> fetchModels(LlmProviderConfig config) async =>
      modelsToReturn;

  @override
  Future<bool> testConnection(LlmProviderConfig config) async => testResult;

  @override
  Future<void> stopGeneration() async {}

  @override
  Future<void> loadModel(String path, {int? contextSize}) async {}

  void emitState(ServiceState s) => _stateController.add(s);

  void dispose() {
    _stateController.close();
  }
}
