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
    test('execute_tapByText_invokesTapByText', () async {
      await tool.execute('{"action": "tap", "text": "Button"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'tapByText');
      expect(mockContext.methodCalls.last.arguments, {'text': 'Button'});
    });

    test('execute_tapByCoordinates_invokesPerformTap', () async {
      await tool.execute(
          '{"action": "tap", "x": 100, "y": 200}', mockContext);
      expect(mockContext.methodCalls.last.method, 'performTap');
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['x'], 100.0);
      expect(args['y'], 200.0);
    });

    test('execute_tapWithStringCoordinates_parsesCorrectly', () async {
      await tool.execute(
          '{"action": "tap", "x": "50", "y": "75"}', mockContext);
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['x'], 50.0);
      expect(args['y'], 75.0);
    });

    test('execute_tapWithoutTarget_returnsError', () async {
      final result =
          await tool.execute('{"action": "tap"}', mockContext);
      expect(result, contains('Error'));
    });
  });

  group('execute_longClick', () {
    test('execute_longClickWithText_invokesLongClickByText', () async {
      await tool.execute(
          '{"action": "long_click", "text": "Item"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'longClickByText');
    });

    test('execute_longClickWithoutText_returnsError', () async {
      final result =
          await tool.execute('{"action": "long_click"}', mockContext);
      expect(result, contains("'text' required"));
    });
  });

  group('execute_type', () {
    test('execute_typeWithContent_invokesTypeText', () async {
      await tool.execute(
          '{"action": "type", "content": "hello"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'typeText');
      expect(
        (mockContext.methodCalls.last.arguments as Map)['content'],
        'hello',
      );
    });

    test('execute_typeWithoutContent_returnsError', () async {
      final result =
          await tool.execute('{"action": "type"}', mockContext);
      expect(result, contains("'content' required"));
    });

    test('execute_typeWithTarget_passesTarget', () async {
      await tool.execute(
          '{"action": "type", "content": "hi", "target": "field"}',
          mockContext);
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['target'], 'field');
      expect(args['content'], 'hi');
    });
  });

  group('execute_scroll', () {
    test('execute_scroll_invokesScrollMethod', () async {
      await tool.execute(
          '{"action": "scroll", "direction": "down"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'scroll');
      expect(
        (mockContext.methodCalls.last.arguments as Map)['direction'],
        'down',
      );
    });

    test('execute_scrollWithoutDirection_defaultsToForward', () async {
      await tool.execute('{"action": "scroll"}', mockContext);
      expect(
        (mockContext.methodCalls.last.arguments as Map)['direction'],
        'forward',
      );
    });
  });

  group('execute_swipe', () {
    test('execute_swipeWithDirection_invokesSwipeMethod', () async {
      await tool.execute(
          '{"action": "swipe", "direction": "up"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'swipe');
      expect(
        (mockContext.methodCalls.last.arguments as Map)['direction'],
        'up',
      );
    });

    test('execute_swipeWithoutDirection_defaultsToUp', () async {
      await tool.execute('{"action": "swipe"}', mockContext);
      expect(
        (mockContext.methodCalls.last.arguments as Map)['direction'],
        'up',
      );
    });
  });

  group('execute_global', () {
    test('execute_globalWithAction_invokesPerformGlobalAction', () async {
      await tool.execute(
          '{"action": "global", "global_action": "back"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'performGlobalAction');
      expect(
        (mockContext.methodCalls.last.arguments as Map)['action'],
        'back',
      );
    });

    test('execute_globalWithoutAction_returnsError', () async {
      final result =
          await tool.execute('{"action": "global"}', mockContext);
      expect(result, contains("'global_action' required"));
    });
  });

  group('execute_unknownAction', () {
    test('execute_unknownAction_returnsError', () async {
      final result =
          await tool.execute('{"action": "unknown"}', mockContext);
      expect(result, contains("Error: Unknown action 'unknown'"));
    });

    test('execute_emptyAction_returnsError', () async {
      final result = await tool.execute('{}', mockContext);
      expect(result, contains('Error: Unknown action'));
    });
  });

  group('execute_caseInsensitive', () {
    test('execute_upperCaseAction_treatedAsTap', () async {
      await tool.execute('{"action": "TAP", "text": "Btn"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'tapByText');
    });
  });

  group('execute_malformedInput', () {
    test('execute_malformedJson_returnsError', () async {
      final result = await tool.execute('not json', mockContext);
      expect(result, contains('Error: Unknown action'));
    });
  });

  group('execute_nullResult', () {
    test('execute_nullResult_returnsError', () async {
      mockContext.setInvokeResult(null);
      final result = await tool.execute(
          '{"action": "tap", "text": "Btn"}', mockContext);
      expect(result, 'Error');
    });
  });

  group('name_andMetadata', () {
    test('name_returnsScreenAction', () {
      expect(tool.name, 'screen_action');
    });

    test('description_isNotEmpty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });
  });
}
