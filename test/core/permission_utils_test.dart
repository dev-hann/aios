import 'package:aios/core/permission_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('permissionFromKey', () {
    test('permissionFromKey_contacts_returnsPermissionContacts', () {
      expect(permissionFromKey('contacts'), Permission.contacts);
    });

    test('permissionFromKey_phone_returnsPermissionPhone', () {
      expect(permissionFromKey('phone'), Permission.phone);
    });

    test('permissionFromKey_sms_returnsPermissionSms', () {
      expect(permissionFromKey('sms'), Permission.sms);
    });

    test('permissionFromKey_unknown_returnsNull', () {
      expect(permissionFromKey('unknown'), isNull);
    });

    test('permissionFromKey_empty_returnsNull', () {
      expect(permissionFromKey(''), isNull);
    });

    test('permissionFromKey_accessibility_returnsNull', () {
      expect(permissionFromKey('accessibility'), isNull);
    });

    test('permissionFromKey_notification_returnsNull', () {
      expect(permissionFromKey('notification'), isNull);
    });
  });
}
