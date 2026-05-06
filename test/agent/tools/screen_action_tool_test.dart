import 'package:aios/agent/tools/screen_action_tool.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tool_context.dart';

void main() {
  late ScreenActionTool tool;
  late MockToolContext mockContext;

  setUp(() {
    tool = ScreenActionTool();
    mockContext = MockToolContext()
      ..setInvokeResult('OK');
  });

  group('execute_tap', () {
    test('tap by text invokes tapByText', () async {
      await tool.execute('{"action": "tap", "text": "Button"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'tapByText');
      expect(mockContext.methodCalls.last.arguments, {'text': 'Button'});
    });

    test('tap by coordinates invokes performTap', () async {
      await tool.execute(
          '{"action": "tap", "x": 100, "y": 200}', mockContext);
      expect(mockContext.methodCalls.last.method, 'performTap');
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['x'], 100.0);
      expect(args['y'], 200.0);
    });

    test('tap with string coordinates parses correctly', () async {
      await tool.execute(
          '{"action": "tap", "x": "50", "y": "75"}', mockContext);
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['x'], 50.0);
      expect(args['y'], 75.0);
    });

    test('tap without text or coordinates returns error', () async {
      final result =
          await tool.execute('{"action": "tap"}', mockContext);
      expect(result, contains('Error'));
    });
  });

  group('execute_longClick', () {
    test('long_click with text invokes longClickByText', () async {
      await tool.execute(
          '{"action": "long_click", "text": "Item"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'longClickByText');
    });

    test('long_click without text returns error', () async {
      final result =
          await tool.execute('{"action": "long_click"}', mockContext);
      expect(result, contains("'text' required"));
    });
  });

  group('execute_type', () {
    test('type with content invokes typeText', () async {
      await tool.execute(
          '{"action": "type", "content": "hello"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'typeText');
      expect(
        (mockContext.methodCalls.last.arguments as Map)['content'],
        'hello',
      );
    });

    test('type without content returns error', () async {
      final result =
          await tool.execute('{"action": "type"}', mockContext);
      expect(result, contains("'content' required"));
    });

    test('type with target passes target', () async {
      await tool.execute(
          '{"action": "type", "content": "hi", "target": "field"}',
          mockContext);
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['target'], 'field');
      expect(args['content'], 'hi');
    });
  });

  group('execute_scroll', () {
    test('scroll invokes scroll method', () async {
      await tool.execute(
          '{"action": "scroll", "direction": "down"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'scroll');
      expect(
        (mockContext.methodCalls.last.arguments as Map)['direction'],
        'down',
      );
    });

    test('scroll without direction defaults to forward', () async {
      await tool.execute('{"action": "scroll"}', mockContext);
      expect(
        (mockContext.methodCalls.last.arguments as Map)['direction'],
        'forward',
      );
    });
  });

  group('execute_swipe', () {
    test('swipe invokes swipe method with direction', () async {
      await tool.execute(
          '{"action": "swipe", "direction": "up"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'swipe');
      expect(
        (mockContext.methodCalls.last.arguments as Map)['direction'],
        'up',
      );
    });

    test('swipe without direction defaults to up', () async {
      await tool.execute('{"action": "swipe"}', mockContext);
      expect(
        (mockContext.methodCalls.last.arguments as Map)['direction'],
        'up',
      );
    });
  });

  group('execute_global', () {
    test('global with action invokes performGlobalAction', () async {
      await tool.execute(
          '{"action": "global", "global_action": "back"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'performGlobalAction');
      expect(
        (mockContext.methodCalls.last.arguments as Map)['action'],
        'back',
      );
    });

    test('global without global_action returns error', () async {
      final result =
          await tool.execute('{"action": "global"}', mockContext);
      expect(result, contains("'global_action' required"));
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
    test('TAP is treated as tap', () async {
      await tool.execute('{"action": "TAP", "text": "Btn"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'tapByText');
    });
  });

  group('execute_malformedInput', () {
    test('malformed JSON returns error', () async {
      final result = await tool.execute('not json', mockContext);
      expect(result, contains('Error: Unknown action'));
    });
  });

  group('execute_nullResult', () {
    test('null invokeMethod result returns Error', () async {
      mockContext.setInvokeResult(null);
      final result = await tool.execute(
          '{"action": "tap", "text": "Btn"}', mockContext);
      expect(result, 'Error');
    });
  });

  group('name_andMetadata', () {
    test('name is screen_action', () {
      expect(tool.name, 'screen_action');
    });

    test('description is not empty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });
  });
}
