import 'dart:convert';

import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';

class DeviceInfoTool extends ExtendedTool {
  static const _tag = 'AIOS-DeviceInfoTool';

  @override
  String get name => 'device_info';

  @override
  String get description =>
      'Get device info (model, OS, battery, storage, memory). '
      'Args: {action}';

  @override
  String get parameters =>
      '{"action": "get_info|battery|storage|memory"}';

  @override
  String get toolPrompt =>
      'Get device info.\n\n'
      'Parameters: $parameters\n\n'
      'Actions:\n'
      '- get_info: model, manufacturer, Android version\n'
      '- battery: level (%) and charging status\n'
      '- storage: total/used/available (GB)\n'
      '- memory: JVM memory (MB)\n\n'
      'Rules:\n'
      '- "action" defaults to "get_info" if not specified';

  @override
  Future<String> execute(String args, ToolContext toolContext) async {
    try {
      final json = _tryParseJson(args);
      final action =
          json['action']?.toString().toLowerCase() ?? 'get_info';

      return await switch (action) {
        'get_info' => _invokeAndFormat(
            toolContext, 'getDeviceInfo', _formatDeviceInfo),
        'battery' => _invokeAndFormat(
            toolContext, 'getBatteryInfo', _formatBatteryInfo),
        'storage' => _invokeAndFormat(
            toolContext, 'getStorageInfo', _formatStorageInfo),
        'memory' => _invokeAndFormat(
            toolContext, 'getDeviceInfo', _formatMemoryInfo),
        _ => "Error: Unknown action '$action'. "
            "Use get_info, battery, storage, or memory.",
      };
    } on Object catch (e) {
      print('[$_tag] ERROR: $e');
      return 'Error: $e';
    }
  }

  Future<String> _invokeAndFormat(
    ToolContext ctx,
    String method,
    String Function(Map<String, dynamic>) formatter,
  ) async {
    final raw = await ctx.invokeMethod(method);
    if (raw == null) return 'Error: No result';
    final data = json.decode(raw) as Map<String, dynamic>;
    return formatter(data);
  }

  String _formatDeviceInfo(Map<String, dynamic> d) {
    return 'Device: ${d['manufacturer']} ${d['device']}\n'
        'Android: ${d['android_version']} (SDK ${d['sdk_int']})';
  }

  String _formatBatteryInfo(Map<String, dynamic> d) {
    final level = d['level'];
    final charging = d['charging'] == true ? 'Charging' : 'Not charging';
    return 'Battery: $level% ($charging)';
  }

  String _formatStorageInfo(Map<String, dynamic> d) {
    return 'Storage: ${d['used_gb']}GB / ${d['total_gb']}GB used '
        '(${d['usage_percent']}%), '
        '${d['available_gb']}GB available';
  }

  String _formatMemoryInfo(Map<String, dynamic> d) {
    return 'Memory (JVM): '
        '${d['jvm_total_mb']}MB used / ${d['jvm_max_mb']}MB max, '
        '${d['jvm_free_mb']}MB free';
  }

  Map<String, dynamic> _tryParseJson(String args) {
    try {
      final decoded = json.decode(args);
      if (decoded is Map<String, dynamic>) return decoded;
      print('[$_tag] WARN: Invalid JSON type: ${decoded.runtimeType}');
      return {};
    } on Object catch (e) {
      print('[$_tag] WARN: JSON parse error: $e');
      return {};
    }
  }
}
