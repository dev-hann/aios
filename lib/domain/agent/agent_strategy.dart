import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/entities/agent_models.dart';

abstract class AgentStrategy {
  Future<AgentResult> execute(
    String prompt, {
    int maxIterations = 8,
    int maxTokens = 512,
    void Function(AgentStep)? onStep,
  });

  Future<void> warmup();

  void cancel();

  void resolveConfirmation({required bool approved});

  void resolvePermission({required bool granted});

  void setPermissionChecker(
    Future<bool> Function(String permissionKey)? checker,
  );

  String getToolManifest();

  List<({String role, String content})> getConversationHistory();

  void clearHistory();

  void setConversationContext(ConversationContext? context);

  void setToolPreferenceTracker(ToolPreferenceTracker? tracker);
}
