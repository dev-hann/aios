import 'package:aios/agent/tools/contact_search_tool.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tool_context.dart';

void main() {
  late ContactSearchTool tool;
  late MockToolContext mockContext;

  setUp(() {
    tool = ContactSearchTool();
    mockContext = MockToolContext()
      ..setInvokeResult('[{"name": "Kim", "phone": "010"}]');
  });

  group('execute_happyPath', () {
    test('search with query invokes searchContacts', () async {
      await tool.execute('{"query": "Kim"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'searchContacts');
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['query'], 'Kim');
      expect(args['limit'], 10);
    });

    test('search with custom limit passes limit', () async {
      await tool.execute('{"query": "Kim", "limit": 5}', mockContext);
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['limit'], 5);
    });
  });

  group('execute_errorHandling', () {
    test('missing query returns error', () async {
      final result = await tool.execute('{}', mockContext);
      expect(result, contains("'query' parameter required"));
    });

    test('empty query after trim returns error', () async {
      final result = await tool.execute('{"query": "  "}', mockContext);
      expect(result, contains("'query' parameter required"));
    });

    test('null result returns no contacts found', () async {
      mockContext.setInvokeResult(null);
      final result = await tool.execute('{"query": "Kim"}', mockContext);
      expect(result, 'No contacts found');
    });
  });

  group('execute_malformedInput', () {
    test('malformed JSON returns error', () async {
      final result = await tool.execute('not json', mockContext);
      expect(result, contains("'query' parameter required"));
    });
  });

  group('name_andMetadata', () {
    test('name is contact_search', () {
      expect(tool.name, 'contact_search');
    });

    test('description is not empty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });
  });
}
