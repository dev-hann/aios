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
        '[{"package": "com.kakao.talk", "title": "홍길동", '
        '"text": "안녕하세요"}, {"package": "com.google.android.gm", '
        '"title": "Meeting", "text": "Tomorrow at 3pm"}]',
      );
  });

  group('execute_list', () {
    test('execute_listDefault_invokesGetNotifications', () async {
      await tool.execute('{"action": "list"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'getNotifications');
      expect((mockContext.methodCalls.last.arguments as Map)['max_count'], 20);
    });

    test('execute_listWithMaxCount_passesMaxCount', () async {
      await tool.execute('{"action": "list", "max_count": 5}', mockContext);
      expect((mockContext.methodCalls.last.arguments as Map)['max_count'], 5);
    });

    test('execute_listWithAppFilter_passesAppFilter', () async {
      await tool.execute('{"action": "list", "app": "kakao"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'getNotifications');
      expect((mockContext.methodCalls.last.arguments as Map)['app'], 'kakao');
    });
  });

  group('execute_read', () {
    test('execute_readWithApp_invokesGetNotificationsWithApp', () async {
      await tool.execute('{"action": "read", "app": "kakao"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'getNotifications');
      expect((mockContext.methodCalls.last.arguments as Map)['app'], 'kakao');
    });

    test('execute_readWithMaxCount_passesMaxCount', () async {
      await tool.execute(
        '{"action": "read", "app": "gmail", "max_count": 3}',
        mockContext,
      );
      expect((mockContext.methodCalls.last.arguments as Map)['max_count'], 3);
      expect((mockContext.methodCalls.last.arguments as Map)['app'], 'gmail');
    });
  });

  group('execute_defaultAction', () {
    test('execute_noAction_defaultsToList', () async {
      await tool.execute('{}', mockContext);
      expect(mockContext.methodCalls.last.method, 'getNotifications');
      expect((mockContext.methodCalls.last.arguments as Map)['max_count'], 20);
    });

    test('execute_emptyAction_defaultsToList', () async {
      await tool.execute('{"action": ""}', mockContext);
      expect(mockContext.methodCalls.last.method, 'getNotifications');
    });
  });

  group('execute_customMaxCount', () {
    test('execute_maxCountAsString_parsesCorrectly', () async {
      await tool.execute('{"max_count": "10"}', mockContext);
      expect((mockContext.methodCalls.last.arguments as Map)['max_count'], 10);
    });

    test('execute_maxCountAsStringInList_parsesCorrectly', () async {
      await tool.execute('{"action": "list", "max_count": "5"}', mockContext);
      expect((mockContext.methodCalls.last.arguments as Map)['max_count'], 5);
    });
  });

  group('execute_errorHandling', () {
    test('execute_nullResult_returnsNoNotifications', () async {
      mockContext.setInvokeResult(null);
      final result = await tool.execute('{}', mockContext);
      expect(result.output, 'No notifications');
    });

    test('execute_nullResultWithAppFilter_returnsNoNotifications', () async {
      mockContext.setInvokeResult(null);
      final result = await tool.execute('{"app": "kakao"}', mockContext);
      expect(result.output, 'No notifications');
    });

    test('execute_platformException_returnsErrorString', () async {
      mockContext.onInvokeMethod = (_, __) => throw Exception('fail');
      final result = await tool.execute('{}', mockContext);
      expect(result.toContent(), contains('Error:'));
    });
  });

  group('execute_malformedInput', () {
    test('execute_malformedJson_usesDefaults', () async {
      final result = await tool.execute('not json', mockContext);
      expect((mockContext.methodCalls.last.arguments as Map)['max_count'], 20);
      expect(result.toContent(), isNot(contains('Error')));
    });
  });

  group('execute_caseInsensitive', () {
    test('execute_upperCaseAction_treatedAsList', () async {
      await tool.execute('{"action": "LIST"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'getNotifications');
    });

    test('execute_mixedCaseAction_treatedAsRead', () async {
      await tool.execute('{"action": "Read", "app": "kakao"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'getNotifications');
      expect((mockContext.methodCalls.last.arguments as Map)['app'], 'kakao');
    });
  });

  group('toolPrompt', () {
    test('toolPrompt_containsActions', () {
      final prompt = tool.toolPrompt;
      expect(prompt, contains('list'));
      expect(prompt, contains('read'));
    });

    test('toolPrompt_containsParameters', () {
      final prompt = tool.toolPrompt;
      expect(prompt, contains('action'));
      expect(prompt, contains('app'));
      expect(prompt, contains('max_count'));
    });

    test('toolPrompt_isNotEmpty', () {
      expect(tool.toolPrompt.isNotEmpty, isTrue);
    });

    test('toolPrompt_containsRules', () {
      final prompt = tool.toolPrompt;
      expect(prompt, contains('Rules'));
    });
  });

  group('name_andMetadata', () {
    test('name_returnsNotificationReader', () {
      expect(tool.name, 'notification_reader');
    });

    test('description_isNotEmpty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });

    test('description_containsActionInfo', () {
      expect(tool.description, contains('action'));
    });

    test('parameters_isNotEmpty', () {
      expect(tool.parameters.isNotEmpty, isTrue);
    });
  });
}
