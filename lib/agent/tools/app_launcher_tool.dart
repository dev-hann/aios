import 'dart:convert';

import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';

class AppLauncherTool implements ExtendedTool {
  @override
  String get name => 'app_launcher';

  @override
  String get description =>
      'Open app/URL/settings or list apps. '
      'Args: {action, package_name, url, setting, query}';

  @override
  String get parameters =>
      '{"action": "open_app|open_url|open_settings|list_apps", '
      '"package_name": "string", "url": "string", '
      '"setting": "wifi|bluetooth|display|sound|battery|storage|about", '
      '"query": "string (for list_apps)"}';

  @override
  Future<String> execute(String args, ToolContext toolContext) async {
    try {
      final json = _tryParseJson(args);
      final action = json['action']?.toString().toLowerCase() ?? '';

      return switch (action) {
        'open_app' => _openApp(json, toolContext),
        'open_url' => _openUrl(json, toolContext),
        'open_settings' => _openSettings(json, toolContext),
        'list_apps' => _listApps(json, toolContext),
        _ => "Error: Unknown action '$action'. "
            'Use open_app, open_url, open_settings, or list_apps.',
      };
    } on Object catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> _openApp(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final packageName = json['package_name']?.toString() ?? '';
    if (packageName.isEmpty) return "Error: 'package_name' required";
    return await toolContext.invokeMethod(
          'openApp',
          {'package_name': packageName},
        ) ??
        'Error';
  }

  Future<String> _openUrl(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final url = json['url']?.toString() ?? '';
    if (url.isEmpty) return "Error: 'url' required";
    return await toolContext.invokeMethod(
          'openUrl',
          {'url': url},
        ) ??
        'Error';
  }

  Future<String> _openSettings(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final setting = json['setting']?.toString() ?? '';
    if (setting.isEmpty) return "Error: 'setting' required";
    return await toolContext.invokeMethod(
          'openSettings',
          {'setting': setting},
        ) ??
        'Error';
  }

  Future<String> _listApps(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final query = json['query']?.toString() ?? '';
    return await toolContext.invokeMethod(
          'listApps',
          {'query': query},
        ) ??
        'Error';
  }

  Map<String, dynamic> _tryParseJson(String args) {
    try {
      return json.decode(args) as Map<String, dynamic>;
    } on Object {
      return {};
    }
  }
}
