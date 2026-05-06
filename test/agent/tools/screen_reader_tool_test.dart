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
      test('returns screen text from platform', () async {
        mockContext.setInvokeResult('Home Screen\nSettings Button');
        final result = await tool.execute('{}', mockContext);
        expect(result, 'Home Screen\nSettings Button');
      });

      test('invokes getScreenText method', () async {
        mockContext.setInvokeResult('text');
        await tool.execute('{}', mockContext);
        expect(mockContext.methodCalls.length, 1);
        expect(mockContext.methodCalls.first.method, 'getScreenText');
      });
    });

    group('execute_errorHandling', () {
      test('null result returns error', () async {
        mockContext.setInvokeResult(null);
        final result = await tool.execute('{}', mockContext);
        expect(result, 'Error: No result');
      });

      test('platform exception returns error string', () async {
        mockContext.onInvokeMethod = (_, __) => throw Exception('fail');
        final result = await tool.execute('{}', mockContext);
        expect(result, contains('Error:'));
      });
    });

    group('name_andMetadata', () {
      test('name is screen_reader', () {
        expect(tool.name, 'screen_reader');
      });

      test('description is not empty', () {
        expect(tool.description.isNotEmpty, isTrue);
      });
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
      test('find with text invokes findNodesByText', () async {
        await tool.execute('{"text": "Settings"}', mockContext);
        expect(mockContext.methodCalls.last.method, 'findNodesByText');
        expect(
          mockContext.methodCalls.last.arguments,
          {'text': 'Settings'},
        );
      });

      test('null result returns no elements found', () async {
        mockContext.setInvokeResult(null);
        final result =
            await tool.execute('{"text": "test"}', mockContext);
        expect(result, 'No elements found');
      });
    });

    group('execute_errorHandling', () {
      test('missing text parameter returns error', () async {
        final result = await tool.execute('{}', mockContext);
        expect(result, contains("'text' parameter required"));
      });

      test('empty text returns error', () async {
        final result = await tool.execute('{"text": ""}', mockContext);
        expect(result, contains("'text' parameter required"));
      });

      test('malformed JSON returns error', () async {
        final result = await tool.execute('not json', mockContext);
        expect(result, contains('Error:'));
      });

      test('platform exception returns error string', () async {
        mockContext.onInvokeMethod = (_, __) => throw Exception('fail');
        final result =
            await tool.execute('{"text": "test"}', mockContext);
        expect(result, contains('Error:'));
      });
    });

    group('name_andMetadata', () {
      test('name is screen_find', () {
        expect(tool.name, 'screen_find');
      });

      test('description is not empty', () {
        expect(tool.description.isNotEmpty, isTrue);
      });
    });
  });
}
