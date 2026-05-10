class ToolPreferenceTracker {
  ToolPreferenceTracker({int topN = 3}) : _topN = topN;

  final int _topN;
  final Map<String, int> _usage = {};

  int get totalUsage => _usage.values.fold(0, (sum, count) => sum + count);

  int getCount(String toolName) => _usage[toolName] ?? 0;

  void recordToolUse(String toolName) {
    _usage[toolName] = (_usage[toolName] ?? 0) + 1;
  }

  List<String> getMostUsed([int? count]) {
    final sorted = _usage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final limit = count ?? sorted.length;
    return sorted.take(limit).map((e) => e.key).toList();
  }

  String toPromptContext() {
    final top = getMostUsed(_topN);
    if (top.isEmpty) return '';
    final buffer = StringBuffer()..writeln('FREQUENTLY USED TOOLS:');
    for (final tool in top) {
      buffer.writeln('- $tool (${_usage[tool]} uses)');
    }
    return buffer.toString();
  }

  void clear() {
    _usage.clear();
  }
}
