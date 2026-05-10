import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:aios/domain/agent/tool_json_parser.dart';
import 'package:aios/domain/agent/tool_result.dart';
import 'package:flutter/foundation.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:url_launcher/url_launcher.dart';

class AppLauncherTool extends ExtendedTool {
  static const _tag = 'AIOS-AppLauncher';

  List<AppInfo>? _appsCache;
  DateTime? _cacheTime;

  @override
  String get name => 'app_launcher';

  @override
  String get description =>
      'Open an app or URL. Args: {"target": "app name or URL"}';

  @override
  String get parameters => '{"target": "string (app name or URL)"}';

  @override
  String get toolPrompt =>
      'Open an app or URL.\n\n'
      'Parameter: {"target": "app name or URL"}\n\n'
      'Examples:\n'
      '- {"target": "youtube"} → opens YouTube app\n'
      '- {"target": "firefox"} → opens Firefox app\n'
      '- {"target": "https://google.com"} → opens browser\n'
      '- {"target": "naver.com"} → opens browser\n\n'
      'Rules:\n'
      '- Use app name for apps (e.g. "youtube", "카카오톡")\n'
      '- Use URL only for web pages (e.g. "https://google.com")';

  @override
  Future<String?> validate(String args, ToolContext toolContext) async {
    final json = tryParseToolJson(args, _tag);
    final target = json['target']?.toString() ?? '';
    if (target.isEmpty) return "Error: 'target' required";
    return null;
  }

  @override
  Future<ToolResult> execute(String args, ToolContext toolContext) async {
    try {
      final json = tryParseToolJson(args, _tag);
      final target = json['target']?.toString() ?? '';

      if (target.isEmpty) return const ToolResult.err("'target' required");

      if (_looksLikeUrl(target)) {
        return _openUrl(target);
      }

      return _openApp(target, toolContext);
    } on Object catch (e) {
      return ToolResult.err('$e');
    }
  }

  bool _looksLikeUrl(String s) {
    final lower = s.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return true;
    }
    return false;
  }

  @visibleForTesting
  bool testLooksLikeUrl(String s) => _looksLikeUrl(s);

  Future<ToolResult> _openApp(String input, ToolContext toolContext) async {
    print('[$_tag] openApp: input="$input"');

    var packageName = input;

    if (!input.contains('.')) {
      final resolved = await _resolveAppName(input);
      if (resolved == null) {
        final suggestions = await _searchApps(input);
        return ToolResult.err(
          "${Strings.agent.appNotFound(input)}\n$suggestions",
        );
      }
      if (resolved.startsWith('MULTIPLE_MATCH:')) {
        final candidates = resolved.substring('MULTIPLE_MATCH:'.length);
        return ToolResult.ok(
          Strings.agent.multipleAppsMatch(input, candidates),
        );
      }
      packageName = resolved;
      print('[$_tag] Resolved to: $packageName');
    }

    final result = await toolContext.invokeMethod('openApp', {
      'package_name': packageName,
    });
    return ToolResult.fromPlatformResult(result, 'app launch');
  }

  Future<String?> _resolveAppName(String name) async {
    final apps = await _getCachedApps();
    if (apps == null) return null;

    final query = name.toLowerCase().trim();

    final exact = apps.where((a) => a.name.toLowerCase() == query).toList();
    if (exact.length == 1) return exact.first.packageName;
    if (exact.length > 1) return _multiMatchResponse(exact);

    final startsWith = apps
        .where((a) => a.name.toLowerCase().startsWith(query))
        .toList();
    if (startsWith.length == 1) return startsWith.first.packageName;
    if (startsWith.length > 1) return _multiMatchResponse(startsWith);

    final contains = apps
        .where((a) => a.name.toLowerCase().contains(query))
        .toList();
    if (contains.length == 1) return contains.first.packageName;
    if (contains.length > 1) return _multiMatchResponse(contains);

    final pkgContains = apps
        .where((a) => a.packageName.toLowerCase().contains(query))
        .toList();
    if (pkgContains.length == 1) return pkgContains.first.packageName;
    if (pkgContains.length > 1) return _multiMatchResponse(pkgContains);

    return null;
  }

  String _multiMatchResponse(List<AppInfo> matches) {
    return 'MULTIPLE_MATCH:${_formatAppList(matches, max: 5)}';
  }

  Future<String> _searchApps(String query) async {
    final apps = await _getCachedApps();
    if (apps == null || apps.isEmpty) return 'No apps found';

    final q = query.toLowerCase();
    final filtered =
        apps
            .where(
              (a) =>
                  a.name.toLowerCase().contains(q) ||
                  a.packageName.toLowerCase().contains(q),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    if (filtered.isEmpty) return "No apps found matching '$query'";

    return _formatAppList(filtered, max: 10);
  }

  Future<List<AppInfo>?> _getCachedApps() async {
    if (_appsCache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < const Duration(minutes: 5)) {
      return _appsCache;
    }
    try {
      _appsCache = await InstalledApps.getInstalledApps();
      _cacheTime = DateTime.now();
      return _appsCache;
    } on Object catch (e) {
      print('[$_tag] WARN: getInstalledApps error: $e');
      return null;
    }
  }

  Future<ToolResult> _openUrl(String url) async {
    var finalUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      finalUrl = 'https://$url';
    }
    final uri = Uri.tryParse(finalUrl);
    if (uri == null) return const ToolResult.err('Invalid URL');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return ToolResult.ok('Opened $finalUrl');
    }
    return const ToolResult.err('Cannot open URL');
  }

  String _formatAppList(List<AppInfo> apps, {int max = 5}) {
    return apps
        .take(max)
        .toList()
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value.name} (${e.value.packageName})')
        .join('\n');
  }
}
