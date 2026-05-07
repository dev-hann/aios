import 'package:aios/domain/agent/error_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ErrorRecovery recovery;

  setUp(() {
    recovery = ErrorRecovery(
      availableTools: {
        'calculator',
        'app_launcher',
        'screen_action',
        'screen_reader',
      },
    );
  });

  group('isError', () {
    test('isError_errorPrefix_returnsTrue', () {
      expect(recovery.isError('Error: something failed'), isTrue);
    });

    test('isError_errorPrefixWithWhitespace_returnsTrue', () {
      expect(recovery.isError('  Error: something'), isTrue);
    });

    test('isError_nonError_returnsFalse', () {
      expect(recovery.isError('Success: done'), isFalse);
    });

    test('isError_emptyString_returnsFalse', () {
      expect(recovery.isError(''), isFalse);
    });

    test('isError_regularResult_returnsFalse', () {
      expect(recovery.isError('Opened youtube'), isFalse);
    });
  });

  group('analyze', () {
    test('analyze_nonError_returnsNull', () {
      final hint = recovery.analyze('calculator', '{}', '42');
      expect(hint, isNull);
    });

    test('analyze_unknownTool_returnsToolNotFound', () {
      final hint = recovery.analyze(
        'unknown',
        '{}',
        "Error: Unknown tool 'unknown'. Available: calculator",
      );
      expect(hint, isNotNull);
      expect(hint!.type, ErrorType.toolNotFound);
      expect(hint.shouldRetry, isFalse);
      expect(hint.promptNudge, contains('calculator'));
    });

    test('analyze_appNotInstalled_returnsAppNotInstalled', () {
      final hint = recovery.analyze(
        'app_launcher',
        '{"action": "open_app"}',
        'Error: Package "com.foo.bar" is not installed.',
      );
      expect(hint, isNotNull);
      expect(hint!.type, ErrorType.appNotInstalled);
      expect(hint.shouldRetry, isTrue);
      expect(hint.promptNudge, contains('list_apps'));
    });

    test('analyze_noAppsFound_returnsAppNotInstalled', () {
      final hint = recovery.analyze(
        'app_launcher',
        '{"query": "xyz"}',
        "No apps found matching 'xyz'",
      );
      expect(hint, isNull);
    });

    test('analyze_toolContextNotInit_returnsServiceUnavailable', () {
      final hint = recovery.analyze(
        'screen_action',
        '{}',
        'Error: ToolContext not initialized',
      );
      expect(hint, isNotNull);
      expect(hint!.type, ErrorType.serviceUnavailable);
      expect(hint.shouldRetry, isFalse);
      expect(
        hint.promptNudge,
        contains('enable the service'),
      );
    });

    test('analyze_accessibilityNotEnabled_returnsServiceUnavailable', () {
      final hint = recovery.analyze(
        'screen_action',
        '{}',
        'Error: Accessibility is not enabled',
      );
      expect(hint, isNotNull);
      expect(hint!.type, ErrorType.serviceUnavailable);
    });

    test('analyze_notificationNotEnabled_returnsServiceUnavailable', () {
      final hint = recovery.analyze(
        'notification_reader',
        '{}',
        'Error: Notification listener is not enabled',
      );
      expect(hint, isNotNull);
      expect(hint!.type, ErrorType.serviceUnavailable);
    });

    test('analyze_permissionDenied_returnsPermissionDenied', () {
      final hint = recovery.analyze(
        'phone_caller',
        '{}',
        'Error: Permission denied for phone calls',
      );
      expect(hint, isNotNull);
      expect(hint!.type, ErrorType.permissionDenied);
      expect(hint.shouldRetry, isFalse);
    });

    test('analyze_invalidAction_returnsInvalidAction', () {
      final hint = recovery.analyze(
        'screen_action',
        '{}',
        "Error: Unknown action 'jump'. Use tap, scroll.",
      );
      expect(hint, isNotNull);
      expect(hint!.type, ErrorType.invalidAction);
      expect(hint.shouldRetry, isTrue);
      expect(hint.promptNudge, contains('Invalid action'));
    });

    test('analyze_missingParameter_returnsMissingParameter', () {
      final hint = recovery.analyze(
        'screen_action',
        '{}',
        "Error: 'text' required",
      );
      expect(hint, isNotNull);
      expect(hint!.type, ErrorType.missingParameter);
      expect(hint.shouldRetry, isTrue);
      expect(hint.promptNudge, contains('Missing required'));
    });

    test('analyze_cancelledByUser_returnsCancelled', () {
      final hint = recovery.analyze(
        'phone_caller',
        '{}',
        'Action cancelled by user',
      );
      expect(hint, isNull);
    });

    test('analyze_genericError_returnsGeneric', () {
      final hint = recovery.analyze(
        'calculator',
        '{}',
        'Error: Cannot evaluate expression',
      );
      expect(hint, isNotNull);
      expect(hint!.type, ErrorType.generic);
      expect(hint.shouldRetry, isTrue);
    });

    test('analyze_userMessage_koreanForAppNotInstalled', () {
      final hint = recovery.analyze(
        'app_launcher',
        '{}',
        'Error: Package "com.test" is not installed.',
      );
      expect(hint, isNotNull);
      expect(hint!.userMessage, contains('\uC124\uCE58'));
    });

    test('analyze_userMessage_koreanForServiceUnavailable', () {
      final hint = recovery.analyze(
        'screen_action',
        '{}',
        'Error: Accessibility is not enabled',
      );
      expect(hint, isNotNull);
      expect(
        hint!.userMessage,
        contains('\uC11C\uBE44\uC2A4'),
      );
    });
  });

  group('canRetry', () {
    test('canRetry_initialState_returnsTrue', () {
      expect(recovery.canRetry('calculator'), isTrue);
    });

    test('canRetry_afterMaxRetries_returnsFalse', () {
      recovery.analyze('calculator', '{}', 'Error: fail 1');
      recovery.analyze('calculator', '{}', 'Error: fail 2');

      expect(recovery.canRetry('calculator'), isFalse);
    });

    test('canRetry_differentTools_trackedSeparately', () {
      recovery.analyze('calculator', '{}', 'Error: fail');
      recovery.analyze('calculator', '{}', 'Error: fail');

      expect(recovery.canRetry('calculator'), isFalse);
      expect(recovery.canRetry('timer'), isTrue);
    });

    test('canRetry_nonRetryableType_returnsFalseImmediately', () {
      recovery.analyze(
        'unknown',
        '{}',
        "Error: Unknown tool 'unknown'",
      );

      expect(recovery.canRetry('unknown'), isTrue);
    });
  });

  group('reset', () {
    test('reset_clearsRetryCount', () {
      recovery.analyze('calculator', '{}', 'Error: fail');
      recovery.analyze('calculator', '{}', 'Error: fail');

      expect(recovery.canRetry('calculator'), isFalse);

      recovery.reset();

      expect(recovery.canRetry('calculator'), isTrue);
    });

    test('reset_clearsTotalErrors', () {
      recovery.analyze('calculator', '{}', 'Error: fail');
      expect(recovery.totalErrors, 1);

      recovery.reset();

      expect(recovery.totalErrors, 0);
    });
  });

  group('totalErrors', () {
    test('totalErrors_noErrors_returnsZero', () {
      expect(recovery.totalErrors, 0);
    });

    test('totalErrors_tracksErrors', () {
      recovery.analyze('calculator', '{}', 'Error: fail 1');
      recovery.analyze('timer', '{}', 'Error: fail 2');
      recovery.analyze('screen_action', '{}', 'Error: fail 3');

      expect(recovery.totalErrors, 3);
    });

    test('totalErrors_ignoresNonErrors', () {
      recovery.analyze('calculator', '{}', '42');
      recovery.analyze('timer', '{}', 'done');

      expect(recovery.totalErrors, 0);
    });
  });

  group('retryBehavior', () {
    test('retryableError_firstAttempt_hasShouldRetry', () {
      final hint = recovery.analyze(
        'calculator',
        '{}',
        'Error: Cannot compute',
      );
      expect(hint!.shouldRetry, isTrue);
    });

    test('retryableError_secondAttempt_hasNoRetry', () {
      recovery.analyze('calculator', '{}', 'Error: fail 1');
      final hint = recovery.analyze(
        'calculator',
        '{}',
        'Error: fail 2',
      );
      expect(hint!.shouldRetry, isFalse);
    });

    test('appNotInstalled_firstAttempt_suggestsListApps', () {
      final hint = recovery.analyze(
        'app_launcher',
        '{"action":"open_app","package_name":"com.test"}',
        'Error: Package "com.test" is not installed.',
      );
      expect(hint!.shouldRetry, isTrue);
      expect(hint.promptNudge, contains('list_apps'));
    });

    test('cancelledByUser_notAnError', () {
      final hint = recovery.analyze(
        'phone_caller',
        '{}',
        'Action cancelled by user',
      );
      expect(hint, isNull);
    });
  });

  group('fallbackPromptNudge', () {
    test('toolNotFound_listsAvailableTools', () {
      final hint = recovery.analyze(
        'fake_tool',
        '{}',
        "Error: Unknown tool 'fake_tool'",
      );
      expect(hint!.promptNudge, contains('calculator'));
      expect(hint.promptNudge, contains('app_launcher'));
    });

    test('serviceUnavailable_suggestsSettings', () {
      final hint = recovery.analyze(
        'screen_action',
        '{}',
        'Error: ToolContext not initialized',
      );
      expect(
        hint!.promptNudge,
        contains('enable the service'),
      );
    });

    test('permissionDenied_suggestsGrantPermission', () {
      final hint = recovery.analyze(
        'sms_sender',
        '{}',
        'Error: Permission denied for SMS',
      );
      expect(
        hint!.promptNudge,
        contains('grant permission'),
      );
    });

    test('cancelled_emptyNudge', () {
      final hint = recovery.analyze(
        'phone_caller',
        '{}',
        'Action cancelled by user',
      );
      expect(hint, isNull);
    });
  });

  group('edgeCases', () {
    test('emptyAvailableTools_noThrow', () {
      final empty = ErrorRecovery();
      final hint = empty.analyze(
        'x',
        '{}',
        "Error: Unknown tool 'x'",
      );
      expect(hint, isNotNull);
    });

    test('longErrorMessage_handled', () {
      final longError = 'Error: ${'x' * 1000}';
      final hint = recovery.analyze('calc', '{}', longError);
      expect(hint, isNotNull);
      expect(hint!.type, ErrorType.generic);
    });

    test('specialCharsInError_handled', () {
      final hint = recovery.analyze(
        'calc',
        '{}',
        'Error: {"key": "value with \\"quotes\\""}',
      );
      expect(hint, isNotNull);
    });

    test('resetThenAnalyze_worksCorrectly', () {
      recovery.analyze('calc', '{}', 'Error: fail');
      recovery.analyze('calc', '{}', 'Error: fail');
      expect(recovery.canRetry('calc'), isFalse);

      recovery.reset();

      final hint = recovery.analyze('calc', '{}', 'Error: fail');
      expect(hint!.shouldRetry, isTrue);
    });
  });
}
