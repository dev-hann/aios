import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/service_state.dart';

abstract class LlmRepository {
  Stream<ServiceState> get state;
  Stream<String> get tokenStream;
  Stream<double> get loadProgress;

  Future<bool> loadModel(String path, {int? contextSize});
  Future<void> releaseModel();
  bool get isModelLoaded;
  String getModelInfo();
  String getContextUsage();
  Future<void> resetContext();

  Future<void> sendMessage(
    List<ChatMessage> history, {
    required String userMessage,
    double? temperature,
    int? maxTokens,
    int? topK,
    double? topP,
    double? repeatPenalty,
    String? grammar,
  });
  Future<void> stopGeneration();

  Future<void> saveSession(String path);
  Future<void> loadSession(String path);
}
