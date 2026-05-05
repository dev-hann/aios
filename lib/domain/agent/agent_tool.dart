import 'package:aios/domain/agent/tool_context.dart';

abstract class AgentTool {
  String get name;
  String get description;
  String get parameters;

  String execute(String args);
}

abstract class ExtendedTool {
  String get name;
  String get description;
  String get parameters;

  Future<String> execute(String args, ToolContext toolContext);
}
