package com.agent.aios.settings

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton
import com.agent.aios.domain.repository.SettingsRepository as DomainSettingsRepository

val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "aios_settings")

@Singleton
class SettingsRepositoryImpl
    @Inject
    constructor(
        @ApplicationContext context: Context,
    ) : DomainSettingsRepository {
        private val store = context.dataStore

        private val KEY_CONTEXT_SIZE = intPreferencesKey("context_size")
        private val KEY_MAX_TOKENS_CHAT = intPreferencesKey("max_tokens_chat")
        private val KEY_MAX_TOKENS_AGENT = intPreferencesKey("max_tokens_agent")
        private val KEY_TEMPERATURE = floatPreferencesKey("temperature")
        private val KEY_TOP_K = intPreferencesKey("top_k")
        private val KEY_TOP_P = floatPreferencesKey("top_p")
        private val KEY_AGENT_MAX_ITERATIONS = intPreferencesKey("agent_max_iterations")
        private val KEY_REPEAT_PENALTY = floatPreferencesKey("repeat_penalty")
        private val KEY_LAST_MODEL_PATH = stringPreferencesKey("last_model_path")

        override val contextSize: Flow<Int> =
            store.data.map { it[KEY_CONTEXT_SIZE] ?: DomainSettingsRepository.DEFAULT_CONTEXT_SIZE }

        override val maxTokensChat: Flow<Int> =
            store.data.map { it[KEY_MAX_TOKENS_CHAT] ?: DomainSettingsRepository.DEFAULT_MAX_TOKENS_CHAT }

        override val maxTokensAgent: Flow<Int> =
            store.data.map { it[KEY_MAX_TOKENS_AGENT] ?: DomainSettingsRepository.DEFAULT_MAX_TOKENS_AGENT }

        override val temperature: Flow<Float> =
            store.data.map { it[KEY_TEMPERATURE] ?: DomainSettingsRepository.DEFAULT_TEMPERATURE }

        override val topK: Flow<Int> =
            store.data.map { it[KEY_TOP_K] ?: DomainSettingsRepository.DEFAULT_TOP_K }

        override val topP: Flow<Float> =
            store.data.map { it[KEY_TOP_P] ?: DomainSettingsRepository.DEFAULT_TOP_P }

        override val agentMaxIterations: Flow<Int> =
            store.data.map { it[KEY_AGENT_MAX_ITERATIONS] ?: DomainSettingsRepository.DEFAULT_AGENT_MAX_ITERATIONS }

        override val repeatPenalty: Flow<Float> =
            store.data.map { it[KEY_REPEAT_PENALTY] ?: DomainSettingsRepository.DEFAULT_REPEAT_PENALTY }

        override val lastModelPath: Flow<String> =
            store.data.map { prefs: androidx.datastore.preferences.core.Preferences ->
                prefs[KEY_LAST_MODEL_PATH] ?: ""
            }

        override suspend fun setContextSize(value: Int) {
            store.edit { it[KEY_CONTEXT_SIZE] = value }
        }

        override suspend fun setMaxTokensChat(value: Int) {
            store.edit { it[KEY_MAX_TOKENS_CHAT] = value }
        }

        override suspend fun setMaxTokensAgent(value: Int) {
            store.edit { it[KEY_MAX_TOKENS_AGENT] = value }
        }

        override suspend fun setTemperature(value: Float) {
            store.edit { it[KEY_TEMPERATURE] = value }
        }

        override suspend fun setTopK(value: Int) {
            store.edit { it[KEY_TOP_K] = value }
        }

        override suspend fun setTopP(value: Float) {
            store.edit { it[KEY_TOP_P] = value }
        }

        override suspend fun setAgentMaxIterations(value: Int) {
            store.edit { it[KEY_AGENT_MAX_ITERATIONS] = value }
        }

        override suspend fun setRepeatPenalty(value: Float) {
            store.edit { it[KEY_REPEAT_PENALTY] = value }
        }

        override suspend fun setLastModelPath(path: String) {
            store.edit { it[KEY_LAST_MODEL_PATH] = path }
        }

        override suspend fun clearLastModelPath() {
            store.edit { it.remove(KEY_LAST_MODEL_PATH) }
        }
    }
