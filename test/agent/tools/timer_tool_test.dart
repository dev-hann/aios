import 'package:aios/agent/tools/timer_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TimerTool tool;

  setUp(() {
    tool = TimerTool();
  });

  group('execute_validSeconds', () {
    test('valid seconds returns timer message', () {
      final result = tool.execute('{"seconds": 5}');
      expect(result.contains('5'), isTrue);
      expect(result.startsWith('Error:'), isFalse);
    });

    test('minimum boundary 1 second works', () {
      final result = tool.execute('{"seconds": 1}');
      expect(result.startsWith('Error:'), isFalse);
    });

    test('maximum boundary 300 seconds works', () {
      final result = tool.execute('{"seconds": 300}');
      expect(result.startsWith('Error:'), isFalse);
    });
  });

  group('execute_invalidSeconds', () {
    test('zero seconds returns error', () {
      final result = tool.execute('{"seconds": 0}');
      expect(result, 'Error: seconds must be 1-300');
    });

    test('negative seconds returns error', () {
      final result = tool.execute('{"seconds": -1}');
      expect(result, 'Error: seconds must be 1-300');
    });

    test('over 300 seconds returns error', () {
      final result = tool.execute('{"seconds": 301}');
      expect(result, 'Error: seconds must be 1-300');
    });

    test('missing seconds defaults to 0 and returns error', () {
      final result = tool.execute('{}');
      expect(result, 'Error: seconds must be 1-300');
    });
  });

  group('execute_malformedInput', () {
    test('malformed JSON returns error', () {
      final result = tool.execute('not json');
      expect(result.startsWith('Error:'), isTrue);
    });
  });

  group('name_andMetadata', () {
    test('name is timer', () {
      expect(tool.name, 'timer');
    });

    test('description is not empty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });
  });
}
