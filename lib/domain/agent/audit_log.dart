import 'package:aios/domain/entities/agent_models.dart';

class AuditLog {
  AuditLog({int maxSize = 100}) : _maxSize = maxSize;

  final int _maxSize;
  final List<ToolAuditEntry> _entries = [];

  void add(
    String tool,
    String args,
    ToolRisk risk, {
    required bool approved,
    required String result,
  }) {
    _entries.add(
      ToolAuditEntry(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        tool: tool,
        args: args,
        risk: risk,
        approved: approved,
        result: result,
      ),
    );
    while (_entries.length > _maxSize) {
      _entries.removeAt(0);
    }
  }

  List<ToolAuditEntry> getAll() => List.unmodifiable(_entries);

  void clear() => _entries.clear();
}
