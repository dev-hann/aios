import 'package:aios/core/theme/app_strings.dart';

class UserMessageMapper {
  const UserMessageMapper._();

  static String map(String error) {
    final lower = error.toLowerCase();

    if (lower.contains('model') && lower.contains('not found')) {
      return Strings.userMessages.modelNotFound;
    }
    if (lower.contains('model') && lower.contains('not loaded')) {
      return Strings.userMessages.modelNotLoaded;
    }
    if (lower.contains('model') &&
        (lower.contains('load') || lower.contains('corrupt'))) {
      return Strings.userMessages.modelLoadFailed;
    }
    if (lower.contains('context') && lower.contains('exceeded')) {
      return Strings.userMessages.contextExceeded;
    }
    if (lower.contains('sms') || lower.contains('message')) {
      return Strings.userMessages.smsFailed;
    }
    if (lower.contains('call') || lower.contains('phone')) {
      return Strings.userMessages.callFailed;
    }
    if (lower.contains('app') && lower.contains('not installed')) {
      return Strings.userMessages.appNotInstalled;
    }
    if (lower.contains('accessibility') && lower.contains('service')) {
      return Strings.userMessages.accessibilityNotEnabled;
    }
    if (lower.contains('service') && lower.contains('not enabled')) {
      return Strings.userMessages.serviceNotEnabled;
    }
    if (lower.contains('permission') && lower.contains('storage')) {
      return Strings.userMessages.storagePermission;
    }
    if (lower.contains('permission')) {
      return Strings.userMessages.permissionRequired;
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return Strings.userMessages.networkError;
    }
    if (lower.contains('timeout')) {
      return Strings.userMessages.timeout;
    }
    if (lower.contains('cancel')) {
      return Strings.userMessages.cancelled;
    }

    return Strings.userMessages.unexpected;
  }
}
