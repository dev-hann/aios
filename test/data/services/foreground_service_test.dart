import 'package:aios/data/services/foreground_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ForegroundService', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.agent.aios/service'),
            null,
          );
    });

    test('start_success_returnsTrue', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.agent.aios/service'),
            (call) async {
              if (call.method == 'startForegroundService') return true;
              return null;
            },
          );

      final result = await ForegroundService.start();
      expect(result, isTrue);
    });

    test('start_failure_returnsFalse', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.agent.aios/service'),
            (call) async {
              if (call.method == 'startForegroundService') {
                throw PlatformException(code: 'ERROR');
              }
              return null;
            },
          );

      final result = await ForegroundService.start();
      expect(result, isFalse);
    });

    test('stop_success_returnsTrue', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.agent.aios/service'),
            (call) async {
              if (call.method == 'stopForegroundService') return true;
              return null;
            },
          );

      final result = await ForegroundService.stop();
      expect(result, isTrue);
    });

    test('stop_failure_returnsFalse', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.agent.aios/service'),
            (call) async {
              if (call.method == 'stopForegroundService') {
                throw PlatformException(code: 'ERROR');
              }
              return null;
            },
          );

      final result = await ForegroundService.stop();
      expect(result, isFalse);
    });

    test('isRunning_true_returnsTrue', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.agent.aios/service'),
            (call) async {
              if (call.method == 'isForegroundServiceRunning') return true;
              return null;
            },
          );

      final result = await ForegroundService.isRunning();
      expect(result, isTrue);
    });

    test('isRunning_failure_returnsFalse', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.agent.aios/service'),
            (call) async {
              if (call.method == 'isForegroundServiceRunning') {
                throw PlatformException(code: 'ERROR');
              }
              return null;
            },
          );

      final result = await ForegroundService.isRunning();
      expect(result, isFalse);
    });
  });
}
