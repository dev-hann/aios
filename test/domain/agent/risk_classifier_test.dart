import 'package:aios/domain/agent/risk_classifier.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RiskClassifier classifier;

  setUp(() {
    classifier = RiskClassifier();
  });

  group('classifyRisk_safeTools', () {
    test('classify_calculator_returnsSafe', () {
      expect(classifier.classify('calculator', '{}'), ToolRisk.safe);
    });

    test('classify_timer_returnsSafe', () {
      expect(classifier.classify('timer', '{}'), ToolRisk.safe);
    });

    test('classify_deviceInfo_returnsSafe', () {
      expect(classifier.classify('device_info', '{}'), ToolRisk.safe);
    });

    test('classify_notepad_returnsSafe', () {
      expect(classifier.classify('notepad', '{}'), ToolRisk.safe);
    });

    test('classify_screenReader_returnsSafe', () {
      expect(classifier.classify('screen_reader', '{}'), ToolRisk.safe);
    });

    test('classify_screenFind_returnsSafe', () {
      expect(classifier.classify('screen_find', '{}'), ToolRisk.safe);
    });

    test('classify_notificationReader_returnsSafe', () {
      expect(
        classifier.classify('notification_reader', '{}'),
        ToolRisk.safe,
      );
    });

    test('classify_contactSearch_returnsSafe', () {
      expect(classifier.classify('contact_search', '{}'), ToolRisk.safe);
    });
  });

  group('classifyRisk_smsSender', () {
    test('classify_smsSenderSend_returnsCritical', () {
      expect(
        classifier.classify('sms_sender', '{"action": "send"}'),
        ToolRisk.critical,
      );
    });

    test('classify_smsSenderRead_returnsHigh', () {
      expect(
        classifier.classify('sms_sender', '{"action": "read"}'),
        ToolRisk.high,
      );
    });
  });

  group('classifyRisk_phoneCaller', () {
    test('classify_phoneCallerCall_returnsCritical', () {
      expect(
        classifier.classify('phone_caller', '{"action": "call"}'),
        ToolRisk.critical,
      );
    });

    test('classify_phoneCallerDial_returnsHigh', () {
      expect(
        classifier.classify('phone_caller', '{"action": "dial"}'),
        ToolRisk.high,
      );
    });
  });

  group('classifyRisk_screenAction', () {
    test('classify_screenActionTap_returnsHigh', () {
      expect(
        classifier.classify('screen_action', '{"action": "tap"}'),
        ToolRisk.high,
      );
    });

    test('classify_screenActionGlobal_returnsLow', () {
      expect(
        classifier.classify('screen_action', '{"action": "global"}'),
        ToolRisk.low,
      );
    });

    test('classify_screenActionTypePassword_returnsCritical', () {
      expect(
        classifier.classify(
          'screen_action',
          '{"action": "type", "content": "enter your password"}',
        ),
        ToolRisk.critical,
      );
    });

    test('classify_screenActionTypePin_returnsCritical', () {
      expect(
        classifier.classify(
          'screen_action',
          '{"action": "type", "content": "enter your pin"}',
        ),
        ToolRisk.critical,
      );
    });

    test('classify_screenActionTypeCvv_returnsCritical', () {
      expect(
        classifier.classify(
          'screen_action',
          '{"action": "type", "content": "cvv code"}',
        ),
        ToolRisk.critical,
      );
    });

    test('classify_screenActionTypeOtp_returnsCritical', () {
      expect(
        classifier.classify(
          'screen_action',
          '{"action": "type", "content": "otp verification"}',
        ),
        ToolRisk.critical,
      );
    });

    test('classify_screenActionTypeNormal_returnsHigh', () {
      expect(
        classifier.classify(
          'screen_action',
          '{"action": "type", "content": "hello world"}',
        ),
        ToolRisk.high,
      );
    });
  });

  group('classifyRisk_appLauncher', () {
    test('classify_appLauncherOpenApp_returnsHigh', () {
      expect(
        classifier.classify('app_launcher', '{"action": "open_app"}'),
        ToolRisk.high,
      );
    });

    test('classify_appLauncherOpenSettings_returnsLow', () {
      expect(
        classifier.classify('app_launcher', '{"action": "open_settings"}'),
        ToolRisk.low,
      );
    });
  });

  group('classifyRisk_edgeCases', () {
    test('classify_unknownTool_returnsHigh', () {
      expect(
        classifier.classify('nonexistent_tool', '{}'),
        ToolRisk.high,
      );
    });

    test('classify_invalidJson_defaultsToEmptyAction', () {
      expect(classifier.classify('calculator', 'not json'), ToolRisk.safe);
      expect(
        classifier.classify('screen_action', 'not json'),
        ToolRisk.high,
      );
      expect(
        classifier.classify('app_launcher', 'not json'),
        ToolRisk.low,
      );
    });

    test('classify_caseInsensitiveAction_classifiesCorrectly', () {
      expect(
        classifier.classify('sms_sender', '{"action": "SEND"}'),
        ToolRisk.critical,
      );
      expect(
        classifier.classify('phone_caller', '{"action": "CALL"}'),
        ToolRisk.critical,
      );
    });

    test('classify_emptyArgs_defaultsAppropriately', () {
      expect(classifier.classify('calculator', ''), ToolRisk.safe);
      expect(classifier.classify('screen_action', ''), ToolRisk.high);
    });

    test('classify_appLauncherListApps_returnsLow', () {
      expect(
        classifier.classify('app_launcher', '{"action": "list_apps"}'),
        ToolRisk.low,
      );
    });

    test('classify_appLauncherOpenUrl_returnsHigh', () {
      expect(
        classifier.classify('app_launcher', '{"action": "open_url"}'),
        ToolRisk.high,
      );
    });

    test('classify_screenActionTypeSsn_returnsCritical', () {
      expect(
        classifier.classify(
          'screen_action',
          '{"action": "type", "content": "enter your ssn"}',
        ),
        ToolRisk.critical,
      );
    });

    test('classify_screenActionTypePasscode_returnsCritical', () {
      expect(
        classifier.classify(
          'screen_action',
          '{"action": "type", "content": "passcode"}',
        ),
        ToolRisk.critical,
      );
    });

    test('classify_screenActionTypeSocialSecurity_returnsCritical', () {
      expect(
        classifier.classify(
          'screen_action',
          '{"action": "type", "content": "enter your social security number"}',
        ),
        ToolRisk.critical,
      );
    });

    test('classify_screenActionLongClick_returnsHigh', () {
      expect(
        classifier.classify('screen_action', '{"action": "long_click"}'),
        ToolRisk.high,
      );
    });

    test('classify_screenActionScroll_returnsHigh', () {
      expect(
        classifier.classify('screen_action', '{"action": "scroll"}'),
        ToolRisk.high,
      );
    });

    test('classify_screenActionSwipe_returnsHigh', () {
      expect(
        classifier.classify('screen_action', '{"action": "swipe"}'),
        ToolRisk.high,
      );
    });

    test('classify_allSafeToolsWithAnyArgs_remainSafe', () {
      for (final tool in [
        'calculator',
        'timer',
        'device_info',
        'notepad',
        'screen_reader',
        'screen_find',
        'notification_reader',
        'contact_search',
      ]) {
        expect(
          classifier.classify(tool, '{"random": "args"}'),
          ToolRisk.safe,
          reason: '$tool should be safe regardless of args',
        );
      }
    });
  });
}
