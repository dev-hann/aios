package com.agent.aios.ui.viewmodel

import android.os.Environment
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.agent.aios.AIOSApp
import com.agent.aios.AgentStep
import com.agent.aios.data.ConversationMessage
import com.agent.aios.data.ConversationStore
import com.agent.aios.ui.theme.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import android.net.Uri
import java.io.File

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

enum class AgentMode { CHAT, AGENT }

class ChatViewModel : ViewModel() {

    private val app: AIOSApp
        get() = AIOSApp.instance

    private val conversationStore by lazy { ConversationStore(app) }

    private val _messages = MutableStateFlow<List<Message>>(emptyList())
    val messages: StateFlow<List<Message>> = _messages.asStateFlow()

    private val _inputText = MutableStateFlow("")
    val inputText: StateFlow<String> = _inputText.asStateFlow()

    private val _models = MutableStateFlow<List<ModelInfo>>(emptyList())
    val models: StateFlow<List<ModelInfo>> = _models.asStateFlow()

    private val _isModelLoaded = MutableStateFlow(false)
    val isModelLoaded: StateFlow<Boolean> = _isModelLoaded.asStateFlow()

    private val _isGenerating = MutableStateFlow(false)
    val isGenerating: StateFlow<Boolean> = _isGenerating.asStateFlow()

    private val _agentMode = MutableStateFlow(AgentMode.CHAT)
    val agentMode: StateFlow<AgentMode> = _agentMode.asStateFlow()

    private val _pendingConfirmation = MutableStateFlow<ConfirmationRequest?>(null)
    val pendingConfirmation: StateFlow<ConfirmationRequest?> = _pendingConfirmation.asStateFlow()

    private val _isImporting = MutableStateFlow(false)
    val isImporting: StateFlow<Boolean> = _isImporting.asStateFlow()

    private val _currentGeneratingText = MutableStateFlow("")
    val currentGeneratingText: StateFlow<String> = _currentGeneratingText.asStateFlow()

    private val _tokenCount = MutableStateFlow(0)
    val tokenCount: StateFlow<Int> = _tokenCount.asStateFlow()

    private val _elapsedMs = MutableStateFlow(0L)
    val elapsedMs: StateFlow<Long> = _elapsedMs.asStateFlow()

    private val _contextUsage = MutableStateFlow("")
    val contextUsage: StateFlow<String> = _contextUsage.asStateFlow()

    val serviceState = app.serviceState
        .stateIn(viewModelScope, SharingStarted.Eagerly, AIOSApp.ServiceState.DISCONNECTED)

    private var generateStartTime = 0L

    init {
        loadPersistedConversation()
        viewModelScope.launch {
            app.tokenFlow.collect { token ->
                _currentGeneratingText.value += token
            }
        }
        viewModelScope.launch {
            app.agentStepFlow.collect { step ->
                if (step.type == "confirmation_required") {
                    _pendingConfirmation.value = ConfirmationRequest(
                        toolName = step.toolName,
                        args = step.toolArgs,
                        risk = step.riskLevel,
                    )
                } else if (step.type == "thinking_start") {
                    _currentGeneratingText.value = ""
                } else if (step.type == "thinking_end") {
                    _currentGeneratingText.value = ""
                } else {
                    val msg = when (step.type) {
                        "thought" -> Message("agent_think", step.content)
                        "action" -> Message("agent_action", step.content, step.toolName, step.toolArgs)
                        "observation" -> Message("agent_obs", step.toolResult, step.toolName, toolResult = step.toolResult)
                        "answer" -> Message("agent_answer", step.content)
                        else -> Message("system", step.content)
                    }
                    _messages.value = _messages.value + msg
                    if (step.type in listOf("action", "observation", "answer")) {
                        persistAllMessages()
                    }
                }
            }
        }
        refreshModels()
        checkModelLoaded()
    }

    private fun loadPersistedConversation() {
        val persisted = conversationStore.load()
        if (persisted.isNotEmpty()) {
            val restored = persisted.map { msg ->
                Message(role = msg.role, text = msg.content)
            }
            _messages.value = restored
            Log.i("ChatVM", "Restored ${restored.size} messages from disk")
        }
    }

    private fun persistMessage(role: String, content: String) {
        viewModelScope.launch {
            conversationStore.appendMessage(role, content)
        }
    }

    private fun persistAllMessages() {
        viewModelScope.launch {
            val msgs = _messages.value.map { msg ->
                ConversationMessage(role = msg.role, content = msg.text)
            }
            conversationStore.save(msgs)
        }
    }

    private fun updateContextUsage() {
        val svc = app.llmService ?: return
        _contextUsage.value = svc.getContextUsage()
    }

    fun updateInput(text: String) {
        _inputText.value = text
    }

    fun toggleMode() {
        _agentMode.value = if (_agentMode.value == AgentMode.CHAT) AgentMode.AGENT else AgentMode.CHAT
    }

