import 'package:aios/agent/tools/app_launcher_tool.dart';
import 'package:aios/agent/tools/calculator_tool.dart';
import 'package:aios/agent/tools/contact_search_tool.dart';
import 'package:aios/agent/tools/device_info_tool.dart';
import 'package:aios/agent/tools/notepad_tool.dart';
import 'package:aios/agent/tools/notification_tool.dart';
import 'package:aios/agent/tools/phone_caller_tool.dart';
import 'package:aios/agent/tools/screen_action_tool.dart';
import 'package:aios/agent/tools/screen_reader_tool.dart';
import 'package:aios/agent/tools/sms_sender_tool.dart';
import 'package:aios/agent/tools/timer_tool.dart';
import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/agent/agent_tool.dart';
import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/llm_engine.dart';
import 'package:aios/domain/agent/react_strategy.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/repositories/note_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final toolContextProvider = Provider<ToolContext>((ref) {
  throw UnimplementedError('toolContextProvider must be overridden');
});

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  throw UnimplementedError('noteRepositoryProvider must be overridden');
});

final conversationContextProvider = Provider<ConversationContext>((ref) {
  return ConversationContext();
});

final toolPreferenceTrackerProvider = Provider<ToolPreferenceTracker>((ref) {
  return ToolPreferenceTracker();
});

final providerConfigProvider = StateProvider<LlmProviderConfig?>((ref) => null);

final agentEngineProvider = Provider<LlmEngine?>((ref) {
  throw UnimplementedError('agentEngineProvider must be overridden');
});

final modelLoadedPathProvider = StateProvider<String?>((ref) => null);

Future<bool> _defaultPermissionChecker(String permissionKey) async {
  switch (permissionKey) {
    case 'contacts':
      return Permission.contacts.status.isGranted;
    case 'phone':
      return Permission.phone.status.isGranted;
    case 'sms':
      return Permission.sms.status.isGranted;
    default:
      return true;
  }
}

final agentProvider = Provider<AgentStrategy>((ref) {
  final engine = ref.watch(agentEngineProvider);
  final toolContext = ref.watch(toolContextProvider);
  final conversationContext = ref.watch(conversationContextProvider);
  final preferenceTracker = ref.watch(toolPreferenceTrackerProvider);
  final noteRepo = ref.watch(noteRepositoryProvider);
  final timers = <String, TimerEntry>{};

  final basicTools = <String, AgentTool>{
    'calculator': CalculatorTool(),
    'notepad': NotePadTool(noteRepo),
    'timer': TimerTool(timers),
  };

  final extendedTools = <String, ExtendedTool>{
    'app_launcher': AppLauncherTool(),
    'screen_action': ScreenActionTool(),
    'screen_reader': ScreenReaderTool(),
    'screen_find': ScreenFindTool(),
    'notification_reader': NotificationTool(),
    'sms_sender': SmsSenderTool(),
    'phone_caller': PhoneCallerTool(),
    'contact_search': ContactSearchTool(),
    'device_info': DeviceInfoTool(),
  };

  if (engine == null) {
    return _PlaceholderStrategy();
  }

  final strategy = ReactStrategy(
    engine: engine,
    toolContext: toolContext,
    basicTools: basicTools,
    extendedTools: extendedTools,
  );

  strategy
    ..setPermissionChecker(_defaultPermissionChecker)
    ..setConversationContext(conversationContext)
    ..setToolPreferenceTracker(preferenceTracker);

  return strategy;
});

class _PlaceholderStrategy implements AgentStrategy {
  @override
  Future<AgentResult> execute(
    String prompt, {
    int maxIterations = 8,
    int maxTokens = 512,
    void Function(AgentStep)? onStep,
  }) async {
    return const AgentResult(
      steps: [const AgentStep('answer', 'API 설정을 먼저 완료해주세요.')],
      success: false,
    );
  }

  @override
  void cancel() {}

  @override
  Future<void> warmup() async {}

  @override
  void resolveConfirmation(bool approved) {}

  @override
  void resolvePermission(bool granted) {}

  @override
  void setPermissionChecker(
    Future<bool> Function(String permissionKey)? checker,
  ) {}

  @override
  String getToolManifest() => '';

  @override
  List<({String role, String content})> getConversationHistory() => [];

  @override
  void clearHistory() {}

  @override
  void setConversationContext(ConversationContext? context) {}

  @override
  void setToolPreferenceTracker(ToolPreferenceTracker? tracker) {}
}
