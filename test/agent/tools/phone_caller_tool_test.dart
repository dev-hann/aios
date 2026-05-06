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
    test('call action invokes makeCall with call action', () async {
      await tool.execute(
          '{"action": "call", "number": "01012345678"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'makeCall');
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['action'], 'call');
      expect(args['number'], '01012345678');
    });

    test('dial action invokes makeCall with dial action', () async {
      await tool.execute(
          '{"action": "dial", "number": "01012345678"}', mockContext);
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['action'], 'dial');
    });

    test('missing action defaults to dial', () async {
      await tool.execute('{"number": "01012345678"}', mockContext);
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['action'], 'dial');
    });
  });

  group('execute_errorHandling', () {
    test('missing number returns error', () async {
      final result = await tool.execute('{"action": "call"}', mockContext);
      expect(result, contains("'number' required"));
    });

    test('empty number after trim returns error', () async {
      final result =
          await tool.execute('{"action": "call", "number": "  "}', mockContext);
      expect(result, contains("'number' required"));
    });
  });

  group('execute_malformedInput', () {
    test('malformed JSON returns error', () async {
      final result = await tool.execute('not json', mockContext);
      expect(result, contains("'number' required"));
    });
  });

  group('execute_nullResult', () {
    test('null invokeMethod result returns Error', () async {
      mockContext.setInvokeResult(null);
      final result = await tool.execute(
          '{"action": "call", "number": "010"}', mockContext);
      expect(result, 'Error');
    });
  });

  group('name_andMetadata', () {
    test('name is phone_caller', () {
      expect(tool.name, 'phone_caller');
    });

    test('description is not empty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });
  });
}
