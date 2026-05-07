import 'dart:convert';

import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';

class ScreenReaderTool extends ExtendedTool {
  static const _tag = 'AIOS-ScreenReader';

  @override
  String get name => 'screen_reader';

  @override
  String get description =>
      'Read all visible text on screen. Args: {}';

  @override
  String get parameters => '{}';

  @override
  String get toolPrompt =>
      'Read the device screen.\n\n'
      'Actions:\n'
      '- Read all visible text on screen\n'
      '- Returns every text element currently displayed\n\n'
      'Parameters: {}\n\n'
      'Rules:\n'
      '- No arguments needed, just read the full screen\n'
      '- Use this when user asks what is on screen\n'
      '- Use screen_find to locate specific elements';

  @override
  Future<String> execute(String args, ToolContext toolContext) async {
    try {
      print('[$_tag] Reading screen text');
      final result = await toolContext.invokeMethod('getScreenText');
      if (result == null) {
        print('[$_tag] WARN: No result from getScreenText');
        return 'Error: No result';
      }
      print('[$_tag] Screen text length: ${result.length}');
      return result;
    } on Object catch (e) {
      print('[$_tag] ERROR: $e');
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
  String get toolPrompt =>
      'Find UI elements on the device screen.\n\n'
      'Actions:\n'
      '- Find UI elements by text content\n'
      '- Returns matching elements with bounds\n\n'
      'Parameters: {"text": "string, text to search for"}\n\n'
      'Rules:\n'
      '- text is required\n'
      '- Searches for elements containing the text\n'
      '- Returns text and bounds of matching elements';

  @override
  Future<String> execute(String args, ToolContext toolContext) async {
    try {
      final text = _parseArg(args, 'text');
      if (text.isEmpty) return "Error: 'text' required";
      print('[$_tag] Finding elements with text: "$text"');
      final result = await toolContext.invokeMethod(
        'findNodesByText',
        {'text': text},
      );
      if (result == null) {
        print('[$_tag] WARN: No elements found for "$text"');
        return 'No elements found';
      }
      print('[$_tag] Found elements for "$text": ${result.length} chars');
      return result;
    } on Object catch (e) {
      print('[$_tag] ERROR: $e');
      return 'Error: $e';
    }
  }

  String _parseArg(String args, String key) {
    try {
      final decoded = jsonDecode(args);
      if (decoded is Map<String, dynamic>) {
        return decoded[key]?.toString() ?? '';
      }
      print('[$_tag] WARN: Invalid JSON type: ${decoded.runtimeType}');
      return '';
    } on Object catch (e) {
      print('[$_tag] WARN: JSON parse error: $e');
      return '';
    }
  }
}
