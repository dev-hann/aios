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
    test('execute_searchWithQuery_invokesSearchContacts', () async {
      await tool.execute('{"query": "Kim"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'searchContacts');
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['query'], 'Kim');
      expect(args['limit'], 10);
    });

    test('execute_searchWithCustomLimit_passesLimit', () async {
      await tool.execute('{"query": "Kim", "limit": 5}', mockContext);
      final args = mockContext.methodCalls.last.arguments as Map;
      expect(args['limit'], 5);
    });
  });

  group('execute_errorHandling', () {
    test('execute_missingQuery_returnsError', () async {
      final result = await tool.execute('{}', mockContext);
      expect(result, contains("'query' required"));
    });

    test('execute_emptyQuery_returnsError', () async {
      final result = await tool.execute('{"query": "  "}', mockContext);
      expect(result, contains("'query' required"));
    });

    test('execute_nullResult_returnsNoContactsFound', () async {
      mockContext.setInvokeResult(null);
      final result = await tool.execute('{"query": "Kim"}', mockContext);
      expect(result, 'No contacts found');
    });
  });

  group('execute_malformedInput', () {
    test('execute_malformedJson_returnsError', () async {
      final result = await tool.execute('not json', mockContext);
      expect(result, contains("'query' required"));
    });
  });

  group('name_andMetadata', () {
    test('name_returnsContactSearch', () {
      expect(tool.name, 'contact_search');
    });

    test('description_isNotEmpty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });
  });

  group('toolPrompt', () {
    test('toolPrompt_containsQuery', () {
      expect(tool.toolPrompt, contains('query'));
    });

    test('toolPrompt_containsLimit', () {
      expect(tool.toolPrompt, contains('limit'));
    });

    test('toolPrompt_isNotEmpty', () {
      expect(tool.toolPrompt.isNotEmpty, isTrue);
    });

    test('toolPrompt_containsRules', () {
      expect(tool.toolPrompt, contains('Rules'));
    });

    test('toolPrompt_containsSearchDescription', () {
      expect(tool.toolPrompt, contains('Search'));
    });
  });
}
