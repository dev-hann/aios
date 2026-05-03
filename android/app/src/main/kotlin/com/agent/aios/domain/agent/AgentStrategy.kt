package com.agent.aios.domain.agent

import com.agent.aios.domain.model.AgentResult
import com.agent.aios.domain.model.AgentStep

interface AgentStrategy {
    suspend fun execute(
        prompt: String,
        maxIterations: Int = 8,
        maxTokens: Int = 512,
        onStep: (AgentStep) -> Unit,
    ): AgentResult

    fun cancel()

    fun resolveConfirmation(approved: Boolean)

    fun initSystemPrompt()

    fun getToolManifest(): String

    fun getConversationHistory(): List<Pair<String, String>>

    fun clearHistory()
}
