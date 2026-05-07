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
    test('execute_defaultMaxCount_invokesGetNotifications', () async {
      await tool.execute('{}', mockContext);
      expect(mockContext.methodCalls.last.method, 'getNotifications');
      expect(
        (mockContext.methodCalls.last.arguments as Map)['max_count'],
        20,
      );
    });

    test('execute_customMaxCount_passesMaxCount', () async {
      await tool.execute('{"max_count": 10}', mockContext);
      expect(
        (mockContext.methodCalls.last.arguments as Map)['max_count'],
        10,
      );
    });
  });

  group('execute_errorHandling', () {
    test('execute_nullResult_returnsNoNotifications', () async {
      mockContext.setInvokeResult(null);
      final result = await tool.execute('{}', mockContext);
      expect(result, 'No notifications');
    });

    test('execute_platformException_returnsErrorString', () async {
      mockContext.onInvokeMethod = (_, __) => throw Exception('fail');
      final result = await tool.execute('{}', mockContext);
      expect(result, contains('Error:'));
    });
  });

  group('execute_malformedInput', () {
    test('execute_malformedJson_usesDefaults', () async {
      final result = await tool.execute('not json', mockContext);
      expect(
        (mockContext.methodCalls.last.arguments as Map)['max_count'],
        20,
      );
      expect(result, isNot(contains('Error')));
    });
  });

  group('name_andMetadata', () {
    test('name_returnsNotificationReader', () {
      expect(tool.name, 'notification_reader');
    });

    test('description_isNotEmpty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });
  });
}
