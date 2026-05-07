import 'package:aios/agent/tools/screen_reader_tool.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tool_context.dart';

void main() {
  group('ScreenReaderTool', () {
    late ScreenReaderTool tool;
    late MockToolContext mockContext;

    setUp(() {
      tool = ScreenReaderTool();
      mockContext = MockToolContext();
    });

    group('execute_happyPath', () {
      test('execute_returnsScreenTextFromPlatform', () async {
        mockContext.setInvokeResult('Home Screen\nSettings Button');
        final result = await tool.execute('{}', mockContext);
        expect(result, 'Home Screen\nSettings Button');
      });

      test('execute_invokesGetScreenTextMethod', () async {
        mockContext.setInvokeResult('text');
        await tool.execute('{}', mockContext);
        expect(mockContext.methodCalls.length, 1);
        expect(mockContext.methodCalls.first.method, 'getScreenText');
      });
    });

    group('execute_errorHandling', () {
      test('execute_nullResult_returnsError', () async {
        mockContext.setInvokeResult(null);
        final result = await tool.execute('{}', mockContext);
        expect(result, 'Error: No result');
      });

      test('execute_platformException_returnsErrorString', () async {
        mockContext.onInvokeMethod = (_, __) => throw Exception('fail');
        final result = await tool.execute('{}', mockContext);
        expect(result, contains('Error:'));
      });
    });

    group('name_andMetadata', () {
      test('name_returnsScreenReader', () {
        expect(tool.name, 'screen_reader');
      });

      test('description_isNotEmpty', () {
        expect(tool.description.isNotEmpty, isTrue);
      });
    });
  });

  group('ScreenReaderTool_toolPrompt', () {
    late ScreenReaderTool tool;

    setUp(() {
      tool = ScreenReaderTool();
    });

    test('toolPrompt_containsReadAction', () {
      expect(tool.toolPrompt, contains('Read'));
    });

    test('toolPrompt_containsDescription', () {
      expect(tool.toolPrompt, contains('screen'));
    });

    test('toolPrompt_isNotEmpty', () {
      expect(tool.toolPrompt.isNotEmpty, isTrue);
    });
  });

  group('ScreenFindTool', () {
    late ScreenFindTool tool;
    late MockToolContext mockContext;

    setUp(() {
      tool = ScreenFindTool();
      mockContext = MockToolContext()
        ..setInvokeResult(
          '[{"text": "Settings", "bounds": "[0,0][100,50]"}]',
        );
    });

    group('execute_happyPath', () {
      test('execute_findWithText_invokesFindNodesByText', () async {
        await tool.execute('{"text": "Settings"}', mockContext);
        expect(mockContext.methodCalls.last.method, 'findNodesByText');
        expect(
          mockContext.methodCalls.last.arguments,
          {'text': 'Settings'},
        );
      });

      test('execute_nullResult_returnsNoElementsFound', () async {
        mockContext.setInvokeResult(null);
        final result =
            await tool.execute('{"text": "test"}', mockContext);
        expect(result, 'No elements found');
      });
    });

    group('execute_errorHandling', () {
      test('execute_missingText_returnsError', () async {
        final result = await tool.execute('{}', mockContext);
        expect(result, contains("'text' required"));
      });

      test('execute_emptyText_returnsError', () async {
        final result = await tool.execute('{"text": ""}', mockContext);
        expect(result, contains("'text' required"));
      });

      test('execute_malformedJson_returnsError', () async {
        final result = await tool.execute('not json', mockContext);
        expect(result, contains('Error:'));
      });

      test('execute_platformException_returnsErrorString', () async {
        mockContext.onInvokeMethod = (_, __) => throw Exception('fail');
        final result =
            await tool.execute('{"text": "test"}', mockContext);
        expect(result, contains('Error:'));
      });
    });

    group('ScreenFindTool_toolPrompt', () {
      test('toolPrompt_containsFindAction', () {
        expect(tool.toolPrompt, contains('Find'));
      });

      test('toolPrompt_containsTextParameter', () {
        expect(tool.toolPrompt, contains('text'));
      });

      test('toolPrompt_isNotEmpty', () {
        expect(tool.toolPrompt.isNotEmpty, isTrue);
      });
    });

    group('name_andMetadata', () {
      test('name_returnsScreenFind', () {
        expect(tool.name, 'screen_find');
      });

      test('description_isNotEmpty', () {
        expect(tool.description.isNotEmpty, isTrue);
      });
    });
  });
}
