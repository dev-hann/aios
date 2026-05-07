abstract class AgentTool {
  String get name;
  String get description;
  String get parameters;

  Future<String> execute(String args);

  Future<String?> validate(String args) async => null;
}
