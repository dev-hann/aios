import 'package:aios/agent/tools/app_launcher_tool.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tool_context.dart';

void main() {
  late AppLauncherTool tool;
  late MockToolContext mockContext;

  setUp(() {
    tool = AppLauncherTool();
    mockContext = MockToolContext()
      ..setInvokeResult('OK');
  });

  group('execute_openApp', () {
    test('open_app with package_name invokes openApp', () async {
      await tool.execute(
          '{"action": "open_app", "package_name": "com.example.app"}',
          mockContext);
      expect(mockContext.methodCalls.last.method, 'openApp');
      expect(
        mockContext.methodCalls.last.arguments,
        {'package_name': 'com.example.app'},
      );
    });

    test('open_app without package_name returns error', () async {
      final result =
          await tool.execute('{"action": "open_app"}', mockContext);
      expect(result, contains("'package_name' required"));
    });
  });

  group('execute_openUrl', () {
    test('open_url with url invokes openUrl', () async {
      await tool.execute(
          '{"action": "open_url", "url": "https://example.com"}',
          mockContext);
      expect(mockContext.methodCalls.last.method, 'openUrl');
      expect(
        mockContext.methodCalls.last.arguments,
        {'url': 'https://example.com'},
      );
    });

    test('open_url without url returns error', () async {
      final result =
          await tool.execute('{"action": "open_url"}', mockContext);
      expect(result, contains("'url' required"));
    });
  });

  group('execute_openSettings', () {
    test('open_settings with setting invokes openSettings', () async {
      await tool.execute(
          '{"action": "open_settings", "setting": "wifi"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'openSettings');
      expect(
        mockContext.methodCalls.last.arguments,
        {'setting': 'wifi'},
      );
    });

    test('open_settings without setting returns error', () async {
      final result =
          await tool.execute('{"action": "open_settings"}', mockContext);
      expect(result, contains("'setting' required"));
    });
  });

  group('execute_listApps', () {
    test('list_apps invokes listApps with query', () async {
      await tool.execute(
          '{"action": "list_apps", "query": "chrome"}', mockContext);
      expect(mockContext.methodCalls.last.method, 'listApps');
      expect(
        mockContext.methodCalls.last.arguments,
        {'query': 'chrome'},
      );
    });

    test('list_apps without query passes empty string', () async {
      await tool.execute('{"action": "list_apps"}', mockContext);
      expect(
        mockContext.methodCalls.last.arguments,
        {'query': ''},
      );
    });
  });

  group('execute_unknownAction', () {
    test('unknown action returns error with available actions', () async {
      final result =
          await tool.execute('{"action": "unknown"}', mockContext);
      expect(result, contains("Error: Unknown action 'unknown'"));
      expect(result, contains('open_app'));
    });

    test('empty action returns error', () async {
      final result = await tool.execute('{}', mockContext);
      expect(result, contains('Error: Unknown action'));
    });
  });

  group('execute_caseInsensitive', () {
    test('OPEN_APP is treated as open_app', () async {
      await tool.execute(
          '{"action": "OPEN_APP", "package_name": "com.test"}',
          mockContext);
      expect(mockContext.methodCalls.last.method, 'openApp');
    });
  });

  group('execute_malformedInput', () {
    test('malformed JSON returns error', () async {
      final result = await tool.execute('not json', mockContext);
      expect(result, contains('Error: Unknown action'));
    });
  });

  group('name_andMetadata', () {
    test('name is app_launcher', () {
      expect(tool.name, 'app_launcher');
    });

    test('description is not empty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });
  });
}
