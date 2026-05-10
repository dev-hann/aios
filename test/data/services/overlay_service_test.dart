import 'package:aios/data/services/foreground_service.dart';
import 'package:aios/data/services/overlay_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ForegroundService', () {
    test('start_returnsTrueOnSuccess', () async {
      MethodChannel('com.agent.aios/service').setMockMethodCallHandler((
        call,
      ) async {
        if (call.method == 'startForegroundService') return true;
        return null;
      });

      final result = await ForegroundService.start();
      expect(result, isTrue);
    });

    test('stop_returnsTrueOnSuccess', () async {
      MethodChannel('com.agent.aios/service').setMockMethodCallHandler((
        call,
      ) async {
        if (call.method == 'stopForegroundService') return true;
        return null;
      });

      final result = await ForegroundService.stop();
      expect(result, isTrue);
    });

    test('isRunning_returnsFalseOnPlatformError', () async {
      MethodChannel('com.agent.aios/service').setMockMethodCallHandler((
        call,
      ) async {
        throw PlatformException(code: 'ERROR', message: 'test');
      });

      final result = await ForegroundService.isRunning();
      expect(result, isFalse);
    });
  });

  group('OverlayService', () {
    late OverlayService service;

    setUp(() {
      service = OverlayService();
    });

    tearDown(() {
      service.dispose();
    });

    test('startOverlay_returnsTrueOnSuccess', () async {
      MethodChannel('com.agent.aios/overlay').setMockMethodCallHandler((
        call,
      ) async {
        if (call.method == 'startOverlay') return true;
        return null;
      });

      final result = await service.startOverlay();
      expect(result, isTrue);
    });

    test('stopOverlay_returnsTrueOnSuccess', () async {
      MethodChannel('com.agent.aios/overlay').setMockMethodCallHandler((
        call,
      ) async {
        if (call.method == 'stopOverlay') return true;
        return null;
      });

      final result = await service.stopOverlay();
      expect(result, isTrue);
    });

    test('updateResult_passesTextToNative', () async {
      String? capturedArg;
      MethodChannel('com.agent.aios/overlay').setMockMethodCallHandler((
        call,
      ) async {
        if (call.method == 'updateResult') {
          capturedArg = call.arguments as String?;
          return true;
        }
        return null;
      });

      await service.updateResult('test result');
      expect(capturedArg, 'test result');
    });

    test('isOverlayPermissionGranted_returnsTrue', () async {
      MethodChannel('com.agent.aios/overlay').setMockMethodCallHandler((
        call,
      ) async {
        if (call.method == 'isOverlayPermissionGranted') return true;
        return null;
      });

      final result = await service.isOverlayPermissionGranted();
      expect(result, isTrue);
    });

    test('onUserMessage_storesCallback', () async {
      String? receivedMessage;
      service.onUserMessage = (text) {
        receivedMessage = text;
      };

      expect(receivedMessage, isNull);
    });

    test('dispose_clearsHandler', () async {
      void handler(String text) {}
      service.onUserMessage = handler;

      expect(service.onUserMessage, isNotNull);
      service.dispose();
      expect(service.onUserMessage, isNull);
    });

    test('startOverlay_returnsFalseOnPlatformError', () async {
      MethodChannel('com.agent.aios/overlay').setMockMethodCallHandler((
        call,
      ) async {
        throw PlatformException(code: 'ERROR', message: 'test');
      });

      final result = await service.startOverlay();
      expect(result, isFalse);
    });
  });
}
