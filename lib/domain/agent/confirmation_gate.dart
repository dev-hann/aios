import 'dart:async';

import 'package:aios/domain/entities/agent_models.dart';

class ConfirmationGate {
  Completer<bool>? _completer;

  Future<bool> requestConfirmation(
    ToolRisk risk,
    String toolName,
    String args,
    void Function(AgentStep) onStep,
  ) async {
    _completer = Completer<bool>();

    onStep(
      AgentStep(
        'confirmation_required',
        'Requires confirmation: $toolName',
        toolName: toolName,
        toolArgs: args,
        riskLevel: risk.name,
      ),
    );

    try {
      return await _completer!.future.timeout(
        const Duration(seconds: 60),
      );
    } on TimeoutException {
      return false;
    }
  }

  void resolve(bool approved) {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(approved);
    }
  }

  void cancel() {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(false);
    }
  }
}
