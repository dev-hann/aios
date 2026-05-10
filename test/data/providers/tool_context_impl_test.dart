import 'package:aios/data/providers/tool_context_impl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ToolContextImpl', () {
    late ToolContextImpl toolContext;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.agent.aios/tools'),
            null,
          );
      toolContext = ToolContextImpl();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.agent.aios/tools'),
            null,
          );
    });

    group('invokeMethod', () {
      test('invokeMethod_success_returnsResult', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.agent.aios/tools'),
              (call) async {
                if (call.method == 'getScreenText') return 'Home Screen';
                return null;
              },
            );

        final result = await toolContext.invokeMethod('getScreenText');

        expect(result, 'Home Screen');
      });

      test('invokeMethod_nullResult_returnsNull', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.agent.aios/tools'),
              (call) async => null,
            );

        final result = await toolContext.invokeMethod('unknownMethod');

        expect(result, isNull);
      });

      test('invokeMethod_platformException_returnsErrorString', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.agent.aios/tools'),
              (call) async {
                throw PlatformException(
                  code: 'ERROR',
                  message: 'Service not available',
                );
              },
            );

        final result = await toolContext.invokeMethod('getScreenText');

        expect(result, isNotNull);
        expect(result, contains('Error'));
        expect(result, contains('Service not available'));
      });

      test('invokeMethod_passesArguments', () async {
        dynamic capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.agent.aios/tools'),
              (call) async {
                capturedArgs = call.arguments;
                return 'ok';
              },
            );

        await toolContext.invokeMethod('tapByText', {'text': 'Button'});

        expect(capturedArgs, isNotNull);
      });

      test('invokeMethod_withoutArguments', () async {
        String? capturedMethod;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.agent.aios/tools'),
              (call) async {
                capturedMethod = call.method;
                return 'ok';
              },
            );

        await toolContext.invokeMethod('getScreenText');

        expect(capturedMethod, 'getScreenText');
      });

      test(
        'invokeMethod_platformExceptionWithNullMessage_returnsError',
        () async {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
                const MethodChannel('com.agent.aios/tools'),
                (call) async {
                  throw PlatformException(code: 'CRASH', message: null);
                },
              );

          final result = await toolContext.invokeMethod('getScreenText');

          expect(result, contains('Error'));
        },
      );
    });

    group('isAccessibilityEnabled', () {
      test('returnsTrue_whenServiceEnabled', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.agent.aios/tools'),
              (call) async {
                if (call.method == 'isAccessibilityEnabled') return true;
                return null;
              },
            );

        final result = await toolContext.isAccessibilityEnabled();

        expect(result, isTrue);
      });

      test('returnsFalse_whenServiceDisabled', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.agent.aios/tools'),
              (call) async {
                if (call.method == 'isAccessibilityEnabled') return false;
                return null;
              },
            );

        final result = await toolContext.isAccessibilityEnabled();

        expect(result, isFalse);
      });

      test('returnsFalse_whenNullResult', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.agent.aios/tools'),
              (call) async => null,
            );

        final result = await toolContext.isAccessibilityEnabled();

        expect(result, isFalse);
      });

      test('returnsFalse_onPlatformException', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.agent.aios/tools'),
              (call) async {
                throw PlatformException(code: 'ERROR');
              },
            );

        final result = await toolContext.isAccessibilityEnabled();

        expect(result, isFalse);
      });
    });

    group('isNotificationListenerEnabled', () {
      test('returnsTrue_whenServiceEnabled', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.agent.aios/tools'),
              (call) async {
                if (call.method == 'isNotificationListenerEnabled') return true;
                return null;
              },
            );

        final result = await toolContext.isNotificationListenerEnabled();

        expect(result, isTrue);
      });

      test('returnsFalse_whenServiceDisabled', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.agent.aios/tools'),
              (call) async {
                if (call.method == 'isNotificationListenerEnabled')
                  return false;
                return null;
              },
            );

        final result = await toolContext.isNotificationListenerEnabled();

        expect(result, isFalse);
      });

      test('returnsFalse_whenNullResult', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.agent.aios/tools'),
              (call) async => null,
            );

        final result = await toolContext.isNotificationListenerEnabled();

        expect(result, isFalse);
      });

      test('returnsFalse_onPlatformException', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.agent.aios/tools'),
              (call) async {
                throw PlatformException(code: 'ERROR');
              },
            );

        final result = await toolContext.isNotificationListenerEnabled();

        expect(result, isFalse);
      });
    });
  });
}
