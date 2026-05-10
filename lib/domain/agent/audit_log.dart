import 'dart:collection';

import 'package:aios/domain/entities/agent_models.dart';

class AuditLog {
  AuditLog({int maxSize = 100}) : _maxSize = maxSize;

  final int _maxSize;
  final Queue<ToolAuditEntry> _entries = Queue();

  void add(
    String tool,
    String args,
    ToolRisk risk, {
    required bool approved,
    required String result,
  }) {
    _entries.addLast(
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
      _entries.removeFirst();
    }
  }

  List<ToolAuditEntry> getAll() => List.unmodifiable(_entries);

  void clear() => _entries.clear();
}
