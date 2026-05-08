import 'package:aios/agent/tools/app_launcher_tool.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tool_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLauncherTool tool;
  late MockToolContext mockContext;

  setUp(() {
    tool = AppLauncherTool();
    mockContext = MockToolContext()..setInvokeResult('Opened com.test');
  });

  group('validate', () {
    test('validate_emptyTarget_returnsError', () async {
      final result = await tool.validate('{}', mockContext);
      expect(result, isNotNull);
      expect(result, contains("'target' required"));
    });

    test('validate_withTarget_returnsNull', () async {
      final result = await tool.validate(
        '{"target": "youtube"}',
        mockContext,
      );
      expect(result, isNull);
    });
  });

  group('execute_openApp', () {
    test('execute_packageName_opensApp', () async {
      final result = await tool.execute(
        '{"target": "com.test"}',
        mockContext,
      );
      expect(result, contains('Opened'));
    });

    test('execute_emptyTarget_returnsError', () async {
      final result = await tool.execute('{}', mockContext);
      expect(result, contains("'target' required"));
    });
  });

  group('execute_urlDetection', () {
    test('execute_httpsUrl_detectedAsUrl', () {
      expect(tool.testLooksLikeUrl('https://google.com'), isTrue);
    });

    test('execute_domainOnly_detectedAsUrl', () {
      expect(tool.testLooksLikeUrl('naver.com'), isFalse);
    });

    test('execute_appName_notDetectedAsUrl', () {
      expect(tool.testLooksLikeUrl('youtube'), isFalse);
    });

    test('execute_packageName_notDetectedAsUrl', () {
      expect(
        tool.testLooksLikeUrl('com.google.android.youtube'),
        isFalse,
      );
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
