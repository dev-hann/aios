import 'package:aios/domain/agent/agent_tool.dart';

class DeviceInfoTool implements AgentTool {
  @override
  String get name => 'device_info';

  @override
  String get description =>
      'Get device info (model, OS, memory). Args: {}';

  @override
  String get parameters => '{}';

  @override
  String execute(String args) {
    return 'Error: device_info requires platform channel. '
        'Use ExtendedTool version.';
  }
}
