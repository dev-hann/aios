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

  static RequiredPermission? getRequiredPermission(
    String toolName,
    String argsJson,
  ) {
    switch (toolName) {
      case 'contact_search':
        return RequiredPermission(
          key: 'contacts',
          displayName: Strings.permDisplay.contacts,
          isService: false,
        );
      case 'phone_caller':
        if (argsJson.contains('"call"')) {
          return RequiredPermission(
            key: 'phone',
            displayName: Strings.permDisplay.phone,
            isService: false,
          );
        }
        return null;
      case 'sms_sender':
        return RequiredPermission(
          key: 'sms',
          displayName: Strings.permDisplay.sms,
          isService: false,
        );
      case 'screen_action':
      case 'screen_reader':
      case 'screen_find':
        return RequiredPermission(
          key: 'accessibility',
          displayName: Strings.permDisplay.accessibilityService,
          isService: true,
        );
      case 'notification_reader':
        return RequiredPermission(
          key: 'notification',
          displayName: Strings.permDisplay.notificationAccess,
          isService: true,
        );
      default:
        return null;
    }
  }

  static RequiredPermission? getByKey(String key) {
    return switch (key) {
      'contacts' => RequiredPermission(
        key: 'contacts',
        displayName: Strings.permDisplay.contacts,
        isService: false,
      ),
      'phone' => RequiredPermission(
        key: 'phone',
        displayName: Strings.permDisplay.phone,
        isService: false,
      ),
      'sms' => RequiredPermission(
        key: 'sms',
        displayName: Strings.permDisplay.sms,
        isService: false,
      ),
      'accessibility' => RequiredPermission(
        key: 'accessibility',
        displayName: Strings.permDisplay.accessibilityService,
        isService: true,
      ),
      'notification' => RequiredPermission(
        key: 'notification',
        displayName: Strings.permDisplay.notificationAccess,
        isService: true,
      ),
      _ => null,
    };
  }
}
