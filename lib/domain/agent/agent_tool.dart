abstract class AgentTool {
  String get name;
  String get description;
  String get parameters;

  String get toolPrompt =>
      '$description\nParameters: $parameters';

  String? get grammar => null;

  Future<String> execute(String args);

  Future<String?> validate(String args) async => null;

  Future<String?> phaseContext(String args) async => null;
}
