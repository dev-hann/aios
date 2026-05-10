import 'dart:async';

import 'package:aios/domain/agent/tool_permission_mapper.dart';
import 'package:aios/domain/entities/agent_models.dart';

typedef PermissionChecker = Future<bool> Function(String permissionKey);

class PermissionGate {
  Completer<bool>? _completer;

  Future<bool> requestPermission(
    RequiredPermission permission,
    String toolName,
    void Function(AgentStep) onStep,
  ) async {
    _completer = Completer<bool>();

    onStep(
      AgentStep(
        'permission_required',
        '${permission.displayName} 권한이 필요합니다',
        toolName: toolName,
        permission: permission.key,
      ),
    );

    print(
      '[AIOS-PermissionGate] '
      'Awaiting permission: ${permission.key} for $toolName',
    );

    try {
      return await _completer!.future.timeout(const Duration(seconds: 120));
    } on TimeoutException {
      print(
        '[AIOS-PermissionGate] '
        'Timeout waiting for permission: ${permission.key}',
      );
      return false;
    }
  }

  void resolve(bool granted) {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(granted);
    }
  }

  void cancel() {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(false);
    }
  }
}
