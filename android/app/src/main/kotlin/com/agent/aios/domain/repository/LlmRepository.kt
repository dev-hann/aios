package com.agent.aios.domain.repository

import com.agent.aios.domain.model.AgentStep
import com.agent.aios.domain.model.ServiceState
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow

interface LlmRepository {
    val serviceState: StateFlow<ServiceState>
    val tokenStream: Flow<String>
    val agentStepStream: Flow<AgentStep>
    val updateAvailable: StateFlow<Boolean?>
    val latestVersion: StateFlow<String>
    val updateError: StateFlow<String?>

    val loadProgress: StateFlow<Float>

    val loadStage: StateFlow<Int>

    fun bindService()

    suspend fun loadModel(path: String, contextSize: Int? = null): Boolean

    fun releaseModel()

    fun isModelLoaded(): Boolean

    fun getModelInfo(): String

    fun getContextUsage(): String

    fun resetContext()

    fun cancelInference()

    fun resolveConfirmation(approved: Boolean)
}
