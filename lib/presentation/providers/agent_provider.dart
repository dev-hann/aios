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
import 'package:aios/domain/agent/react_strategy.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final toolContextProvider = Provider<ToolContext>((ref) {
  throw UnimplementedError('toolContextProvider must be overridden');
});

final conversationContextProvider = Provider<ConversationContext>((ref) {
  return ConversationContext();
});

final toolPreferenceTrackerProvider =
    Provider<ToolPreferenceTracker>((ref) {
  return ToolPreferenceTracker();
});

final agentProvider = Provider<AgentStrategy>((ref) {
  final llmRepo = ref.watch(llmRepositoryProvider);
  final toolContext = ref.watch(toolContextProvider);
  final conversationContext =
      ref.watch(conversationContextProvider);
  final preferenceTracker =
      ref.watch(toolPreferenceTrackerProvider);
  final notes = <String, String>{};
  final timers = <String, TimerEntry>{};

  final basicTools = <String, AgentTool>{
    'calculator': CalculatorTool(),
    'notepad': NotePadTool(notes),
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

  final strategy = ReactStrategy(
    llmRepo,
    toolContext: toolContext,
    basicTools: basicTools,
    extendedTools: extendedTools,
  );

  strategy.setConversationContext(conversationContext);
  strategy.setToolPreferenceTracker(preferenceTracker);

  return strategy;
});
