import 'package:aios/domain/agent/tool_result.dart';

enum ErrorType {
  toolNotFound,
  appNotInstalled,
  serviceUnavailable,
  permissionDenied,
  invalidAction,
  missingParameter,
  cancelled,
  generic,
}

class RecoveryHint {
  final ErrorType type;
  final String userMessage;
  final String promptNudge;
  final bool shouldRetry;

  const RecoveryHint({
    required this.type,
    required this.userMessage,
    required this.promptNudge,
    required this.shouldRetry,
  });
}

class ErrorRecovery {
  static const _maxRetries = 1;

  final Set<String> _availableTools;
  final Map<String, int> _retryCount = {};
  int _totalErrors = 0;

  ErrorRecovery({Set<String>? availableTools})
    : _availableTools = availableTools ?? {};

  void reset() {
    _retryCount.clear();
    _totalErrors = 0;
  }

  bool isErrorString(String observation) =>
      observation.trimLeft().startsWith('Error:');

  bool isError(ToolResult result) => result.isError;

  bool canRetry(String toolName) => (_retryCount[toolName] ?? 0) < _maxRetries;

  RecoveryHint? analyze(String toolName, String args, ToolResult result) {
    if (!result.isError) return null;

    _totalErrors++;
    final observation = result.toContent();
    final type = _categorize(observation);
    final retryAvailable = canRetry(toolName);

    if (retryAvailable && _isRetryable(type)) {
      _retryCount[toolName] = (_retryCount[toolName] ?? 0) + 1;
      return RecoveryHint(
        type: type,
        userMessage: _userMessage(type),
        promptNudge: _retryPromptNudge(toolName, type),
        shouldRetry: true,
      );
    }

    return RecoveryHint(
      type: type,
      userMessage: _userMessage(type),
      promptNudge: _fallbackPromptNudge(type),
      shouldRetry: false,
    );
  }

  int get totalErrors => _totalErrors;

  ErrorType _categorize(String observation) {
    final lower = observation.toLowerCase();

    if (lower.contains('unknown tool')) return ErrorType.toolNotFound;
    if (lower.contains('not installed') || lower.contains('no apps found')) {
      return ErrorType.appNotInstalled;
    }
    if (lower.contains('toolcontext not initialized') ||
        lower.contains('accessibility') && lower.contains('not enabled') ||
        lower.contains('notification') && lower.contains('not enabled')) {
      return ErrorType.serviceUnavailable;
    }
    if (lower.contains('permission') || lower.contains('denied')) {
      return ErrorType.permissionDenied;
    }
    if (lower.contains('unknown action')) return ErrorType.invalidAction;
    if (lower.contains('required')) return ErrorType.missingParameter;
    if (lower.contains('cancelled by user')) return ErrorType.cancelled;

    return ErrorType.generic;
  }

  bool _isRetryable(ErrorType type) =>
      type == ErrorType.invalidAction ||
      type == ErrorType.missingParameter ||
      type == ErrorType.appNotInstalled ||
      type == ErrorType.generic;

  String _userMessage(ErrorType type) => switch (type) {
    ErrorType.toolNotFound =>
      '\uC694\uCCAD\uD55C \uB3C4\uAD6C\uB97C \uCC3E\uC744 \uC218 \uC5C6\uC2B5\uB2C8\uB2E4.',
    ErrorType.appNotInstalled =>
      '\uD574\uB2F9 \uC571\uC774 \uC124\uCE58\uB418\uC5B4 \uC788\uC9C0 \uC54A\uC2B5\uB2C8\uB2E4.',
    ErrorType.serviceUnavailable =>
      '\uD544\uC694\uD55C \uC11C\uBE44\uC2A4\uAC00 \uD65C\uC131\uD654\uB418\uC9C0 '
          '\uC54A\uC558\uC2B5\uB2C8\uB2E4. \uC124\uC815\uC5D0\uC11C '
          '\uD65C\uC131\uD654\uD574\uC8FC\uC138\uC694.',
    ErrorType.permissionDenied =>
      '\uAD8C\uD55C\uC774 \uAC70\uBD80\uB418\uC5C8\uC2B5\uB2C8\uB2E4. '
          '\uC124\uC815\uC5D0\uC11C \uAD8C\uD55C\uC744 \uD5C8\uC6A9\uD574\uC8FC\uC138\uC694.',
    ErrorType.invalidAction =>
      '\uC798\uBABB\uB41C \uBA85\uB839\uC785\uB2C8\uB2E4. '
          '\uC62C\uBC14\uB978 \uD615\uC2DD\uC73C\uB85C \uB2E4\uC2DC '
          '\uC2DC\uB3C4\uD574\uC8FC\uC138\uC694.',
    ErrorType.missingParameter =>
      '\uD544\uC218 \uD56D\uBAA9\uC774 \uB204\uB77D\uB418\uC5C8\uC2B5\uB2C8\uB2E4.',
    ErrorType.cancelled =>
      '\uC0AC\uC6A9\uC790\uAC00 \uC791\uC5C5\uC744 \uCDE8\uC18C\uD588\uC2B5\uB2C8\uB2E4.',
    ErrorType.generic =>
      '\uC624\uB958\uAC00 \uBC1C\uC0DD\uD588\uC2B5\uB2C8\uB2E4. '
          '\uB2E4\uC2DC \uC2DC\uB3C4\uD574\uC8FC\uC138\uC694.',
  };

  String _retryPromptNudge(String toolName, ErrorType type) {
    return switch (type) {
      ErrorType.appNotInstalled =>
        'RECOVERY: App not found. '
            'Try "list_apps" action to search for the correct '
            'app, or Answer explaining it is not installed.',
      ErrorType.invalidAction =>
        'RECOVERY: Invalid action for $toolName. '
            'Check available actions and retry with correct name.',
      ErrorType.missingParameter =>
        'RECOVERY: Missing required parameter. '
            'You MUST provide all parameters as a JSON object. '
            'Call the same tool again with the correct parameters.',
      ErrorType.generic =>
        'RECOVERY: Tool failed. '
            'Try different approach or Answer with error details.',
      ErrorType.toolNotFound ||
      ErrorType.serviceUnavailable ||
      ErrorType.permissionDenied ||
      ErrorType.cancelled => 'RECOVERY: Try again or Answer the user.',
    };
  }

  String _fallbackPromptNudge(ErrorType type) {
    return switch (type) {
      ErrorType.toolNotFound =>
        'RECOVERY: Unknown tool. '
            'Available: ${_availableTools.join(", ")}. '
            'Use one of these or Answer the user.',
      ErrorType.serviceUnavailable =>
        'RECOVERY: Service unavailable. '
            'Answer the user explaining they need to enable '
            'the service in Settings.',
      ErrorType.permissionDenied =>
        'RECOVERY: Permission denied. '
            'Answer the user explaining they need to grant '
            'permission in Settings.',
      ErrorType.cancelled => '',
      ErrorType.appNotInstalled ||
      ErrorType.invalidAction ||
      ErrorType.missingParameter ||
      ErrorType.generic => 'RECOVERY: Provide Answer explaining what happened.',
    };
  }
}
