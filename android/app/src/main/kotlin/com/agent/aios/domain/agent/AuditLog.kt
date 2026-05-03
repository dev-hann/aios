package com.agent.aios.domain.agent

import com.agent.aios.domain.model.ToolAuditEntry

class AuditLog(private val maxSize: Int = 100) {
    private val entries = mutableListOf<ToolAuditEntry>()

    fun add(
        tool: String,
        args: String,
        risk: com.agent.aios.domain.model.ToolRisk,
        approved: Boolean,
        result: String,
    ) {
        synchronized(entries) {
            entries.add(ToolAuditEntry(System.currentTimeMillis(), tool, args, risk, approved, result))
            while (entries.size > maxSize) {
                entries.removeAt(0)
            }
        }
    }

    fun getAll(): List<ToolAuditEntry> = synchronized(entries) { entries.toList() }

    fun clear() = synchronized(entries) { entries.clear() }
}
