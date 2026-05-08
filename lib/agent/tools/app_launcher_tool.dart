import 'dart:convert';

import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:flutter/foundation.dart';
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
      'Open apps or URLs.\n\n'
      'Actions:\n'
      '- open_app: Open app (prefer for app names)\n'
      '- open_url: Open URL (ONLY for http/https links)\n'
      '- list_apps: List apps (when app not found)\n\n'
      'Parameters: {"action": "open_app|open_url|list_apps", '
      '"package_name": "string", "url": "string", '
      '"query": "string"}\n\n'
      'Rules:\n'
      '- Find package_name from the Installed apps list\n'
      '- NEVER use open_url for app names\n'
      '- NEVER guess package_name';

  @override
  Future<String?> phaseContext(
    String args,
    ToolContext toolContext,
  ) async {
    final query = _extractAppQuery(args);
    final result = await _listApps({'query': query});
    if (query.isNotEmpty && result.startsWith('No apps')) {
      return _listApps({'query': ''});
    }
    return result;
  }

  String _extractAppQuery(String prompt) {
    final lower = prompt.toLowerCase();
    final patterns = [
      RegExp(r'(?:open|launch|start|run)\s+(\w+)'),
      RegExp(r'(?:열어|실행|시작|켜)\s*(\S+)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(lower);
      if (m != null) return m.group(1)!;
    }
    return '';
  }

  @visibleForTesting
  String testExtractAppQuery(String prompt) => _extractAppQuery(prompt);

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
    print('[$_tag] openApp: package="$packageName"');
    if (packageName.isEmpty) return "Error: 'package_name' required";

    final result = await toolContext.invokeMethod(
          'openApp',
          {'package_name': packageName},
        ) ??
        'Error';
    print('[$_tag] openApp result: $result');
    return result;
  }

  Future<bool> _packageExists(String packageName) async {
    try {
      final info = await InstalledApps.getAppInfo(packageName);
      return info != null;
    } on Object catch (e) {
      print('[$_tag] WARN: Package check error: $e');
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
    print('[$_tag] listApps: query="$query"');
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
      print('[$_tag] WARN: Invalid JSON type: ${decoded.runtimeType}');
      return {};
    } on Object catch (e) {
      print('[$_tag] WARN: JSON parse error: $e');
      return {};
    }
  }
}
