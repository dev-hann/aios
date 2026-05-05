import 'package:aios/domain/agent/risk_classifier.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RiskClassifier classifier;

  setUp(() {
    classifier = RiskClassifier();
  });

  group('classifyRisk_safeTools', () {
    test('calculator is safe', () {
      expect(classifier.classify('calculator', '{}'), ToolRisk.safe);
    });

    test('timer is safe', () {
      expect(classifier.classify('timer', '{}'), ToolRisk.safe);
    });

    test('device_info is safe', () {
      expect(classifier.classify('device_info', '{}'), ToolRisk.safe);
    });

    test('notepad is safe', () {
      expect(classifier.classify('notepad', '{}'), ToolRisk.safe);
    });

    test('screen_reader is safe', () {
      expect(classifier.classify('screen_reader', '{}'), ToolRisk.safe);
    });

    test('screen_find is safe', () {
      expect(classifier.classify('screen_find', '{}'), ToolRisk.safe);
    });

    test('notification_reader is safe', () {
      expect(
        classifier.classify('notification_reader', '{}'),
        ToolRisk.safe,
      );
    });

    test('contact_search is safe', () {
      expect(classifier.classify('contact_search', '{}'), ToolRisk.safe);
    });
  });

  group('classifyRisk_smsSender', () {
    test('send is critical', () {
      expect(
        classifier.classify('sms_sender', '{"action": "send"}'),
        ToolRisk.critical,
      );
    });

    test('read is high', () {
      expect(
        classifier.classify('sms_sender', '{"action": "read"}'),
        ToolRisk.high,
      );
    });
  });

  group('classifyRisk_phoneCaller', () {
    test('call is critical', () {
      expect(
        classifier.classify('phone_caller', '{"action": "call"}'),
        ToolRisk.critical,
      );
    });

    test('dial is high', () {
      expect(
        classifier.classify('phone_caller', '{"action": "dial"}'),
        ToolRisk.high,
      );
    });
  });

  group('classifyRisk_screenAction', () {
    test('tap is high', () {
      expect(
        classifier.classify('screen_action', '{"action": "tap"}'),
        ToolRisk.high,
      );
    });

    test('global is low', () {
      expect(
        classifier.classify('screen_action', '{"action": "global"}'),
        ToolRisk.low,
      );
    });

    test('type password is critical', () {
      expect(
        classifier.classify(
          'screen_action',
          '{"action": "type", "content": "enter your password"}',
        ),
        ToolRisk.critical,
      );
    });

    test('type pin is critical', () {
      expect(
        classifier.classify(
          'screen_action',
          '{"action": "type", "content": "enter your pin"}',
        ),
        ToolRisk.critical,
      );
    });

    test('type cvv is critical', () {
      expect(
        classifier.classify(
          'screen_action',
          '{"action": "type", "content": "cvv code"}',
        ),
        ToolRisk.critical,
      );
    });

    test('type otp is critical', () {
      expect(
        classifier.classify(
          'screen_action',
          '{"action": "type", "content": "otp verification"}',
        ),
        ToolRisk.critical,
      );
    });

    test('type normal text is high', () {
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
    test('open_app is high', () {
      expect(
        classifier.classify('app_launcher', '{"action": "open_app"}'),
        ToolRisk.high,
      );
    });

    test('open_settings is low', () {
      expect(
        classifier.classify('app_launcher', '{"action": "open_settings"}'),
        ToolRisk.low,
      );
    });
  });

  group('classifyRisk_edgeCases', () {
    test('unknown tool is high', () {
      expect(
        classifier.classify('nonexistent_tool', '{}'),
        ToolRisk.high,
      );
    });

    test('invalid json defaults action to empty', () {
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

    test('case insensitive action', () {
      expect(
        classifier.classify('sms_sender', '{"action": "SEND"}'),
        ToolRisk.critical,
      );
      expect(
        classifier.classify('phone_caller', '{"action": "CALL"}'),
        ToolRisk.critical,
      );
    });
  });
}
