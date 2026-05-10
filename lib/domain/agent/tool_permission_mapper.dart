import 'package:aios/core/theme/app_strings.dart';

class RequiredPermission {
  const RequiredPermission({
    required this.key,
    required this.displayName,
    required this.isService,
  });

  final String key;
  final String displayName;
  final bool isService;
}

class ToolPermissionMapper {
  const ToolPermissionMapper._();

  static final _contacts = RequiredPermission(
    key: 'contacts',
    displayName: Strings.permDisplay.contacts,
    isService: false,
  );

  static final _phone = RequiredPermission(
    key: 'phone',
    displayName: Strings.permDisplay.phone,
    isService: false,
  );

  static final _sms = RequiredPermission(
    key: 'sms',
    displayName: Strings.permDisplay.sms,
    isService: false,
  );

  static final _accessibility = RequiredPermission(
    key: 'accessibility',
    displayName: Strings.permDisplay.accessibilityService,
    isService: true,
  );

  static final _notification = RequiredPermission(
    key: 'notification',
    displayName: Strings.permDisplay.notificationAccess,
    isService: true,
  );

  static RequiredPermission? getRequiredPermission(
    String toolName,
    String argsJson,
  ) {
    switch (toolName) {
      case 'contact_search':
        return _contacts;
      case 'phone_caller':
        if (argsJson.contains('"call"')) return _phone;
        return null;
      case 'sms_sender':
        return _sms;
      case 'screen_action':
      case 'screen_reader':
      case 'screen_find':
        return _accessibility;
      case 'notification_reader':
        return _notification;
      default:
        return null;
    }
  }

  static RequiredPermission? getByKey(String key) {
    return switch (key) {
      'contacts' => _contacts,
      'phone' => _phone,
      'sms' => _sms,
      'accessibility' => _accessibility,
      'notification' => _notification,
      _ => null,
    };
  }
}
