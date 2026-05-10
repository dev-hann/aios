import 'package:aios/agent/tools/sms_sender_tool.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tool_context.dart';

void main() {
  late SmsSenderTool tool;
  late MockToolContext mockContext;

  setUp(() {
    tool = SmsSenderTool();
    mockContext = MockToolContext()..setInvokeResult('OK');
  });

  group('execute_send', () {
    test('execute_sendWithToAndBody_invokesSendSms', () async {
      await tool.execute(
        '{"action": "send", "to": "01012345678", "body": "Hello"}',
        mockContext,
      );
      expect(mockContext.methodCalls.last.method, 'sendSms');
      expect(mockContext.methodCalls.last.arguments, {
        'to': '01012345678',
        'body': 'Hello',
      });
    });

    test('execute_sendWithoutTo_returnsError', () async {
      final result = await tool.execute(
        '{"action": "send", "body": "Hello"}',
        mockContext,
      );
      expect(result.toContent(), contains("'to' required"));
    });

    test('execute_sendWithoutBody_returnsError', () async {
      final result = await tool.execute(
        '{"action": "send", "to": "01012345678"}',
        mockContext,
      );
      expect(result.toContent(), contains("'body' required"));
    });

    test('execute_sendWithEmptyTo_returnsError', () async {
      final result = await tool.execute(
        '{"action": "send", "to": "  ", "body": "Hello"}',
        mockContext,
      );
      expect(result.toContent(), contains("'to' required"));
    });
  });

  group('execute_read', () {
    test('execute_readWithDefaultLimit_invokesReadSms', () async {
      await tool.execute('{"action": "read"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'readSms');
      expect((mockContext.methodCalls.last.arguments as Map)['limit'], 10);
    });

    test('execute_readWithCustomLimit_passesLimit', () async {
      await tool.execute('{"action": "read", "limit": 20}', mockContext);
      expect((mockContext.methodCalls.last.arguments as Map)['limit'], 20);
    });
  });

  group('execute_unknownAction', () {
    test('execute_unknownAction_returnsError', () async {
      final result = await tool.execute('{"action": "unknown"}', mockContext);
      expect(result.toContent(), contains("Error: Unknown action 'unknown'"));
    });

    test('execute_emptyAction_returnsError', () async {
      final result = await tool.execute('{}', mockContext);
      expect(result.toContent(), contains('Error: Unknown action'));
    });
  });

  group('execute_caseInsensitive', () {
    test('execute_upperCaseSend_treatedAsSend', () async {
      await tool.execute(
        '{"action": "SEND", "to": "010", "body": "hi"}',
        mockContext,
      );
      expect(mockContext.methodCalls.last.method, 'sendSms');
    });
  });

  group('execute_malformedInput', () {
    test('execute_malformedJson_returnsError', () async {
      final result = await tool.execute('not json', mockContext);
      expect(result.toContent(), contains('Error: Unknown action'));
    });
  });

  group('toolPrompt', () {
    test('toolPrompt_containsActions', () {
      final prompt = tool.toolPrompt;
      expect(prompt, contains('send'));
      expect(prompt, contains('read'));
    });

    test('toolPrompt_containsParameters', () {
      final prompt = tool.toolPrompt;
      expect(prompt, contains('action'));
      expect(prompt, contains('to'));
      expect(prompt, contains('body'));
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
    test('name_returnsSmsSender', () {
      expect(tool.name, 'sms_sender');
    });

    test('description_isNotEmpty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });
  });
}
