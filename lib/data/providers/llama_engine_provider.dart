import 'package:aios/domain/entities/chat_message.dart';

abstract class LlamaEngineProvider {
  Future<bool> loadModel(String path, {int? contextSize});

  Future<void> releaseModel();

  bool get isModelLoaded;

  String getModelInfo();

  String getContextUsage();

  Stream<String> generate(
    List<ChatMessage> history,
    String userMessage, {
    double? temperature,
    int? maxTokens,
    int? topK,
    double? topP,
    double? repeatPenalty,
    String? grammar,
  });

  Future<void> stopGeneration();

  Future<void> saveState(String path);

  Future<void> loadState(String path);
}
