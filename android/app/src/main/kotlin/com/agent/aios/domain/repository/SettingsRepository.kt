package com.agent.aios.domain.repository

import kotlinx.coroutines.flow.Flow

interface SettingsRepository {
    val contextSize: Flow<Int>
    val maxTokensChat: Flow<Int>
    val maxTokensAgent: Flow<Int>
    val temperature: Flow<Float>
    val topK: Flow<Int>
    val topP: Flow<Float>
    val agentMaxIterations: Flow<Int>
    val repeatPenalty: Flow<Float>
    val lastModelPath: Flow<String>

    suspend fun setContextSize(value: Int)

    suspend fun setMaxTokensChat(value: Int)

    suspend fun setMaxTokensAgent(value: Int)

    suspend fun setTemperature(value: Float)

    suspend fun setTopK(value: Int)

    suspend fun setTopP(value: Float)

    suspend fun setAgentMaxIterations(value: Int)

    suspend fun setRepeatPenalty(value: Float)

    suspend fun setLastModelPath(path: String)

    suspend fun clearLastModelPath()

    companion object {
        const val DEFAULT_CONTEXT_SIZE = 2048
        const val DEFAULT_MAX_TOKENS_CHAT = 128
        const val DEFAULT_MAX_TOKENS_AGENT = 512
        const val DEFAULT_TEMPERATURE = 0.7f
        const val DEFAULT_TOP_K = 40
        const val DEFAULT_TOP_P = 0.9f
        const val DEFAULT_AGENT_MAX_ITERATIONS = 8
        const val DEFAULT_REPEAT_PENALTY = 1.1f
    }
}
