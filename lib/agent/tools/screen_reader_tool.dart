import 'dart:convert';
import 'dart:developer' as developer;

import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';

class ScreenReaderTool extends ExtendedTool {
  @override
  String get name => 'screen_reader';

  @override
  String get description =>
      'Read all visible text on screen. Args: {}';

  @override
  String get parameters => '{}';

  @override
  Future<String> execute(String args, ToolContext toolContext) async {
    try {
      final result = await toolContext.invokeMethod('getScreenText');
      return result ?? 'Error: No result';
    } on Object catch (e) {
      return 'Error: $e';
    }
  }
}

class ScreenFindTool extends ExtendedTool {
  static const _tag = 'AIOS-ScreenFind';

  @override
  String get name => 'screen_find';

  @override
  String get description =>
      'Find UI elements by text. Args: {text}';

  @override
  String get parameters =>
      '{"text": "string, text to search for on screen"}';

  @override
  Future<String> execute(String args, ToolContext toolContext) async {
    try {
      final text = _parseArg(args, 'text');
      if (text.isEmpty) return "Error: 'text' required";
      final result = await toolContext.invokeMethod(
        'findNodesByText',
        {'text': text},
      );
      return result ?? 'No elements found';
    } on Object catch (e) {
      return 'Error: $e';
    }
  }

  String _parseArg(String args, String key) {
    try {
      final decoded = jsonDecode(args);
      if (decoded is Map<String, dynamic>) {
        return decoded[key]?.toString() ?? '';
      }
      developer.log(
        'Invalid JSON type: ${decoded.runtimeType}',
        name: _tag,
        level: 900,
      );
      return '';
    } on Object catch (e) {
      developer.log(
        'JSON parse error: $e',
        name: _tag,
        level: 900,
      );
      return '';
    }
  }
}