    fun refreshModels() {
        val found = mutableListOf<ModelInfo>()

        val dir = File(app.filesDir, "models")
        if (!dir.exists()) dir.mkdirs()
        dir.listFiles()
            ?.filter { it.extension == "gguf" }
            ?.mapTo(found) { ModelInfo(it.name, it.length(), it.absolutePath) }

        val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (downloadDir.exists()) {
            downloadDir.listFiles()
                ?.filter { it.name.endsWith(".gguf") }
                ?.mapTo(found) { ModelInfo(it.name, it.length(), it.absolutePath) }
        }

        _models.value = found
    }

    fun restoreModel(name: String, onResult: (Boolean) -> Unit) {
        val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val src = File(downloadDir, name)
        val dst = File(File(app.filesDir, "models"), name)

        if (!src.exists()) {
            onResult(false)
            return
        }
        if (dst.exists()) {
            onResult(true)
            return
        }

        Thread {
            try {
                dst.parentFile?.mkdirs()
                src.inputStream().use { input ->
                    dst.outputStream().use { output ->
                        input.copyTo(output, 8192)
                    }
                }
                Log.i("ChatVM", "Model restored: ${dst.length()} bytes")
                refreshModels()
                onResult(true)
            } catch (e: Exception) {
                Log.e("ChatVM", "Restore failed: ${e.message}")
                onResult(false)
            }
        }.start()
    }

    private fun checkModelLoaded() {
        _isModelLoaded.value = app.llmService?.isModelLoaded() ?: false
    }

    fun loadModel(path: String) {
        val contextSize = runCatching {
            runBlocking { app.settingsRepository.contextSize.first() }
        }.getOrNull() ?: 2048
        _isGenerating.value = true
        app.loadModel(path, contextSize) { success ->
            viewModelScope.launch {
                _isModelLoaded.value = success
                _isGenerating.value = false
                if (!success) {
                    _messages.value = _messages.value + Message("system", "Failed to load model. Check if the file is a valid GGUF.")
                }
            }
        }
    }

    fun sendMessage() {
        val text = _inputText.value.trim()
        if (text.isEmpty() || _isGenerating.value) return
        _inputText.value = ""
        _messages.value = _messages.value + Message("user", text)
        persistMessage("user", text)
        _isGenerating.value = true
        _currentGeneratingText.value = ""
        _tokenCount.value = 0
        generateStartTime = System.currentTimeMillis()

        when (_agentMode.value) {
            AgentMode.CHAT -> {
                _messages.value = _messages.value + Message("assistant", "")
                val idx = _messages.value.lastIndex
                app.generateStream(text) { count ->
                    _tokenCount.value = count
                    _elapsedMs.value = System.currentTimeMillis() - generateStartTime
                    _isGenerating.value = false
                    val finalText = _currentGeneratingText.value
                    _messages.value = _messages.value.toMutableList().apply {
                        this[idx] = Message("assistant", finalText)
                    }
                    _currentGeneratingText.value = ""
                    persistMessage("assistant", finalText)
                    updateContextUsage()
                }
            }
            AgentMode.AGENT -> {
                app.runAgent(text) { steps ->
                    _isGenerating.value = false
                    Log.i("ChatVM", "Agent completed with ${steps.size} steps")
                    updateContextUsage()
                    persistAllMessages()
                }
            }
        }
    }

    fun clearConversation() {
        _messages.value = emptyList()
        conversationStore.clear()
        app.llmService?.resetContext()
        _contextUsage.value = ""
    }

    fun approveTool() {
        val req = _pendingConfirmation.value ?: return
        _pendingConfirmation.value = null
        _messages.value = _messages.value + Message("system", "Allowed: ${req.toolName}")
        app.resolveConfirmation(true)
    }

    fun denyTool() {
        val req = _pendingConfirmation.value ?: return
        _pendingConfirmation.value = null
        _messages.value = _messages.value + Message("system", "Denied: ${req.toolName}")
        app.resolveConfirmation(false)
    }

    fun getTokensPerSecond(): Float {
        val tokens = _tokenCount.value
        val elapsed = _elapsedMs.value
        if (elapsed <= 0) return 0f
        return (tokens.toFloat() / elapsed) * 1000f
    }

    fun importModelFromUri(uri: Uri, fileName: String) {
        if (_isImporting.value) return
        _isImporting.value = true
        viewModelScope.launch {
            try {
                val modelsDir = File(app.filesDir, "models")
                if (!modelsDir.exists()) modelsDir.mkdirs()
                val safeName = if (fileName.endsWith(".gguf")) fileName else "$fileName.gguf"
                val dst = File(modelsDir, safeName)
                withContext(Dispatchers.IO) {
                    app.contentResolver.openInputStream(uri)?.use { input ->
                        dst.outputStream().use { output ->
                            input.copyTo(output, 8192)
                        }
                    }
                }
                Log.i("ChatVM", "Model imported: ${dst.length()} bytes -> ${dst.absolutePath}")
                refreshModels()
            } catch (e: Exception) {
                Log.e("ChatVM", "Model import failed: ${e.message}")
            } finally {
                _isImporting.value = false
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        persistAllMessages()
    }
}
