import 'dart:convert';
import 'dart:developer' as developer;

import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:url_launcher/url_launcher.dart';

class AppLauncherTool extends ExtendedTool {
  static const _tag = 'AIOS-AppLauncher';

  @override
  String get name => 'app_launcher';

  @override
  String get description =>
      'Open app/URL or list installed apps. '
      'Args: {action, package_name, url, query}';

  @override
  String get parameters =>
      '{"action": "open_app|open_url|list_apps", '
      '"package_name": "string", '
      '"url": "string", "query": "string"}';

  @override
  String get toolPrompt =>
      'Open apps/URLs or list installed apps.\n\n'
      'Actions:\n'
      '- open_app: Open app by package_name\n'
      '- open_url: Open URL in browser\n'
      '- list_apps: List apps with optional query\n\n'
      'Parameters: {"action": "open_app|open_url|list_apps", '
      '"package_name": "string", "url": "string", '
      '"query": "string"}\n\n'
      'Rules: Use exact package_name from app list. '
      'Never guess or invent a package_name.';

  @override
  Future<String?> phaseContext(
    String args,
    ToolContext toolContext,
  ) async {
    return _listApps({'query': ''});
  }

  @override
  Future<String?> validate(String args, ToolContext toolContext) async {
    final json = _tryParseJson(args);
    final action = json['action']?.toString().toLowerCase() ?? '';

    if (action != 'open_app') return null;

    final packageName = json['package_name']?.toString() ?? '';
    if (packageName.isEmpty) return "Error: 'package_name' required";

    final exists = await _packageExists(packageName);
    if (!exists) {
      return 'Error: Package "$packageName" is not installed. '
          'Call list_apps with a query to find the correct '
          'package_name.';
    }
    return null;
  }

  @override
  Future<String> execute(String args, ToolContext toolContext) async {
    try {
      final json = _tryParseJson(args);
      final action = json['action']?.toString().toLowerCase() ?? '';

      return switch (action) {
        'open_app' => _openApp(json, toolContext),
        'open_url' => _openUrl(json),
        'list_apps' => _listApps(json),
        _ => "Error: Unknown action '$action'. "
            'Use open_app, open_url, or list_apps.',
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
    developer.log('openApp: package="$packageName"', name: _tag);
    if (packageName.isEmpty) return "Error: 'package_name' required";

    final result = await toolContext.invokeMethod(
          'openApp',
          {'package_name': packageName},
        ) ??
        'Error';
    developer.log('openApp result: $result', name: _tag);
    return result;
  }

  Future<bool> _packageExists(String packageName) async {
    try {
      final info = await InstalledApps.getAppInfo(packageName);
      return info != null;
    } on Object catch (e) {
      developer.log(
        'Package check error: $e',
        name: _tag,
        level: 900,
      );
      return false;
    }
  }

  Future<String> _openUrl(Map<String, dynamic> json) async {
    final url = json['url']?.toString() ?? '';
    if (url.isEmpty) return "Error: 'url' required";
    final uri = Uri.tryParse(url);
    if (uri == null) return 'Error: Invalid URL';
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return 'Opened $url';
    }
    return 'Error: Cannot open URL';
  }

  Future<String> _listApps(Map<String, dynamic> json) async {
    final query = json['query']?.toString().toLowerCase() ?? '';
    developer.log('listApps: query="$query"', name: _tag);
    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        excludeNonLaunchableApps: true,
        withIcon: false,
      );
      if (apps == null || apps.isEmpty) return 'No apps found';

      var filtered = apps;
      if (query.isNotEmpty) {
        filtered = apps
            .where(
              (a) =>
                  a.name.toLowerCase().contains(query) ||
                  a.packageName.toLowerCase().contains(query),
            )
            .toList();
      }

      filtered.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      if (filtered.isEmpty) return "No apps found matching '$query'";

      final result = filtered.take(30).toList().asMap().entries.map(
        (e) => '${e.key + 1}. ${e.value.name} (${e.value.packageName})',
      ).join('\n');
      return result;
    } on Object catch (e) {
      return 'Error: $e';
    }
  }

  Map<String, dynamic> _tryParseJson(String args) {
    try {
      final decoded = json.decode(args);
      if (decoded is Map<String, dynamic>) return decoded;
      developer.log(
        'Invalid JSON type: ${decoded.runtimeType}',
        name: _tag,
        level: 900,
      );
      return {};
    } on Object catch (e) {
      developer.log(
        'JSON parse error: $e',
        name: _tag,
        level: 900,
      );
      return {};
    }
  }
}
