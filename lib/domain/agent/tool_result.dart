class ToolResult {
  final String? output;
  final String? error;
  final String? system;
  final String? observation;

  const ToolResult({this.output, this.error, this.system, this.observation});

  const ToolResult.ok(this.output, {this.system, this.observation})
    : error = null;

  const ToolResult.err(this.error, {this.system})
    : output = null,
      observation = null;

  bool get isError => error != null;

  String toContent() {
    final parts = <String>[];
    if (system != null) parts.add('<system>$system</system>');
    if (error != null) {
      parts.add('Error: $error');
    } else if (output != null) {
      parts.add(output!);
    }
    if (observation != null) parts.add('Screen: $observation');
    return parts.join('\n');
  }

  @override
  String toString() => toContent();
}
