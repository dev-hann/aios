import 'package:aios/domain/agent/tool_result.dart';

abstract class AgentTool {
  String get name;
  String get description;
  String get parameters;

  String get toolPrompt => '$description\nParameters: $parameters';

  Future<ToolResult> execute(String args);

  Future<String?> validate(String args) async => null;
}
