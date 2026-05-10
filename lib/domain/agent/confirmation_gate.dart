import 'package:aios/domain/agent/gate_completer.dart';
import 'package:aios/domain/entities/agent_models.dart';

class ConfirmationGate extends GateCompleter {
  static const _tag = 'AIOS-ConfirmationGate';

  Future<bool> requestConfirmation(
    ToolRisk risk,
    String toolName,
    String args,
    void Function(AgentStep) onStep,
  ) async {
    createCompleter();

    onStep(
      AgentStep(
        'confirmation_required',
        'Requires confirmation: $toolName',
        toolName: toolName,
        toolArgs: args,
        riskLevel: risk.name,
      ),
    );

    return waitForResolution(
      timeout: const Duration(seconds: 60),
      tag: _tag,
      label: 'confirmation for $toolName',
    );
  }
}
