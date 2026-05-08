import 'dart:convert';

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

  group('execute_getInfo', () {
    test('execute_getInfo_returnsFormattedDeviceInfo', () async {
      final data = json.encode({
        'device': 'Pixel 8',
        'manufacturer': 'Google',
        'android_version': '14',
        'sdk_int': 34,
        'jvm_max_mb': 512,
        'jvm_total_mb': 128,
        'jvm_free_mb': 64,
      });
      mockContext.setInvokeResult(data);
      final result = await tool.execute(
        '{"action": "get_info"}',
        mockContext,
      );
      expect(result, contains('Google'));
      expect(result, contains('Pixel 8'));
      expect(result, contains('14'));
      expect(result, contains('34'));
    });

    test('execute_defaultAction_returnsGetInfo', () async {
      final data = json.encode({
        'device': 'Pixel 8',
        'manufacturer': 'Google',
        'android_version': '14',
        'sdk_int': 34,
        'jvm_max_mb': 512,
        'jvm_total_mb': 128,
        'jvm_free_mb': 64,
      });
      mockContext.setInvokeResult(data);
      final result = await tool.execute('{}', mockContext);
      expect(result, contains('Pixel 8'));
      expect(mockContext.methodCalls.first.method, 'getDeviceInfo');
    });
  });

  group('execute_battery', () {
    test('execute_battery_returnsFormattedBatteryInfo', () async {
      mockContext.setInvokeResult(
        json.encode({'level': 85, 'charging': true}),
      );
      final result = await tool.execute(
        '{"action": "battery"}',
        mockContext,
      );
      expect(result, contains('85%'));
      expect(result, contains('Charging'));
      expect(mockContext.methodCalls.first.method, 'getBatteryInfo');
    });

    test('execute_batteryNotCharging_showsNotCharging', () async {
      mockContext.setInvokeResult(
        json.encode({'level': 42, 'charging': false}),
      );
      final result = await tool.execute(
        '{"action": "battery"}',
        mockContext,
      );
      expect(result, contains('42%'));
      expect(result, contains('Not charging'));
    });
  });

  group('execute_storage', () {
    test('execute_storage_returnsFormattedStorageInfo', () async {
      mockContext.setInvokeResult(json.encode({
        'total_gb': '128.0',
        'used_gb': '64.5',
        'available_gb': '63.5',
        'usage_percent': 50,
      }));
      final result = await tool.execute(
        '{"action": "storage"}',
        mockContext,
      );
      expect(result, contains('64.5GB'));
      expect(result, contains('128.0GB'));
      expect(result, contains('63.5GB'));
      expect(result, contains('50%'));
      expect(mockContext.methodCalls.first.method, 'getStorageInfo');
    });
  });

  group('execute_memory', () {
    test('execute_memory_returnsFormattedMemoryInfo', () async {
      mockContext.setInvokeResult(json.encode({
        'device': 'Pixel 8',
        'manufacturer': 'Google',
        'android_version': '14',
        'sdk_int': 34,
        'jvm_max_mb': 512,
        'jvm_total_mb': 128,
        'jvm_free_mb': 64,
      }));
      final result = await tool.execute(
        '{"action": "memory"}',
        mockContext,
      );
      expect(result, contains('128MB'));
      expect(result, contains('512MB'));
      expect(result, contains('64MB'));
      expect(mockContext.methodCalls.first.method, 'getDeviceInfo');
    });
  });

  group('execute_errorHandling', () {
    test('execute_nullResult_returnsError', () async {
      mockContext.setInvokeResult(null);
      final result = await tool.execute('{}', mockContext);
      expect(result, 'Error: No result');
    });

    test('execute_unknownAction_returnsError', () async {
      final result = await tool.execute(
        '{"action": "unknown"}',
        mockContext,
      );
      expect(result, contains("Error: Unknown action 'unknown'"));
      expect(result, contains('get_info'));
    });

    test('execute_platformException_returnsErrorString', () async {
      mockContext.onInvokeMethod = (_, __) => throw Exception('fail');
      final result = await tool.execute('{}', mockContext);
      expect(result, contains('Error:'));
    });
  });

  group('execute_malformedInput', () {
    test('execute_malformedJson_defaultsToGetInfo', () async {
      final data = json.encode({
        'device': 'Pixel 8',
        'manufacturer': 'Google',
        'android_version': '14',
        'sdk_int': 34,
        'jvm_max_mb': 512,
        'jvm_total_mb': 128,
        'jvm_free_mb': 64,
      });
      mockContext.setInvokeResult(data);
      final result = await tool.execute('not json', mockContext);
      expect(result, contains('Pixel 8'));
    });
  });

  group('name_andMetadata', () {
    test('name_returnsDeviceInfo', () {
      expect(tool.name, 'device_info');
    });

    test('description_isNotEmpty', () {
      expect(tool.description.isNotEmpty, isTrue);
    });

    test('parameters_isNotEmpty', () {
      expect(tool.parameters.isNotEmpty, isTrue);
    });

    test('toolPrompt_containsActions', () {
      expect(tool.toolPrompt, contains('get_info'));
      expect(tool.toolPrompt, contains('battery'));
      expect(tool.toolPrompt, contains('storage'));
      expect(tool.toolPrompt, contains('memory'));
    });

    test('toolPrompt_containsRules', () {
      expect(tool.toolPrompt, contains('Rules'));
      expect(tool.toolPrompt, contains('defaults to "get_info"'));
      expect(tool.toolPrompt, contains('Get device info'));
    });

    test('toolPrompt_containsParameters', () {
      expect(tool.toolPrompt, contains('Parameters'));
    });
  });
}
