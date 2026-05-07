class UserMessageMapper {
  const UserMessageMapper._();

  static String map(String error) {
    final lower = error.toLowerCase();

    if (lower.contains('model') && lower.contains('not found')) {
      return 'No AI model found. Please import a model in Settings.';
    }
    if (lower.contains('model') && lower.contains('not loaded')) {
      return 'No AI model loaded. Please load a model in Settings.';
    }
    if (lower.contains('model') &&
        (lower.contains('load') || lower.contains('corrupt'))) {
      return 'Failed to load the AI model. Try a different model file.';
    }
    if (lower.contains('context') && lower.contains('exceeded')) {
      return 'Response too long. '
          'Try reducing max tokens or starting a new chat.';
    }
    if (lower.contains('sms') || lower.contains('message')) {
      return 'SMS could not be sent. Check signal and permissions.';
    }
    if (lower.contains('call') || lower.contains('phone')) {
      return 'Phone call could not be made. Check permissions.';
    }
    if (lower.contains('app') && lower.contains('not installed')) {
      return 'That app is not installed on your device.';
    }
    if (lower.contains('accessibility') && lower.contains('service')) {
      return 'Accessibility service is not enabled. '
          'Enable it in Settings > Accessibility.';
    }
    if (lower.contains('service') && lower.contains('not enabled')) {
      return 'Required service is not enabled. Check Settings.';
    }
    if (lower.contains('permission') && lower.contains('storage')) {
      return 'Storage permission is required. '
          'Enable it in Settings > Apps > AIOS > Permissions.';
    }
    if (lower.contains('permission')) {
      return 'Permission is required. '
          'Enable it in Settings > Apps > AIOS > Permissions.';
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return 'Network connection error. Check your internet.';
    }
    if (lower.contains('timeout')) {
      return 'The request timed out. Please try again.';
    }
    if (lower.contains('cancel')) {
      return 'The action was cancelled.';
    }

    return 'An unexpected error occurred. Please try again.';
  }
}
