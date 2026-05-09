import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent_models.freezed.dart';
part 'agent_models.g.dart';

enum ToolRisk { safe, low, high, critical }

@freezed
class AgentStep with _$AgentStep {
  const factory AgentStep(
    String type,
    String content, {
    @Default('') String toolName,
    @Default('') String toolArgs,
    @Default('') String toolResult,
    @Default('') String riskLevel,
    @Default('') String phase,
    @Default(0) int retryAttempt,
    @Default(0) int maxRetries,
    @Default('') String permission,
  }) = _AgentStep;

  factory AgentStep.fromJson(Map<String, dynamic> json) =>
      _$AgentStepFromJson(json);
}

@freezed
class AgentResult with _$AgentResult {
  const factory AgentResult({
    required List<AgentStep> steps,
    required bool success,
  }) = _AgentResult;

  factory AgentResult.fromJson(Map<String, dynamic> json) =>
      _$AgentResultFromJson(json);
}

@freezed
class ToolAuditEntry with _$ToolAuditEntry {
  const factory ToolAuditEntry({
    required int timestamp,
    required String tool,
    required String args,
    required ToolRisk risk,
    required bool approved,
    required String result,
  }) = _ToolAuditEntry;

  factory ToolAuditEntry.fromJson(Map<String, dynamic> json) =>
      _$ToolAuditEntryFromJson(json);
}
