package com.agent.aios.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.agent.aios.domain.repository.SettingsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val repo: SettingsRepository,
) : ViewModel() {
    val contextSize: StateFlow<Int> =
        repo.contextSize
            .stateIn(viewModelScope, SharingStarted.Eagerly, SettingsRepository.DEFAULT_CONTEXT_SIZE)

    val maxTokensChat: StateFlow<Int> =
        repo.maxTokensChat
            .stateIn(viewModelScope, SharingStarted.Eagerly, SettingsRepository.DEFAULT_MAX_TOKENS_CHAT)

    val maxTokensAgent: StateFlow<Int> =
        repo.maxTokensAgent
            .stateIn(viewModelScope, SharingStarted.Eagerly, SettingsRepository.DEFAULT_MAX_TOKENS_AGENT)

    val temperature: StateFlow<Float> =
        repo.temperature
            .stateIn(viewModelScope, SharingStarted.Eagerly, SettingsRepository.DEFAULT_TEMPERATURE)

    val topK: StateFlow<Int> =
        repo.topK
            .stateIn(viewModelScope, SharingStarted.Eagerly, SettingsRepository.DEFAULT_TOP_K)

    val topP: StateFlow<Float> =
        repo.topP
            .stateIn(viewModelScope, SharingStarted.Eagerly, SettingsRepository.DEFAULT_TOP_P)

    val agentMaxIterations: StateFlow<Int> =
        repo.agentMaxIterations
            .stateIn(viewModelScope, SharingStarted.Eagerly, SettingsRepository.DEFAULT_AGENT_MAX_ITERATIONS)

    val repeatPenalty: StateFlow<Float> =
        repo.repeatPenalty
            .stateIn(viewModelScope, SharingStarted.Eagerly, SettingsRepository.DEFAULT_REPEAT_PENALTY)

    fun updateContextSize(value: Int) {
        viewModelScope.launch { repo.setContextSize(value) }
    }

    fun updateMaxTokensChat(value: Int) {
        viewModelScope.launch { repo.setMaxTokensChat(value) }
    }

    fun updateMaxTokensAgent(value: Int) {
        viewModelScope.launch { repo.setMaxTokensAgent(value.coerceIn(128, 1024)) }
    }

    fun updateTemperature(value: Float) {
        viewModelScope.launch { repo.setTemperature(value) }
    }

    fun updateTopK(value: Int) {
        viewModelScope.launch { repo.setTopK(value) }
    }

    fun updateTopP(value: Float) {
        viewModelScope.launch { repo.setTopP(value) }
    }

    fun updateAgentMaxIterations(value: Int) {
        viewModelScope.launch { repo.setAgentMaxIterations(value.coerceIn(2, 20)) }
    }

    fun updateRepeatPenalty(value: Float) {
        viewModelScope.launch { repo.setRepeatPenalty(value) }
    }
}
