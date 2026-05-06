import 'package:aios/agent/tools/notification_tool.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tool_context.dart';

void main() {
  late NotificationTool tool;
  late MockToolContext mockContext;

  setUp(() {
    tool = NotificationTool();
    mockContext = MockToolContext()
      ..setInvokeResult(
        '[{"app": "Messages", "title": "Hi", "text": "Hello"}]',
      );
  });

  group('execute_happyPath', () {
    test('reads notifications with default max_count', () async {
      await tool.execute('{}', mockContext);
      expect(mockContext.methodCalls.last.method, 'getNotifications');
      expect(
        (mockContext.methodCalls.last.arguments as Map)['max_count'],
        20,
      );
    });

    test('reads notifications with custom max_count', () async {
      await tool.execute('{"max_count": 10}', mockContext);
      expect(
        (mockContext.methodCalls.last.arguments as Map)['max_count'],
        10,
      );
    });
  });

  group('execute_errorHandling', () {
    test('null result returns no notifications', () async {
      mockContext.setInvokeResult(null);
      final result = await tool.execute('{}', mockContext);
      expect(result, 'No notifications');
    });

    test('platform exception returns error string', () async {
      mockContext.onInvokeMethod = (_, __) => throw Exception('fail');
      final result = await tool.execute('{}', mockContext);
      expect(result, contains('Error:'));
    });
  });

  group('execute_malformedInput', () {
    test('malformed JSON uses defaults', () async {
      final result = await tool.execute('not json', mockContext);
      expect(
        (mockContext.methodCalls.last.arguments as Map)['max_count'],
        20,
      );
      expect(result, isNot(contains('Error')));
    });
  });

  group('name_andMetadata', () {
    test('name is notification_reader', () {
      expect(tool.name, 'notification_reader');
    });

    test('description is not empty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });
  });
}
