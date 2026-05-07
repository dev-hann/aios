import 'package:aios/agent/tools/notepad_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late NotePadTool tool;
  late Map<String, String> notes;

  setUp(() {
    notes = {};
    tool = NotePadTool(notes);
  });

  group('execute_save', () {
    test('execute_saveWithKeyAndValue_succeeds', () async {
      final result =
          await tool.execute('{"action": "save", "key": "test", "value": "hello"}');
      expect(result, "Saved note 'test'");
      expect(notes['test'], 'hello');
    });

    test('execute_saveWithoutKey_returnsError', () async {
      final result = await tool.execute('{"action": "save", "value": "hello"}');
      expect(result, "Error: 'key' required");
    });

    test('execute_saveOverwritesExistingNote_succeeds', () async {
      notes['test'] = 'old';
      await tool.execute(
          '{"action": "save", "key": "test", "value": "new"}');
      expect(notes['test'], 'new');
    });
  });

  group('execute_get', () {
    test('execute_getExistingNote_returnsValue', () async {
      notes['test'] = 'hello';
      final result = await tool.execute('{"action": "get", "key": "test"}');
      expect(result, 'hello');
    });

    test('execute_getNonExistentNote_returnsNotFound', () async {
      final result = await tool.execute('{"action": "get", "key": "missing"}');
      expect(result, "Note 'missing' not found");
    });
  });

  group('execute_list', () {
    test('execute_listEmptyNotes_returnsNoNotes', () async {
      final result = await tool.execute('{"action": "list"}');
      expect(result, 'No notes saved');
    });

    test('execute_listWithNotes_returnsFormattedList', () async {
      notes['a'] = 'alpha';
      notes['b'] = 'beta';
      final result = await tool.execute('{"action": "list"}');
      expect(result.contains('- a: alpha'), isTrue);
      expect(result.contains('- b: beta'), isTrue);
    });
  });

  group('execute_delete', () {
    test('execute_deleteExistingNote_succeeds', () async {
      notes['test'] = 'hello';
      final result = await tool.execute('{"action": "delete", "key": "test"}');
      expect(result, "Deleted note 'test'");
      expect(notes.containsKey('test'), isFalse);
    });

    test('execute_deleteNonExistentNote_returnsNotFound', () async {
      final result =
          await tool.execute('{"action": "delete", "key": "missing"}');
      expect(result, "Note 'missing' not found");
    });
  });

  group('execute_unknownAction', () {
    test('execute_unknownAction_returnsErrorWithAvailableActions', () async {
      final result = await tool.execute('{"action": "unknown"}');
      expect(result, contains("Error: Unknown action 'unknown'"));
      expect(result, contains('save'));
    });
  });

  group('execute_malformedInput', () {
    test('execute_malformedJson_returnsError', () async {
      final result = await tool.execute('not json');
      expect(result.startsWith('Error:'), isTrue);
    });
  });

  group('name_andMetadata', () {
    test('name_returnsNotepad', () async {
      expect(tool.name, 'notepad');
    });

    test('description_isNotEmpty', () async {
      expect(tool.description.isNotEmpty, isTrue);
    });
  });
}
