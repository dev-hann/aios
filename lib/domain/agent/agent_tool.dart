abstract class AgentTool {
  String get name;
  String get description;
  String get parameters;

  String execute(String args);
}
