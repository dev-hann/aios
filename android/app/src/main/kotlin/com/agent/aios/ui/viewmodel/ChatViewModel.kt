package com.agent.aios.ui.viewmodel

import android.app.ActivityManager
import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.agent.aios.domain.model.AgentStep
import com.agent.aios.domain.model.ConfirmationRequest
import com.agent.aios.domain.model.ConversationMessage
import com.agent.aios.domain.model.Message
import com.agent.aios.domain.model.ModelInfo
import com.agent.aios.domain.model.ServiceState
import com.agent.aios.domain.repository.ConversationRepository
import com.agent.aios.domain.repository.LlmRepository
import com.agent.aios.domain.repository.ModelRepository
import com.agent.aios.domain.repository.SettingsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
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
    val loadProgress: Float = 0f,
    val loadStage: Int = 0,
    val modelSizeWarning: String? = null,
)

@HiltViewModel
class ChatViewModel
    @Inject
    constructor(
        @ApplicationContext private val appContext: Context,
        private val llmRepository: LlmRepository,
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
            viewModelScope.launch {
                llmRepository.loadProgress.collect { progress ->
                    _uiState.value = _uiState.value.copy(loadProgress = progress)
                }
            }
            viewModelScope.launch {
                llmRepository.loadStage.collect { stage ->
                    _uiState.value = _uiState.value.copy(loadStage = stage)
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

        fun loadModel(path: String, modelSize: Long = 0L) {
            _uiState.value = _uiState.value.copy(modelSizeWarning = null)

            if (modelSize > 0) {
                val actManager = appContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val memInfo = ActivityManager.MemoryInfo()
                actManager.getMemoryInfo(memInfo)
                val availMb = memInfo.availMem / (1024 * 1024)
                val modelSizeMb = modelSize / (1024 * 1024)
                val totalMb = memInfo.totalMem / (1024 * 1024)

                // ~1.3x model file size needed for mmap + KV context + runtime overhead
                val estimatedNeedMb = (modelSizeMb * 1.3).toInt()
                if (modelSizeMb > totalMb * 0.6) {
                    _uiState.value =
                        _uiState.value.copy(
                            modelSizeWarning = "Model (${modelSizeMb}MB) may be too large for this device (${totalMb}MB total RAM). App may freeze during loading.",
                        )
                } else if (estimatedNeedMb > availMb) {
                    _uiState.value =
                        _uiState.value.copy(
                            modelSizeWarning = "Low memory: ${availMb}MB available, model needs ~${estimatedNeedMb}MB. App may freeze during loading.",
                        )
                }
            }

            _uiState.value = _uiState.value.copy(isGenerating = true)
            viewModelScope.launch {
                val savedContextSize = runCatching { settingsRepository.contextSize.first() }.getOrNull() ?: 2048
                val contextSize =
                    if (modelSize > 2_000_000_000L) {
                        val reduced = minOf(savedContextSize, 1024)
                        if (reduced < savedContextSize) {
                            Log.w(TAG, "Large model (${modelSize / 1_000_000}MB): reducing context $savedContextSize → $reduced")
                        }
                        reduced
                    } else if (modelSize > 1_500_000_000L) {
                        minOf(savedContextSize, 1536)
                    } else {
                        savedContextSize
                    }
                val success = llmRepository.loadModel(path, contextSize)
                _uiState.value =
                    _uiState.value.copy(
                        isModelLoaded = success,
                        isGenerating = false,
                        modelSizeWarning = null,
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
