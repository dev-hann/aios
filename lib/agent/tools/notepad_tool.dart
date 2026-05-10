import 'package:aios/domain/agent/agent_tool.dart';
import 'package:aios/domain/agent/tool_json_parser.dart';
import 'package:aios/domain/agent/tool_result.dart';
import 'package:aios/domain/repositories/note_repository.dart';

class NotePadTool extends AgentTool {
  NotePadTool(this._noteRepo);

  static const _tag = 'AIOS-NotepadTool';

  final NoteRepository _noteRepo;

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
  String get toolPrompt =>
      'Manage notes (save, get, list, delete).\n\n'
      'Parameters: $parameters\n\n'
      'Rules:\n'
      '- "action" is required: save, get, list, or delete\n'
      '- save: requires "key" and "value"\n'
      '- get: requires "key"\n'
      '- list: no additional params needed\n'
      '- delete: requires "key"\n'
      '- Respond with user language';

  @override
  Future<ToolResult> execute(String args) async {
    try {
      final json = tryParseToolJson(args, _tag);
      final action = json['action']?.toString().toLowerCase() ?? '';
      return switch (action) {
        'save' => await _save(json),
        'get' => await _get(json),
        'list' => await _list(),
        'delete' => await _delete(json),
        _ => ToolResult.err(
          "Unknown action '$action'. Use save, get, list, or delete.",
        ),
      };
    } on Object catch (e) {
      return ToolResult.err('$e');
    }
  }

  Future<ToolResult> _save(Map<String, dynamic> json) async {
    final key = json['key']?.toString() ?? '';
    final value = json['value']?.toString() ?? '';
    if (key.isEmpty) return const ToolResult.err("'key' required");
    await _noteRepo.save(key, value);
    return ToolResult.ok("Saved note '$key'");
  }

  Future<ToolResult> _get(Map<String, dynamic> json) async {
    final key = json['key']?.toString() ?? '';
    final value = await _noteRepo.get(key);
    if (value == null) return ToolResult.ok("Note '$key' not found");
    return ToolResult.ok(value);
  }

  Future<ToolResult> _list() async {
    final notes = await _noteRepo.getAll();
    if (notes.isEmpty) return const ToolResult.ok('No notes saved');
    return ToolResult.ok(
      notes.entries.map((e) => '- ${e.key}: ${e.value}').join('\n'),
    );
  }

  Future<ToolResult> _delete(Map<String, dynamic> json) async {
    final key = json['key']?.toString() ?? '';
    final deleted = await _noteRepo.delete(key);
    if (deleted) return ToolResult.ok("Deleted note '$key'");
    return ToolResult.ok("Note '$key' not found");
  }
}
