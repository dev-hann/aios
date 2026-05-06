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
    test('save with key and value succeeds', () {
      final result =
          tool.execute('{"action": "save", "key": "test", "value": "hello"}');
      expect(result, "Saved note 'test'");
      expect(notes['test'], 'hello');
    });

    test('save without key returns error', () {
      final result = tool.execute('{"action": "save", "value": "hello"}');
      expect(result, "Error: 'key' required");
    });

    test('save overwrites existing note', () {
      notes['test'] = 'old';
      tool.execute(
          '{"action": "save", "key": "test", "value": "new"}');
      expect(notes['test'], 'new');
    });
  });

  group('execute_get', () {
    test('get existing note returns value', () {
      notes['test'] = 'hello';
      final result = tool.execute('{"action": "get", "key": "test"}');
      expect(result, 'hello');
    });

    test('get non-existent note returns not found', () {
      final result = tool.execute('{"action": "get", "key": "missing"}');
      expect(result, "Note 'missing' not found");
    });
  });

  group('execute_list', () {
    test('list empty notes returns no notes', () {
      final result = tool.execute('{"action": "list"}');
      expect(result, 'No notes saved');
    });

    test('list with notes returns formatted list', () {
      notes['a'] = 'alpha';
      notes['b'] = 'beta';
      final result = tool.execute('{"action": "list"}');
      expect(result.contains('- a: alpha'), isTrue);
      expect(result.contains('- b: beta'), isTrue);
    });
  });

  group('execute_delete', () {
    test('delete existing note succeeds', () {
      notes['test'] = 'hello';
      final result = tool.execute('{"action": "delete", "key": "test"}');
      expect(result, "Deleted note 'test'");
      expect(notes.containsKey('test'), isFalse);
    });

    test('delete non-existent note returns not found', () {
      final result =
          tool.execute('{"action": "delete", "key": "missing"}');
      expect(result, "Note 'missing' not found");
    });
  });

  group('execute_unknownAction', () {
    test('unknown action returns error with available actions', () {
      final result = tool.execute('{"action": "unknown"}');
      expect(result, contains("Error: Unknown action 'unknown'"));
      expect(result, contains('save'));
    });
  });

  group('execute_malformedInput', () {
    test('malformed JSON returns error', () {
      final result = tool.execute('not json');
      expect(result.startsWith('Error:'), isTrue);
    });
  });

  group('name_andMetadata', () {
    test('name is notepad', () {
      expect(tool.name, 'notepad');
    });

    test('description is not empty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });
  });
}
