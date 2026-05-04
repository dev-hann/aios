package com.agent.aios.ui.viewmodel

import android.net.Uri
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.agent.aios.data.llm.LlmRepositoryImpl
import com.agent.aios.domain.model.AgentStep
import com.agent.aios.domain.model.ConfirmationRequest
import com.agent.aios.domain.model.ConversationMessage
import com.agent.aios.domain.model.Message
import com.agent.aios.domain.model.ModelInfo
import com.agent.aios.domain.model.ServiceState
import com.agent.aios.domain.repository.ConversationRepository
import com.agent.aios.domain.repository.ModelRepository
import com.agent.aios.domain.repository.SettingsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import javax.inject.Inject

data class ChatUiState(
    val messages: List<Message> = emptyList(),
    val inputText: String = "",
    val models: List<ModelInfo> = emptyList(),
    val isModelLoaded: Boolean = false,
    val isGenerating: Boolean = false,
    val pendingConfirmation: ConfirmationRequest? = null,
    val isImporting: Boolean = false,
    val currentGeneratingText: String = "",
    val tokenCount: Int = 0,
    val elapsedMs: Long = 0L,
    val contextUsage: String = "",
    val serviceState: ServiceState = ServiceState.DISCONNECTED,
)

@HiltViewModel
class ChatViewModel
    @Inject
    constructor(
        private val llmRepository: LlmRepositoryImpl,
        private val modelRepository: ModelRepository,
        private val conversationRepository: ConversationRepository,
        private val settingsRepository: SettingsRepository,
    ) : ViewModel() {
        private val TAG = "AIOS-ChatVM"

        val updateAvailable: StateFlow<Boolean?> get() = llmRepository.updateAvailable
        val latestVersion: StateFlow<String> get() = llmRepository.latestVersion

        fun getModelInfo(): String = llmRepository.getModelInfo()

        fun releaseModel() = llmRepository.releaseModel()

        private val _uiState = MutableStateFlow(ChatUiState())
        val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()

        private var generateStartTime = 0L

        init {
            loadPersistedConversation()
            viewModelScope.launch {
                llmRepository.tokenStream.collect { token ->
                    _uiState.value =
                        _uiState.value.copy(
                            currentGeneratingText = _uiState.value.currentGeneratingText + token,
                        )
                }
            }
            viewModelScope.launch {
                llmRepository.agentStepStream.collect { step ->
                    handleAgentStep(step)
                }
            }
            viewModelScope.launch {
                llmRepository.serviceState.collect { state ->
                    _uiState.value = _uiState.value.copy(serviceState = state)
                }
            }
            refreshModels()
            tryAutoLoadModel()
        }

        private fun handleAgentStep(step: AgentStep) {
            if (step.type == "confirmation_required") {
                _uiState.value =
                    _uiState.value.copy(
                        pendingConfirmation =
                            ConfirmationRequest(
                                toolName = step.toolName,
                                args = step.toolArgs,
                                risk = step.riskLevel,
                            ),
                    )
            } else if (step.type == "thinking_start") {
                _uiState.value = _uiState.value.copy(currentGeneratingText = "")
            } else if (step.type == "thinking_end") {
                _uiState.value = _uiState.value.copy(currentGeneratingText = "")
            } else {
                val msg =
                    when (step.type) {
                        "thought" -> Message("agent_think", step.content)
                        "action" -> Message("agent_action", step.content, step.toolName, step.toolArgs)
                        "observation" -> Message("agent_obs", step.toolResult, step.toolName, toolResult = step.toolResult)
                        "answer" -> Message("agent_answer", step.content)
                        else -> Message("system", step.content)
                    }
                _uiState.value =
                    _uiState.value.copy(
                        messages = _uiState.value.messages + msg,
                    )
                if (step.type in listOf("action", "observation", "answer")) {
                    persistAllMessages()
                }
            }
        }

        private fun loadPersistedConversation() {
            val persisted = conversationRepository.load()
            if (persisted.isNotEmpty()) {
                val restored = persisted.map { msg -> Message(role = msg.role, text = msg.content) }
                _uiState.value = _uiState.value.copy(messages = restored)
                Log.i(TAG, "Restored ${restored.size} messages from disk")
            }
        }

        private fun persistMessage(role: String, content: String) {
            viewModelScope.launch {
                conversationRepository.appendMessage(role, content)
            }
        }

        private fun persistAllMessages() {
            viewModelScope.launch {
                val msgs =
                    _uiState.value.messages.map { msg ->
                        ConversationMessage(role = msg.role, content = msg.text)
                    }
                conversationRepository.save(msgs)
            }
        }

        private fun updateContextUsage() {
            _uiState.value = _uiState.value.copy(contextUsage = llmRepository.getContextUsage())
        }

        fun updateInput(text: String) {
            _uiState.value = _uiState.value.copy(inputText = text)
        }

        fun refreshModels() {
            _uiState.value = _uiState.value.copy(models = modelRepository.scanModels())
        }

        fun restoreModel(name: String, onResult: (Boolean) -> Unit) {
            viewModelScope.launch {
                val success = withContext(Dispatchers.IO) { modelRepository.restoreModel(name) }
                if (success) refreshModels()
                onResult(success)
            }
        }

        private fun tryAutoLoadModel() {
            if (llmRepository.isModelLoaded()) {
                _uiState.value = _uiState.value.copy(isModelLoaded = true)
                return
            }
            viewModelScope.launch {
                try {
                    val savedPath = settingsRepository.lastModelPath.first()
                    if (savedPath.isBlank()) return@launch
                    val file = File(savedPath)
                    if (!file.exists()) {
                        settingsRepository.clearLastModelPath()
                        return@launch
                    }
                    Log.i(TAG, "Auto-loading model: $savedPath")
                    loadModel(savedPath)
                } catch (_: Exception) {
                }
            }
        }

        fun loadModel(path: String) {
            _uiState.value = _uiState.value.copy(isGenerating = true)
            viewModelScope.launch {
                val contextSize = runCatching { settingsRepository.contextSize.first() }.getOrNull() ?: 2048
                val success = llmRepository.loadModel(path, contextSize)
                _uiState.value =
                    _uiState.value.copy(
                        isModelLoaded = success,
                        isGenerating = false,
                    )
                if (success) {
                    viewModelScope.launch { settingsRepository.setLastModelPath(path) }
                } else {
                    _uiState.value =
                        _uiState.value.copy(
                            messages = _uiState.value.messages + Message("system", "Failed to load model. Check if the file is a valid GGUF."),
                        )
                }
            }
        }

        fun sendMessage() {
            val text = _uiState.value.inputText.trim()
            if (text.isEmpty() || _uiState.value.isGenerating) return
            _uiState.value =
                _uiState.value.copy(
                    inputText = "",
                    messages = _uiState.value.messages + Message("user", text),
                    isGenerating = true,
                    currentGeneratingText = "",
                    tokenCount = 0,
                )
            generateStartTime = System.currentTimeMillis()
            persistMessage("user", text)

            llmRepository.runAgent(text) { steps ->
                _uiState.value = _uiState.value.copy(isGenerating = false)
                _uiState.value =
                    _uiState.value.copy(
                        elapsedMs = System.currentTimeMillis() - generateStartTime,
                    )
                updateContextUsage()
                persistAllMessages()
            }
        }

        fun clearConversation() {
            _uiState.value = _uiState.value.copy(messages = emptyList(), contextUsage = "")
            conversationRepository.clear()
            llmRepository.resetContext()
        }

        fun approveTool() {
            val req = _uiState.value.pendingConfirmation ?: return
            _uiState.value =
                _uiState.value.copy(
                    pendingConfirmation = null,
                    messages = _uiState.value.messages + Message("system", "Allowed: ${req.toolName}"),
                )
            llmRepository.resolveConfirmation(true)
        }

        fun denyTool() {
            val req = _uiState.value.pendingConfirmation ?: return
            _uiState.value =
                _uiState.value.copy(
                    pendingConfirmation = null,
                    messages = _uiState.value.messages + Message("system", "Denied: ${req.toolName}"),
                )
            llmRepository.resolveConfirmation(false)
        }

        fun cancelGeneration() {
            llmRepository.cancelInference()
            _uiState.value =
                _uiState.value.copy(
                    isGenerating = false,
                    currentGeneratingText = "",
                    pendingConfirmation = null,
                )
        }

        fun getTokensPerSecond(): Float {
            val tokens = _uiState.value.tokenCount
            val elapsed = _uiState.value.elapsedMs
            if (elapsed <= 0) return 0f
            return (tokens.toFloat() / elapsed) * 1000f
        }

        fun importModelFromUri(uri: Uri, fileName: String) {
            if (_uiState.value.isImporting) return
            _uiState.value = _uiState.value.copy(isImporting = true)
            viewModelScope.launch {
                try {
                    withContext(Dispatchers.IO) {
                        modelRepository.importModelFromUri(uri, fileName)
                    }
                    refreshModels()
                } catch (e: Exception) {
                    Log.e(TAG, "Model import failed: ${e.message}")
                } finally {
                    _uiState.value = _uiState.value.copy(isImporting = false)
                }
            }
        }

        override fun onCleared() {
            super.onCleared()
            persistAllMessages()
        }
    }
