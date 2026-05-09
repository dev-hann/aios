import 'package:aios/agent/tools/phone_caller_tool.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tool_context.dart';

void main() {
  late PhoneCallerTool tool;
  late MockToolContext mockContext;

  setUp(() {
    tool = PhoneCallerTool();
    mockContext = MockToolContext()
      ..setInvokeResult('OK');
  });

  group('execute_happyPath', () {
    test('execute_callAction_invokesMakeCallWithCallAction', () async {
      await tool.execute(
          '{"action": "call", "number": "01012345678"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'makeCall');
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['action'], 'call');
      expect(args['number'], '01012345678');
    });

    test('execute_dialAction_invokesMakeCallWithDialAction', () async {
      await tool.execute(
          '{"action": "dial", "number": "01012345678"}', mockContext);
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['action'], 'dial');
    });

    test('execute_missingAction_defaultsToDial', () async {
      await tool.execute('{"number": "01012345678"}', mockContext);
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['action'], 'dial');
    });
  });

  group('execute_errorHandling', () {
    test('execute_missingNumber_returnsError', () async {
      final result = await tool.execute('{"action": "call"}', mockContext);
      expect(result, contains("'number' required"));
    });

    test('execute_emptyNumber_returnsError', () async {
      final result =
          await tool.execute('{"action": "call", "number": "  "}', mockContext);
      expect(result, contains("'number' required"));
    });
  });

  group('execute_malformedInput', () {
    test('execute_malformedJson_returnsError', () async {
      final result = await tool.execute('not json', mockContext);
      expect(result, contains("'number' required"));
    });
  });

  group('execute_nullResult', () {
    test('execute_nullResult_returnsError', () async {
      mockContext.setInvokeResult(null);
      final result = await tool.execute(
          '{"action": "call", "number": "010"}', mockContext);
      expect(result, contains('Error:'));
    });
  });

  group('name_andMetadata', () {
    test('name_returnsPhoneCaller', () {
      expect(tool.name, 'phone_caller');
    });

    test('description_isNotEmpty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });
  });

  group('toolPrompt', () {
    test('toolPrompt_containsActions', () {
      final prompt = tool.toolPrompt;
      expect(prompt, contains('call'));
      expect(prompt, contains('dial'));
    });

    test('toolPrompt_containsParameters', () {
      final prompt = tool.toolPrompt;
      expect(prompt, contains('action'));
      expect(prompt, contains('number'));
    });

    test('toolPrompt_isNotEmpty', () {
      expect(tool.toolPrompt.isNotEmpty, isTrue);
    });

    test('toolPrompt_containsRules', () {
      final prompt = tool.toolPrompt;
      expect(prompt, contains('Rules'));
    });
  });

  group('execute_caseInsensitive', () {
    test('execute_upperCaseCall_treatedAsCall', () async {
      await tool.execute(
          '{"action": "CALL", "number": "01012345678"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'makeCall');
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['action'], 'call');
    });

    test('execute_upperCaseDial_treatedAsDial', () async {
      await tool.execute(
          '{"action": "DIAL", "number": "01012345678"}', mockContext);
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['action'], 'dial');
    });
  });
}
