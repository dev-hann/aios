import 'package:aios/agent/tools/device_info_tool.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tool_context.dart';

void main() {
  late DeviceInfoTool tool;
  late MockToolContext mockContext;

  setUp(() {
    tool = DeviceInfoTool();
    mockContext = MockToolContext();
  });

  group('execute_happyPath', () {
    test('returns device info from platform', () async {
      mockContext.setInvokeResult(
        '{"model": "Pixel 8", "os": "Android 14", "memory": "8GB"}',
      );
      final result = await tool.execute('{}', mockContext);
      expect(result, contains('Pixel 8'));
    });

    test('invokes getDeviceInfo method', () async {
      mockContext.setInvokeResult('info');
      await tool.execute('{}', mockContext);
      expect(mockContext.methodCalls.length, 1);
      expect(mockContext.methodCalls.first.method, 'getDeviceInfo');
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
    test('name is device_info', () {
      expect(tool.name, 'device_info');
    });

    test('description is not empty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });

    test('parameters is not empty', () {
      expect(tool.parameters.isNotEmpty, isTrue);
    });
  });
}
