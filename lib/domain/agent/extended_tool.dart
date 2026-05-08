import 'package:aios/domain/agent/tool_context.dart';

abstract class ExtendedTool {
  String get name;
  String get description;
  String get parameters;

  String get toolPrompt =>
      '$description\nParameters: $parameters';

  String? get grammar => null;

  Future<String> execute(String args, ToolContext toolContext);

  Future<String?> validate(String args, ToolContext toolContext) async =>
      null;

  Future<String?> phaseContext(
    String args,
    ToolContext toolContext,
  ) async =>
      null;
}
