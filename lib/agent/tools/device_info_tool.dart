import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';

class DeviceInfoTool implements ExtendedTool {
  @override
  String get name => 'device_info';

  @override
  String get description =>
      'Get device info (model, OS, memory). Args: {}';

  @override
  String get parameters => '{}';

  @override
  Future<String> execute(String args, ToolContext toolContext) async {
    try {
      return await toolContext.invokeMethod('getDeviceInfo') ??
          'Error: No result';
    } on Object catch (e) {
      return 'Error: $e';
    }
  }
}
