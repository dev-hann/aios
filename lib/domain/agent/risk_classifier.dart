import 'package:aios/domain/agent/tool_json_parser.dart';
import 'package:aios/domain/entities/agent_models.dart';

class RiskClassifier {
  static const _tag = 'AIOS-RiskClassifier';

  ToolRisk classify(String toolName, String args) {
    final json = tryParseToolJson(args, _tag);
    final action = json['action']?.toString().toLowerCase() ?? '';

    return switch (toolName) {
      'calculator' || 'timer' || 'device_info' || 'notepad' => ToolRisk.safe,
      'screen_reader' || 'screen_find' => ToolRisk.safe,
      'notification_reader' => ToolRisk.safe,
      'contact_search' => ToolRisk.safe,
      'app_launcher' => _classifyAppLauncher(action),
      'screen_action' => _classifyScreenAction(action, json),
      'sms_sender' => _classifySmsSender(action),
      'phone_caller' => _classifyPhoneCaller(action),
      _ => ToolRisk.high,
    };
  }

  ToolRisk _classifyAppLauncher(String action) => switch (action) {
    'open_settings' || 'list_apps' => ToolRisk.low,
    'open_app' || 'open_url' => ToolRisk.high,
    _ => ToolRisk.low,
  };

  ToolRisk _classifyScreenAction(String action, Map<String, dynamic> json) {
    if (action == 'global') return ToolRisk.low;
    if (action == 'type') {
      final content = json['content']?.toString().toLowerCase() ?? '';
      const sensitive = [
        'password',
        'pin',
        'passcode',
        'ssn',
        'social security',
        'credit card',
        'cvv',
        'otp',
      ];
      if (sensitive.any(content.contains)) {
        return ToolRisk.critical;
      }
      return ToolRisk.low;
    }
    if (['tap', 'long_click', 'scroll', 'swipe'].contains(action)) {
      return ToolRisk.low;
    }
    return ToolRisk.low;
  }

  ToolRisk _classifySmsSender(String action) => switch (action) {
    'send' => ToolRisk.critical,
    'read' => ToolRisk.high,
    _ => ToolRisk.high,
  };

  ToolRisk _classifyPhoneCaller(String action) => switch (action) {
    'call' => ToolRisk.critical,
    'dial' => ToolRisk.high,
    _ => ToolRisk.high,
  };
}
