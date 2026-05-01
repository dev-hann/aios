package com.agent.aios.settings

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "aios_settings")

class SettingsRepository(private val context: Context) {

    private val store = context.dataStore

    companion object {
        val KEY_CONTEXT_SIZE = intPreferencesKey("context_size")
        val KEY_MAX_TOKENS_CHAT = intPreferencesKey("max_tokens_chat")
        val KEY_MAX_TOKENS_AGENT = intPreferencesKey("max_tokens_agent")
        val KEY_TEMPERATURE = floatPreferencesKey("temperature")
        val KEY_TOP_K = intPreferencesKey("top_k")
        val KEY_TOP_P = floatPreferencesKey("top_p")
        val KEY_AGENT_MAX_ITERATIONS = intPreferencesKey("agent_max_iterations")
        val KEY_REPEAT_PENALTY = floatPreferencesKey("repeat_penalty")

        const val DEFAULT_CONTEXT_SIZE = 2048
        const val DEFAULT_MAX_TOKENS_CHAT = 128
        const val DEFAULT_MAX_TOKENS_AGENT = 256
        const val DEFAULT_TEMPERATURE = 0.7f
        const val DEFAULT_TOP_K = 40
        const val DEFAULT_TOP_P = 0.9f
        const val DEFAULT_AGENT_MAX_ITERATIONS = 5
        const val DEFAULT_REPEAT_PENALTY = 1.1f
    }

    val contextSize: Flow<Int> = store.data.map {
        it[KEY_CONTEXT_SIZE] ?: DEFAULT_CONTEXT_SIZE
    }

    val maxTokensChat: Flow<Int> = store.data.map {
        it[KEY_MAX_TOKENS_CHAT] ?: DEFAULT_MAX_TOKENS_CHAT
    }

    val maxTokensAgent: Flow<Int> = store.data.map {
        it[KEY_MAX_TOKENS_AGENT] ?: DEFAULT_MAX_TOKENS_AGENT
    }

    val temperature: Flow<Float> = store.data.map {
        it[KEY_TEMPERATURE] ?: DEFAULT_TEMPERATURE
    }

    val topK: Flow<Int> = store.data.map {
        it[KEY_TOP_K] ?: DEFAULT_TOP_K
    }

    val topP: Flow<Float> = store.data.map {
        it[KEY_TOP_P] ?: DEFAULT_TOP_P
    }

    val agentMaxIterations: Flow<Int> = store.data.map {
        it[KEY_AGENT_MAX_ITERATIONS] ?: DEFAULT_AGENT_MAX_ITERATIONS
    }

    val repeatPenalty: Flow<Float> = store.data.map {
        it[KEY_REPEAT_PENALTY] ?: DEFAULT_REPEAT_PENALTY
    }

    suspend fun setContextSize(value: Int) {
        store.edit { it[KEY_CONTEXT_SIZE] = value }
    }

    suspend fun setMaxTokensChat(value: Int) {
        store.edit { it[KEY_MAX_TOKENS_CHAT] = value }
    }

    suspend fun setMaxTokensAgent(value: Int) {
        store.edit { it[KEY_MAX_TOKENS_AGENT] = value }
    }

    suspend fun setTemperature(value: Float) {
        store.edit { it[KEY_TEMPERATURE] = value }
    }

    suspend fun setTopK(value: Int) {
        store.edit { it[KEY_TOP_K] = value }
    }

    suspend fun setTopP(value: Float) {
        store.edit { it[KEY_TOP_P] = value }
    }

    suspend fun setAgentMaxIterations(value: Int) {
        store.edit { it[KEY_AGENT_MAX_ITERATIONS] = value }
    }

    suspend fun setRepeatPenalty(value: Float) {
        store.edit { it[KEY_REPEAT_PENALTY] = value }
    }
}
