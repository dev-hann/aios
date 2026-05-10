import 'package:aios/agent/tools/notepad_tool.dart';
import 'mock_note_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late NotePadTool tool;
  late MockNoteRepository noteRepo;

  setUp(() {
    noteRepo = MockNoteRepository();
    tool = NotePadTool(noteRepo);
  });

  group('execute_save', () {
    test('execute_saveWithKeyAndValue_succeeds', () async {
      final result = await tool.execute(
        '{"action": "save", "key": "test", "value": "hello"}',
      );
      expect(result.output, "Saved note 'test'");
      expect(noteRepo['test'], 'hello');
    });

    test('execute_saveWithoutKey_returnsError', () async {
      final result = await tool.execute('{"action": "save", "value": "hello"}');
      expect(result.toContent(), "Error: 'key' required");
    });

    test('execute_saveOverwritesExistingNote_succeeds', () async {
      noteRepo.setNote('test', 'old');
      await tool.execute('{"action": "save", "key": "test", "value": "new"}');
      expect(noteRepo['test'], 'new');
    });
  });

  group('execute_get', () {
    test('execute_getExistingNote_returnsValue', () async {
      noteRepo.setNote('test', 'hello');
      final result = await tool.execute('{"action": "get", "key": "test"}');
      expect(result.output, 'hello');
    });

    test('execute_getNonExistentNote_returnsNotFound', () async {
      final result = await tool.execute('{"action": "get", "key": "missing"}');
      expect(result.output, "Note 'missing' not found");
    });
  });

  group('execute_list', () {
    test('execute_listEmptyNotes_returnsNoNotes', () async {
      final result = await tool.execute('{"action": "list"}');
      expect(result.output, 'No notes saved');
    });

    test('execute_listWithNotes_returnsFormattedList', () async {
      noteRepo.seed({'a': 'alpha', 'b': 'beta'});
      final result = await tool.execute('{"action": "list"}');
      expect(result.output!.contains('- a: alpha'), isTrue);
      expect(result.output!.contains('- b: beta'), isTrue);
    });
  });

  group('execute_delete', () {
    test('execute_deleteExistingNote_succeeds', () async {
      noteRepo.setNote('test', 'hello');
      final result = await tool.execute('{"action": "delete", "key": "test"}');
      expect(result.output, "Deleted note 'test'");
      expect(noteRepo.containsKey('test'), isFalse);
    });

    test('execute_deleteNonExistentNote_returnsNotFound', () async {
      final result = await tool.execute(
        '{"action": "delete", "key": "missing"}',
      );
      expect(result.output, "Note 'missing' not found");
    });
  });

  group('execute_unknownAction', () {
    test('execute_unknownAction_returnsErrorWithAvailableActions', () async {
      final result = await tool.execute('{"action": "unknown"}');
      expect(result.toContent(), contains("Error: Unknown action 'unknown'"));
      expect(result.toContent(), contains('save'));
    });
  });

  group('execute_malformedInput', () {
    test('execute_malformedJson_returnsError', () async {
      final result = await tool.execute('not json');
      expect(result.isError, isTrue);
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

  group('toolPrompt', () {
    test('toolPrompt_containsActionTypes', () async {
      expect(tool.toolPrompt, contains('save'));
      expect(tool.toolPrompt, contains('get'));
      expect(tool.toolPrompt, contains('list'));
      expect(tool.toolPrompt, contains('delete'));
    });

    test('toolPrompt_containsKeyRequirement', () async {
      expect(tool.toolPrompt, contains('key'));
    });

    test('toolPrompt_containsValueRequirement', () async {
      expect(tool.toolPrompt, contains('value'));
    });

    test('toolPrompt_containsParameters', () async {
      expect(tool.toolPrompt, contains('Parameters'));
    });
  });
}
