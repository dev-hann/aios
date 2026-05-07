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
import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/react_strategy.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final toolContextProvider = Provider<ToolContext>((ref) {
  throw UnimplementedError('toolContextProvider must be overridden');
});

final agentProvider = Provider<AgentStrategy>((ref) {
  final llmRepo = ref.watch(llmRepositoryProvider);
  final toolContext = ref.watch(toolContextProvider);

  final basicTools = <String, AgentTool>{
    'calculator': CalculatorTool(),
    'timer': TimerTool(),
    'notepad': NotePadTool({}),
  };

  final extendedTools = <String, ExtendedTool>{
    'device_info': DeviceInfoTool(),
    'screen_reader': ScreenReaderTool(),
    'screen_find': ScreenFindTool(),
    'screen_action': ScreenActionTool(),
    'phone_caller': PhoneCallerTool(),
    'notification_reader': NotificationTool(),
    'sms_sender': SmsSenderTool(),
    'contact_search': ContactSearchTool(),
    'app_launcher': AppLauncherTool(),
  };

  return ReactStrategy(
    llmRepo,
    toolContext: toolContext,
    basicTools: basicTools,
    extendedTools: extendedTools,
  );
});
