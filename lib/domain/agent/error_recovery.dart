import 'package:aios/core/theme/app_strings.dart';
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
  const RecoveryHint({
    required this.type,
    required this.userMessage,
    required this.promptNudge,
    required this.shouldRetry,
  });
  final ErrorType type;
  final String userMessage;
  final String promptNudge;
  final bool shouldRetry;
}

class ErrorRecovery {
  ErrorRecovery({Set<String>? availableTools})
    : _availableTools = availableTools ?? {};
  static const _maxRetries = 1;

  final Set<String> _availableTools;
  final Map<String, int> _retryCount = {};
  int _totalErrors = 0;

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
    ErrorType.toolNotFound => Strings.errorRecovery.toolNotFound,
    ErrorType.appNotInstalled => Strings.errorRecovery.appNotInstalled,
    ErrorType.serviceUnavailable => Strings.errorRecovery.serviceUnavailable,
    ErrorType.permissionDenied => Strings.errorRecovery.permissionDenied,
    ErrorType.invalidAction => Strings.errorRecovery.invalidAction,
    ErrorType.missingParameter => Strings.errorRecovery.missingParameter,
    ErrorType.cancelled => Strings.errorRecovery.cancelled,
    ErrorType.generic => Strings.errorRecovery.generic,
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
