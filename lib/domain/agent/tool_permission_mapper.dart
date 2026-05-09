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

  static const _permissionMap = <String, RequiredPermission>{
    'contacts': RequiredPermission(
      key: 'contacts',
      displayName: '연락처',
      isService: false,
    ),
    'phone': RequiredPermission(
      key: 'phone',
      displayName: '전화',
      isService: false,
    ),
    'sms': RequiredPermission(
      key: 'sms',
      displayName: 'SMS',
      isService: false,
    ),
    'accessibility': RequiredPermission(
      key: 'accessibility',
      displayName: '접근성 서비스',
      isService: true,
    ),
    'notification': RequiredPermission(
      key: 'notification',
      displayName: '알림 접근',
      isService: true,
    ),
  };

  static RequiredPermission? getRequiredPermission(
    String toolName,
    String argsJson,
  ) {
    switch (toolName) {
      case 'contact_search':
        return _permissionMap['contacts'];
      case 'phone_caller':
        if (argsJson.contains('"call"')) {
          return _permissionMap['phone'];
        }
        return null;
      case 'sms_sender':
        return _permissionMap['sms'];
      case 'screen_action':
      case 'screen_reader':
      case 'screen_find':
        return _permissionMap['accessibility'];
      case 'notification_reader':
        return _permissionMap['notification'];
      default:
        return null;
    }
  }

  static RequiredPermission? getByKey(String key) =>
      _permissionMap[key];
}
