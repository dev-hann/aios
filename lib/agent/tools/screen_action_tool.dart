import 'dart:convert';

import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';

class ScreenActionTool extends ExtendedTool {
  static const _tag = 'AIOS-ScreenAction';

  @override
  String get name => 'screen_action';

  @override
  String get description =>
      'Screen actions: tap|long_click|type|scroll|swipe|global. '
      'Args: {action, text, content, target, x, y, direction, '
      'start_x, start_y, distance, global_action}';

  @override
  String get parameters =>
      '{"action": "tap|long_click|type|scroll|swipe|global", '
      '"text": "string (for tap/long_click)", '
      '"content": "string (for type)", '
      '"target": "string (optional field name for type)", '
      '"x": "float (for tap)", "y": "float (for tap)", '
      '"direction": "up|down|left|right (for scroll/swipe)", '
      '"start_x": "float (for swipe, default 540)", '
      '"start_y": "float (for swipe, default 1500)", '
      '"distance": "float (for swipe, default 500)", '
      '"global_action": '
      '"back|home|recents|notifications|quick_settings"}';

  @override
  String get toolPrompt =>
      'Control the device screen.\n\n'
      'Actions:\n'
      '- tap: Tap on element by text or coordinates\n'
      '- long_click: Long press on element by text\n'
      '- type: Type text into input field\n'
      '- scroll: Scroll in a direction\n'
      '- swipe: Swipe with direction and distance\n'
      '- global: System action (back, home, recents)\n\n'
      'Parameters: $parameters\n\n'
      'Rules:\n'
      '- Prefer tap with "text" over coordinates\n'
      '- Use "target" in type to specify field\n'
      '- Use global for navigation (back, home, recents)\n'
      '- For scroll/swipe, use direction: up|down|left|right';

  @override
  Future<String> execute(String args, ToolContext toolContext) async {
    try {
      final json = _tryParseJson(args);
      final action = json['action']?.toString().toLowerCase() ?? '';

      return switch (action) {
        'tap' => _handleTap(json, toolContext),
        'long_click' => _handleLongClick(json, toolContext),
        'type' => _handleType(json, toolContext),
        'scroll' => _handleScroll(json, toolContext),
        'swipe' => _handleSwipe(json, toolContext),
        'global' => _handleGlobal(json, toolContext),
        _ => "Error: Unknown action '$action'. "
            'Use tap, long_click, type, scroll, swipe, or global.',
      };
    } on Object catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> _handleTap(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final text = json['text']?.toString() ?? '';
    if (text.isNotEmpty) {
      return await toolContext.invokeMethod('tapByText', {'text': text}) ??
          'Error';
    }
    final x = _toDouble(json['x'], -1);
    final y = _toDouble(json['y'], -1);
    if (x >= 0 && y >= 0) {
      return await toolContext.invokeMethod('performTap', {
            'x': x,
            'y': y,
          }) ??
          'Error';
    }
    return "Error: 'text' required";
  }

  Future<String> _handleLongClick(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final text = json['text']?.toString() ?? '';
    if (text.isEmpty) return "Error: 'text' required";
    return await toolContext.invokeMethod(
          'longClickByText',
          {'text': text},
        ) ??
        'Error';
  }

  Future<String> _handleType(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final content = json['content']?.toString() ?? '';
    if (content.isEmpty) return "Error: 'content' required";
    final target = json['target']?.toString() ?? '';
    return await toolContext.invokeMethod('typeText', {
          'content': content,
          'target': target,
        }) ??
        'Error';
  }

  Future<String> _handleScroll(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final direction = json['direction']?.toString() ?? 'forward';
    return await toolContext.invokeMethod(
          'scroll',
          {'direction': direction},
        ) ??
        'Error';
  }

  Future<String> _handleSwipe(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final direction = json['direction']?.toString() ?? 'up';
    return await toolContext.invokeMethod('swipe', {
          'direction': direction,
          'start_x': _toDouble(json['start_x'], 540),
          'start_y': _toDouble(json['start_y'], 1500),
          'distance': _toDouble(json['distance'], 500),
        }) ??
        'Error';
  }

  Future<String> _handleGlobal(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final action = json['global_action']?.toString() ?? '';
    if (action.isEmpty) {
      return "Error: 'global_action' required";
    }
    return await toolContext.invokeMethod(
          'performGlobalAction',
          {'action': action},
        ) ??
        'Error';
  }

  double _toDouble(dynamic value, double defaultValue) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
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
