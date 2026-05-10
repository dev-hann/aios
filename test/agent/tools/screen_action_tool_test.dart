import 'package:aios/agent/tools/screen_action_tool.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tool_context.dart';

void main() {
  late ScreenActionTool tool;
  late MockToolContext mockContext;

  setUp(() {
    tool = ScreenActionTool();
    mockContext = MockToolContext()
      ..setInvokeResult('OK')
      ..setMethodResult('getScreenText', null);
  });

  group('execute_tap', () {
    test('execute_tapByText_invokesTapByText', () async {
      await tool.execute('{"action": "tap", "text": "Button"}', mockContext);
      final call = mockContext.findCall('tapByText');
      expect(call, isNotNull);
      expect(call!.arguments, {'text': 'Button'});
    });

    test('execute_tapByCoordinates_invokesPerformTap', () async {
      await tool.execute('{"action": "tap", "x": 100, "y": 200}', mockContext);
      final call = mockContext.findCall('performTap');
      expect(call, isNotNull);
      final args = call!.arguments as Map;
      expect(args['x'], 100.0);
      expect(args['y'], 200.0);
    });

    test('execute_tapWithStringCoordinates_parsesCorrectly', () async {
      await tool.execute(
        '{"action": "tap", "x": "50", "y": "75"}',
        mockContext,
      );
      final call = mockContext.findCall('performTap');
      expect(call, isNotNull);
      final args = call!.arguments as Map;
      expect(args['x'], 50.0);
      expect(args['y'], 75.0);
    });

    test('execute_tapWithoutTarget_returnsError', () async {
      final result = await tool.execute('{"action": "tap"}', mockContext);
      expect(result.isError, isTrue);
    });
  });

  group('execute_longClick', () {
    test('execute_longClickWithText_invokesLongClickByText', () async {
      await tool.execute(
        '{"action": "long_click", "text": "Item"}',
        mockContext,
      );
      final call = mockContext.findCall('longClickByText');
      expect(call, isNotNull);
    });

    test('execute_longClickWithoutText_returnsError', () async {
      final result = await tool.execute(
        '{"action": "long_click"}',
        mockContext,
      );
      expect(result.toContent(), contains("'text' required"));
    });
  });

  group('execute_type', () {
    test('execute_typeWithContent_invokesTypeText', () async {
      await tool.execute('{"action": "type", "content": "hello"}', mockContext);
      final call = mockContext.findCall('typeText');
      expect(call, isNotNull);
      expect((call!.arguments as Map)['content'], 'hello');
    });

    test('execute_typeWithoutContent_returnsError', () async {
      final result = await tool.execute('{"action": "type"}', mockContext);
      expect(result.toContent(), contains("'content' required"));
    });

    test('execute_typeWithTarget_passesTarget', () async {
      await tool.execute(
        '{"action": "type", "content": "hi", "target": "field"}',
        mockContext,
      );
      final call = mockContext.findCall('typeText');
      expect(call, isNotNull);
      final args = call!.arguments as Map;
      expect(args['target'], 'field');
      expect(args['content'], 'hi');
    });

    test('execute_typeWithSubmit_autoPressesEnter', () async {
      final result = await tool.execute(
        '{"action": "type", "content": "query", "submit": true}',
        mockContext,
      );
      expect(result.isError, isFalse);
      expect(result.output, contains('pressed enter'));
      expect(result.system, isNotNull);
      expect(
        mockContext.methodCalls.any(
          (c) =>
              c.method == 'performGlobalAction' &&
              (c.arguments as Map)['action'] == 'enter',
        ),
        isTrue,
      );
    });

    test('execute_typeWithoutSubmit_returnsNudge', () async {
      final result = await tool.execute(
        '{"action": "type", "content": "query"}',
        mockContext,
      );
      expect(result.isError, isFalse);
      expect(result.system, contains('enter'));
    });
  });

  group('execute_scroll', () {
    test('execute_scroll_invokesScrollMethod', () async {
      await tool.execute(
        '{"action": "scroll", "direction": "down"}',
        mockContext,
      );
      final call = mockContext.findCall('scroll');
      expect(call, isNotNull);
      expect((call!.arguments as Map)['direction'], 'down');
    });

    test('execute_scrollWithoutDirection_defaultsToForward', () async {
      await tool.execute('{"action": "scroll"}', mockContext);
      final call = mockContext.findCall('scroll');
      expect(call, isNotNull);
      expect((call!.arguments as Map)['direction'], 'forward');
    });
  });

  group('execute_swipe', () {
    test('execute_swipeWithDirection_invokesSwipeMethod', () async {
      await tool.execute('{"action": "swipe", "direction": "up"}', mockContext);
      final call = mockContext.findCall('swipe');
      expect(call, isNotNull);
      expect((call!.arguments as Map)['direction'], 'up');
    });

    test('execute_swipeWithoutDirection_defaultsToUp', () async {
      await tool.execute('{"action": "swipe"}', mockContext);
      final call = mockContext.findCall('swipe');
      expect(call, isNotNull);
      expect((call!.arguments as Map)['direction'], 'up');
    });
  });

  group('execute_global', () {
    test('execute_globalWithAction_invokesPerformGlobalAction', () async {
      await tool.execute(
        '{"action": "global", "global_action": "back"}',
        mockContext,
      );
      final call = mockContext.findCall('performGlobalAction');
      expect(call, isNotNull);
      expect((call!.arguments as Map)['action'], 'back');
    });

    test('execute_globalWithoutAction_returnsError', () async {
      final result = await tool.execute('{"action": "global"}', mockContext);
      expect(result.toContent(), contains("'global_action' required"));
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
    test('execute_upperCaseAction_treatedAsTap', () async {
      await tool.execute('{"action": "TAP", "text": "Btn"}', mockContext);
      final call = mockContext.findCall('tapByText');
      expect(call, isNotNull);
    });
  });

  group('execute_malformedInput', () {
    test('execute_malformedJson_returnsError', () async {
      final result = await tool.execute('not json', mockContext);
      expect(result.toContent(), contains('Error: Unknown action'));
    });
  });

  group('execute_nullResult', () {
    test('execute_nullResult_returnsError', () async {
      mockContext.setInvokeResult(null);
      final result = await tool.execute(
        '{"action": "tap", "text": "Btn"}',
        mockContext,
      );
      expect(result.toContent(), contains('Error:'));
    });
  });

  group('auto_observation', () {
    test('execute_withObservation_includesScreenState', () async {
      mockContext.setMethodResult('getScreenText', 'Home Screen');
      final result = await tool.execute(
        '{"action": "tap", "text": "Button"}',
        mockContext,
      );
      expect(result.isError, isFalse);
      expect(result.observation, 'Home Screen');
      expect(result.toContent(), contains('Screen: Home Screen'));
    });

    test('execute_withoutObservation_omitsScreenState', () async {
      mockContext.setMethodResult('getScreenText', null);
      final result = await tool.execute(
        '{"action": "tap", "text": "Button"}',
        mockContext,
      );
      expect(result.isError, isFalse);
      expect(result.observation, isNull);
    });
  });

  group('toolPrompt', () {
    test('toolPrompt_containsAllActions', () {
      final prompt = tool.toolPrompt;
      expect(prompt, contains('tap'));
      expect(prompt, contains('long_click'));
      expect(prompt, contains('type'));
      expect(prompt, contains('scroll'));
      expect(prompt, contains('swipe'));
      expect(prompt, contains('global'));
    });

    test('toolPrompt_containsParameters', () {
      final prompt = tool.toolPrompt;
      expect(prompt, contains('action'));
      expect(prompt, contains('text'));
      expect(prompt, contains('content'));
      expect(prompt, contains('direction'));
    });

    test('toolPrompt_isNotEmpty', () {
      expect(tool.toolPrompt.isNotEmpty, isTrue);
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
