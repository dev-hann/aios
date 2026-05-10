import 'package:aios/domain/agent/tool_permission_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ToolPermissionMapper', () {
    group('getRequiredPermission', () {
      test('getRequiredPermission_contactSearch_returnsContactsPermission', () {
        final perm = ToolPermissionMapper.getRequiredPermission(
          'contact_search',
          '{}',
        );
        expect(perm, isNotNull);
        expect(perm!.key, 'contacts');
        expect(perm.displayName, '연락처');
        expect(perm.isService, isFalse);
      });

      test('getRequiredPermission_smsSender_returnsSmsPermission', () {
        final perm = ToolPermissionMapper.getRequiredPermission(
          'sms_sender',
          '{"action":"send"}',
        );
        expect(perm, isNotNull);
        expect(perm!.key, 'sms');
        expect(perm.isService, isFalse);
      });

      test('getRequiredPermission_phoneCallerCall_returnsPhonePermission', () {
        final perm = ToolPermissionMapper.getRequiredPermission(
          'phone_caller',
          '{"action":"call"}',
        );
        expect(perm, isNotNull);
        expect(perm!.key, 'phone');
      });

      test('getRequiredPermission_phoneCallerDial_returnsNull', () {
        final perm = ToolPermissionMapper.getRequiredPermission(
          'phone_caller',
          '{"action":"dial"}',
        );
        expect(perm, isNull);
      });

      test('getRequiredPermission_screenAction_returnsAccessibility', () {
        final perm = ToolPermissionMapper.getRequiredPermission(
          'screen_action',
          '{"action":"tap"}',
        );
        expect(perm, isNotNull);
        expect(perm!.key, 'accessibility');
        expect(perm.isService, isTrue);
      });

      test('getRequiredPermission_screenReader_returnsAccessibility', () {
        final perm = ToolPermissionMapper.getRequiredPermission(
          'screen_reader',
          '{}',
        );
        expect(perm, isNotNull);
        expect(perm!.key, 'accessibility');
      });

      test('getRequiredPermission_screenFind_returnsAccessibility', () {
        final perm = ToolPermissionMapper.getRequiredPermission(
          'screen_find',
          '{"text":"test"}',
        );
        expect(perm, isNotNull);
        expect(perm!.key, 'accessibility');
      });

      test('getRequiredPermission_notificationReader_returnsNotification', () {
        final perm = ToolPermissionMapper.getRequiredPermission(
          'notification_reader',
          '{}',
        );
        expect(perm, isNotNull);
        expect(perm!.key, 'notification');
        expect(perm.isService, isTrue);
      });

      test('getRequiredPermission_calculator_returnsNull', () {
        final perm = ToolPermissionMapper.getRequiredPermission(
          'calculator',
          '{"expression":"1+1"}',
        );
        expect(perm, isNull);
      });

      test('getRequiredPermission_unknownTool_returnsNull', () {
        final perm = ToolPermissionMapper.getRequiredPermission(
          'unknown_tool',
          '{}',
        );
        expect(perm, isNull);
      });
    });

    group('getByKey', () {
      test('getByKey_contacts_returnsPermission', () {
        final perm = ToolPermissionMapper.getByKey('contacts');
        expect(perm, isNotNull);
        expect(perm!.key, 'contacts');
        expect(perm.isService, isFalse);
      });

      test('getByKey_phone_returnsPermission', () {
        final perm = ToolPermissionMapper.getByKey('phone');
        expect(perm, isNotNull);
        expect(perm!.key, 'phone');
        expect(perm.isService, isFalse);
      });

      test('getByKey_sms_returnsPermission', () {
        final perm = ToolPermissionMapper.getByKey('sms');
        expect(perm, isNotNull);
        expect(perm!.key, 'sms');
        expect(perm.isService, isFalse);
      });

      test('getByKey_accessibility_returnsServicePermission', () {
        final perm = ToolPermissionMapper.getByKey('accessibility');
        expect(perm, isNotNull);
        expect(perm!.isService, isTrue);
      });

      test('getByKey_notification_returnsServicePermission', () {
        final perm = ToolPermissionMapper.getByKey('notification');
        expect(perm, isNotNull);
        expect(perm!.isService, isTrue);
      });

      test('getByKey_unknown_returnsNull', () {
        final perm = ToolPermissionMapper.getByKey('nonexistent');
        expect(perm, isNull);
      });

      test('getByKey_returnsSameInstanceForSameKey', () {
        final a = ToolPermissionMapper.getByKey('contacts');
        final b = ToolPermissionMapper.getByKey('contacts');
        expect(identical(a, b), isTrue);
      });

      test('getRequiredPermission_sharesInstanceWithGetByKey', () {
        final fromGetByKey = ToolPermissionMapper.getByKey('contacts');
        final fromRequired = ToolPermissionMapper.getRequiredPermission(
          'contact_search',
          '{}',
        );
        expect(identical(fromGetByKey, fromRequired), isTrue);
      });
    });

    group('RequiredPermission', () {
      test('requiredPermission_fields_matchConstructor', () {
        const perm = RequiredPermission(
          key: 'test',
          displayName: 'Test Permission',
          isService: true,
        );
        expect(perm.key, 'test');
        expect(perm.displayName, 'Test Permission');
        expect(perm.isService, isTrue);
      });
    });
  });
}
