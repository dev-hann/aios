package com.agent.aios.domain.model

enum class ToolRisk { SAFE, LOW, HIGH, CRITICAL }

data class ToolAuditEntry(
    val timestamp: Long,
    val tool: String,
    val args: String,
    val risk: ToolRisk,
    val approved: Boolean,
    val result: String,
)

data class AgentStep(
    val type: String,
    val content: String,
    val toolName: String = "",
    val toolArgs: String = "",
    val toolResult: String = "",
    val riskLevel: String = "",
)

data class AgentResult(
    val steps: List<AgentStep>,
    val success: Boolean,
)
