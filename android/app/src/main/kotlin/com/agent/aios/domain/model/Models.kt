package com.agent.aios.domain.model

data class Message(
    val role: String,
    val text: String,
    val toolName: String = "",
    val toolArgs: String = "",
    val toolResult: String = "",
)

data class ModelInfo(
    val name: String,
    val size: Long,
    val path: String,
)

data class ConfirmationRequest(
    val toolName: String,
    val args: String,
    val risk: String,
    val createdAtMs: Long = System.currentTimeMillis(),
    val timeoutMs: Long = 60000L,
)

data class ConversationMessage(
    val role: String,
    val content: String,
)
