import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/domain/agent/gate_completer.dart';
import 'package:aios/domain/agent/tool_permission_mapper.dart';
import 'package:aios/domain/entities/agent_models.dart';

typedef PermissionChecker = Future<bool> Function(String permissionKey);

class PermissionGate extends GateCompleter {
  static const _tag = 'AIOS-PermissionGate';

  Future<bool> requestPermission(
    RequiredPermission permission,
    String toolName,
    void Function(AgentStep) onStep,
  ) async {
    createCompleter();

    onStep(
      AgentStep(
        'permission_required',
        Strings.agent.permissionRequired(permission.displayName),
        toolName: toolName,
        permission: permission.key,
      ),
    );

    print('[$_tag] Awaiting permission: ${permission.key} for $toolName');

    return waitForResolution(
      timeout: const Duration(seconds: 120),
      tag: _tag,
      label: 'permission ${permission.key}',
    );
  }
}
