import 'package:aios/agent/tools/app_launcher_tool.dart';
import 'package:aios/agent/tools/notification_tool.dart';
import 'package:aios/agent/tools/phone_caller_tool.dart';
import 'package:aios/agent/tools/screen_action_tool.dart';
import 'package:aios/agent/tools/screen_reader_tool.dart';
import 'package:aios/agent/tools/sms_sender_tool.dart';
import 'package:aios/domain/agent/agent_strategy.dart';
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

  final extendedTools = <String, ExtendedTool>{
    'app_launcher': AppLauncherTool(),
    'screen_action': ScreenActionTool(),
    'screen_reader': ScreenReaderTool(),
    'screen_find': ScreenFindTool(),
    'notification_reader': NotificationTool(),
    'sms_sender': SmsSenderTool(),
    'phone_caller': PhoneCallerTool(),
  };

  return ReactStrategy(
    llmRepo,
    toolContext: toolContext,
    extendedTools: extendedTools,
  );
});
