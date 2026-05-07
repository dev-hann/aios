import 'dart:convert';
import 'dart:developer' as developer;

import 'package:aios/domain/agent/agent_tool.dart';

class NotePadTool extends AgentTool {
  NotePadTool(this._notes);

  static const _tag = 'AIOS-NotepadTool';

  final Map<String, String> _notes;

  @override
  String get name => 'notepad';

  @override
  String get description =>
      'Save/get/list/delete notes. Args: {action, key, value}';

  @override
  String get parameters =>
      '{"action": "save|get|list|delete", "key": "string", '
      '"value": "string (for save)"}';

  @override
  Future<String> execute(String args) async {
    try {
      final json = _tryParseJson(args);
      final action = json['action']?.toString().toLowerCase() ?? '';
      return switch (action) {
        'save' => _save(json),
        'get' => _get(json),
        'list' => _list(),
        'delete' => _delete(json),
        _ => "Error: Unknown action '$action'. "
            'Use save, get, list, or delete.',
      };
    } on Object catch (e) {
      return 'Error: $e';
    }
  }

  String _save(Map<String, dynamic> json) {
    final key = json['key']?.toString() ?? '';
    final value = json['value']?.toString() ?? '';
    if (key.isEmpty) return "Error: 'key' required";
    _notes[key] = value;
    return "Saved note '$key'";
  }

  String _get(Map<String, dynamic> json) {
    final key = json['key']?.toString() ?? '';
    return _notes[key] ?? "Note '$key' not found";
  }

  String _list() {
    if (_notes.isEmpty) return 'No notes saved';
    return _notes.entries
        .map((e) => '- ${e.key}: ${e.value}')
        .join('\n');
  }

  String _delete(Map<String, dynamic> json) {
    final key = json['key']?.toString() ?? '';
    if (_notes.remove(key) != null) {
      return "Deleted note '$key'";
    }
    return "Note '$key' not found";
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
