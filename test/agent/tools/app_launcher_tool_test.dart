import 'package:aios/agent/tools/app_launcher_tool.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tool_context.dart';

void main() {
  late AppLauncherTool tool;
  late MockToolContext mockContext;

  setUp(() {
    tool = AppLauncherTool();
    mockContext = MockToolContext()..setInvokeResult('Opened com.test');
  });

  group('validate_openApp', () {
    test('validate_nonExistentPackage_returnsError', () async {
      final result = await tool.validate(
        '{"action": "open_app", "package_name": "com.nonexistent.app"}',
        mockContext,
      );
      expect(result, isNotNull);
      expect(result, contains('not installed'));
      expect(result, contains('list_apps'));
    });

    test('validate_listAppsAction_returnsNull', () async {
      final result = await tool.validate(
        '{"action": "list_apps", "query": "youtube"}',
        mockContext,
      );
      expect(result, isNull);
    });

    test('validate_openUrlAction_returnsNull', () async {
      final result = await tool.validate(
        '{"action": "open_url", "url": "https://example.com"}',
        mockContext,
      );
      expect(result, isNull);
    });

    test('validate_openAppWithoutPackageName_returnsError', () async {
      final result = await tool.validate(
        '{"action": "open_app"}',
        mockContext,
      );
      expect(result, isNotNull);
      expect(result, contains("'package_name' required"));
    });
  });

  group('execute_openApp', () {
    test('execute_openAppWithoutPackageName_returnsError', () async {
      final result = await tool.execute(
        '{"action": "open_app"}',
        mockContext,
      );
      expect(result, contains("'package_name' required"));
    });

    test('execute_openAppNonExistentPackage_usesValidate', () async {
      final validateResult = await tool.validate(
        '{"action": "open_app", "package_name": "com.nonexistent.app"}',
        mockContext,
      );
      expect(validateResult, isNotNull);
      expect(validateResult, contains('not installed'));

      final result = await tool.execute(
        '{"action": "open_app", "package_name": "com.nonexistent.app"}',
        mockContext,
      );
      expect(result, contains('Opened'));
    });
  });

  group('execute_unknownAction', () {
    test('execute_unknownAction_returnsError', () async {
      final result = await tool.execute(
        '{"action": "unknown"}',
        mockContext,
      );
      expect(result, contains("Error: Unknown action 'unknown'"));
    });

    test('execute_emptyAction_returnsError', () async {
      final result = await tool.execute('{}', mockContext);
      expect(result, contains('Error: Unknown action'));
    });
  });

  group('execute_caseInsensitive', () {
    test('execute_upperCaseAction_treatedAsOpenApp', () async {
      final result = await tool.execute(
        '{"action": "OPEN_APP", "package_name": "com.test"}',
        mockContext,
      );
      expect(result, isNot(contains('Unknown action')));
    });
  });

  group('execute_malformedInput', () {
    test('execute_malformedJson_returnsError', () async {
      final result = await tool.execute('not json', mockContext);
      expect(result, contains('Error'));
    });
  });

  group('name_andMetadata', () {
    test('name_returnsAppLauncher', () {
      expect(tool.name, 'app_launcher');
    });

    test('description_isNotEmpty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });

    test('parameters_isNotEmpty', () {
      expect(tool.parameters.isNotEmpty, isTrue);
    });
  });

  group('extractAppQuery', () {
    test('extractAppQuery_openPattern_extractsAppName', () {
      final result = tool.testExtractAppQuery('open firefox');
      expect(result, 'firefox');
    });

    test('extractAppQuery_launchPattern_extractsAppName', () {
      final result = tool.testExtractAppQuery('launch chrome');
      expect(result, 'chrome');
    });

    test('extractAppQuery_startPattern_extractsAppName', () {
      final result = tool.testExtractAppQuery('start youtube');
      expect(result, 'youtube');
    });

    test('extractAppQuery_runPattern_extractsAppName', () {
      final result = tool.testExtractAppQuery('run spotify');
      expect(result, 'spotify');
    });

    test('extractAppQuery_noMatch_returnsEmpty', () {
      final result = tool.testExtractAppQuery('hello there');
      expect(result, '');
    });

    test('extractAppQuery_caseInsensitive_extractsAppName', () {
      final result = tool.testExtractAppQuery('Open Firefox');
      expect(result, 'firefox');
    });
  });
}
