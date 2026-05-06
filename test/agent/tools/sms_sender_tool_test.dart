import 'package:aios/agent/tools/sms_sender_tool.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tool_context.dart';

void main() {
  late SmsSenderTool tool;
  late MockToolContext mockContext;

  setUp(() {
    tool = SmsSenderTool();
    mockContext = MockToolContext()
      ..setInvokeResult('OK');
  });

  group('execute_send', () {
    test('send with to and body invokes sendSms', () async {
      await tool.execute(
          '{"action": "send", "to": "01012345678", "body": "Hello"}',
          mockContext);
      expect(mockContext.methodCalls.last.method, 'sendSms');
      expect(
        mockContext.methodCalls.last.arguments,
        {'to': '01012345678', 'body': 'Hello'},
      );
    });

    test('send without to returns error', () async {
      final result = await tool.execute(
        '{"action": "send", "body": "Hello"}',
        mockContext,
      );
      expect(result, contains("'to' required"));
    });

    test('send without body returns error', () async {
      final result = await tool.execute(
          '{"action": "send", "to": "01012345678"}', mockContext);
      expect(result, contains("'body' required"));
    });

    test('send with empty to after trim returns error', () async {
      final result = await tool.execute(
          '{"action": "send", "to": "  ", "body": "Hello"}', mockContext);
      expect(result, contains("'to' required"));
    });
  });

  group('execute_read', () {
    test('read with default limit invokes readSms', () async {
      await tool.execute('{"action": "read"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'readSms');
      expect(
        (mockContext.methodCalls.last.arguments as Map)['limit'],
        10,
      );
    });

    test('read with custom limit passes limit', () async {
      await tool.execute('{"action": "read", "limit": 20}', mockContext);
      expect(
        (mockContext.methodCalls.last.arguments as Map)['limit'],
        20,
      );
    });
  });

  group('execute_unknownAction', () {
    test('unknown action returns error', () async {
      final result =
          await tool.execute('{"action": "unknown"}', mockContext);
      expect(result, contains("Error: Unknown action 'unknown'"));
    });

    test('empty action returns error', () async {
      final result = await tool.execute('{}', mockContext);
      expect(result, contains('Error: Unknown action'));
    });
  });

  group('execute_caseInsensitive', () {
    test('SEND is treated as send', () async {
      await tool.execute(
          '{"action": "SEND", "to": "010", "body": "hi"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'sendSms');
    });
  });

  group('execute_malformedInput', () {
    test('malformed JSON returns error', () async {
      final result = await tool.execute('not json', mockContext);
      expect(result, contains('Error: Unknown action'));
    });
  });

  group('name_andMetadata', () {
    test('name is sms_sender', () {
      expect(tool.name, 'sms_sender');
    });

    test('description is not empty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });
  });
}
