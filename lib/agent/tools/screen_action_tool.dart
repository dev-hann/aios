import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:aios/domain/agent/tool_json_parser.dart';
import 'package:aios/domain/agent/tool_result.dart';

double _doubleOr(dynamic value, double defaultValue) {
  return parseDoubleDynamic(value) ?? defaultValue;
}

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
      '"submit": "boolean (optional, auto enter after typing, e.g. true)", '
      '"x": "float (for tap)", "y": "float (for tap)", '
      '"direction": "up|down|left|right (for scroll/swipe)", '
      '"start_x": "float (for swipe, default 540)", '
      '"start_y": "float (for swipe, default 1500)", '
      '"distance": "float (for swipe, default 500)", '
      '"global_action": '
      '"back|home|recents|notifications|quick_settings|enter"}';

  @override
  String get toolPrompt =>
      'Control the device screen.\n\n'
      'Actions:\n'
      '- tap: Tap on element by text or coordinates\n'
      '- long_click: Long press on element by text\n'
      '- type: Type text into input field\n'
      '- scroll: Scroll in a direction\n'
      '- swipe: Swipe with direction and distance\n'
      '- global: System action (back, home, recents, enter)\n\n'
      'Parameters: $parameters\n\n'
      'Rules:\n'
      '- Prefer tap with "text" over coordinates\n'
      '- Use "target" in type to specify field\n'
      '- Use global for navigation (back, home, recents)\n'
      '- For scroll/swipe, use direction: up|down|left|right\n'
      '- type with submit=true combines type + enter in one call\n'
      '- For search: tap search field → type query with submit=true\n'
      '- If submit is not set, you MUST call global_action "enter" '
      'separately to submit search';

  @override
  Future<ToolResult> execute(String args, ToolContext toolContext) async {
    try {
      final json = tryParseToolJson(args, _tag);
      final action = json['action']?.toString().toLowerCase() ?? '';

      final result = await switch (action) {
        'tap' => _handleTap(json, toolContext),
        'long_click' => _handleLongClick(json, toolContext),
        'type' => _handleType(json, toolContext),
        'scroll' => _handleScroll(json, toolContext),
        'swipe' => _handleSwipe(json, toolContext),
        'global' => _handleGlobal(json, toolContext),
        _ => Future.value(
          ToolResult.err(
            "Unknown action '$action'. "
            'Use tap, long_click, type, scroll, swipe, or global.',
          ),
        ),
      };

      if (result.isError) return result;

      final observation = await _observeScreen(toolContext);
      return ToolResult(
        output: result.output,
        system: result.system,
        observation: observation,
      );
    } on Object catch (e) {
      return ToolResult.err('$e');
    }
  }

  Future<String?> _observeScreen(ToolContext toolContext) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return await toolContext.invokeMethod('getScreenText');
    } on Object {
      return null;
    }
  }

  Future<ToolResult> _handleTap(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final text = json['text']?.toString() ?? '';
    if (text.isNotEmpty) {
      final result = await toolContext.invokeMethod('tapByText', {
        'text': text,
      });
      if (result == null) {
        return const ToolResult.err(
          'tap by text failed - no response from platform',
        );
      }
      return ToolResult.ok(result);
    }
    final x = _doubleOr(json['x'], -1);
    final y = _doubleOr(json['y'], -1);
    if (x >= 0 && y >= 0) {
      final result = await toolContext.invokeMethod('performTap', {
        'x': x,
        'y': y,
      });
      if (result == null) {
        return const ToolResult.err(
          'tap by coordinates failed - no response from platform',
        );
      }
      return ToolResult.ok(result);
    }
    return const ToolResult.err("'text' required");
  }

  Future<ToolResult> _handleLongClick(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final text = json['text']?.toString() ?? '';
    if (text.isEmpty) return const ToolResult.err("'text' required");
    final result = await toolContext.invokeMethod('longClickByText', {
      'text': text,
    });
    if (result == null) {
      return const ToolResult.err(
        'long click failed - no response from platform',
      );
    }
    return ToolResult.ok(result);
  }

  Future<ToolResult> _handleType(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final content = json['content']?.toString() ?? '';
    if (content.isEmpty) return const ToolResult.err("'content' required");
    final target = json['target']?.toString() ?? '';
    final result = await toolContext.invokeMethod('typeText', {
      'content': content,
      'target': target,
    });
    if (result == null) {
      return const ToolResult.err(
        'type text failed - no response from platform',
      );
    }

    final submit = json['submit']?.toString().toLowerCase() == 'true';
    if (submit) {
      await toolContext.invokeMethod('performGlobalAction', {
        'action': 'enter',
      });
      return ToolResult.ok(
        "Typed '$content' and pressed enter.",
        system: 'Search submitted.',
      );
    }

    return ToolResult.ok(
      result,
      system:
          'If this was a search field, call global_action "enter" '
          'to submit, or use submit=true next time.',
    );
  }

  Future<ToolResult> _handleScroll(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final direction = json['direction']?.toString() ?? 'forward';
    final result = await toolContext.invokeMethod('scroll', {
      'direction': direction,
    });
    if (result == null) {
      return const ToolResult.err('scroll failed - no response from platform');
    }
    return ToolResult.ok(result);
  }

  Future<ToolResult> _handleSwipe(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final direction = json['direction']?.toString() ?? 'up';
    final result = await toolContext.invokeMethod('swipe', {
      'direction': direction,
      'start_x': _doubleOr(json['start_x'], 540),
      'start_y': _doubleOr(json['start_y'], 1500),
      'distance': _doubleOr(json['distance'], 500),
    });
    if (result == null) {
      return const ToolResult.err('swipe failed - no response from platform');
    }
    return ToolResult.ok(result);
  }

  Future<ToolResult> _handleGlobal(
    Map<String, dynamic> json,
    ToolContext toolContext,
  ) async {
    final action = json['global_action']?.toString() ?? '';
    if (action.isEmpty) {
      return const ToolResult.err("'global_action' required");
    }
    final result = await toolContext.invokeMethod('performGlobalAction', {
      'action': action,
    });
    if (result == null) {
      return const ToolResult.err(
        'global action failed - no response from platform',
      );
    }
    return ToolResult.ok(result);
  }
}
