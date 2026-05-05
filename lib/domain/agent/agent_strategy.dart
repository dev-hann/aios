import 'package:aios/domain/entities/agent_models.dart';

abstract class AgentStrategy {
  Future<AgentResult> execute(
    String prompt, {
    int maxIterations = 8,
    int maxTokens = 512,
    void Function(AgentStep)? onStep,
  });

  void cancel();

  void resolveConfirmation(bool approved);

  String getToolManifest();

  List<({String role, String content})> getConversationHistory();

  void clearHistory();
}
