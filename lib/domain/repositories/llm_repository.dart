import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/entities/service_state.dart';

abstract class LlmRepository {
  Stream<ServiceState> get state;

  Future<bool> connect(LlmProviderConfig config);
  Future<void> disconnect();
  bool get isConnected;

  Future<List<LlmModelInfo>> fetchModels(LlmProviderConfig config);
  Future<bool> testConnection(LlmProviderConfig config);

  Future<void> stopGeneration();

  Future<void> loadModel(String path, {int? contextSize});
}
