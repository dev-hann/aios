package com.agent.aios.ui.viewmodel

import android.os.Environment
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.agent.aios.AIOSApp
import com.agent.aios.AgentStep
import com.agent.aios.ui.theme.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
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

enum class AgentMode { CHAT, AGENT }

class ChatViewModel : ViewModel() {

    private val app: AIOSApp
        get() = AIOSApp.instance

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

    private val _currentGeneratingText = MutableStateFlow("")
    val currentGeneratingText: StateFlow<String> = _currentGeneratingText.asStateFlow()

    private val _tokenCount = MutableStateFlow(0)
    val tokenCount: StateFlow<Int> = _tokenCount.asStateFlow()

    private val _elapsedMs = MutableStateFlow(0L)
    val elapsedMs: StateFlow<Long> = _elapsedMs.asStateFlow()

    val serviceState = app.serviceState
        .stateIn(viewModelScope, SharingStarted.Eagerly, AIOSApp.ServiceState.DISCONNECTED)

    private var generateStartTime = 0L

    init {
        viewModelScope.launch {
            app.tokenFlow.collect { token ->
                _currentGeneratingText.value += token
            }
        }
        viewModelScope.launch {
            app.agentStepFlow.collect { step ->
                val msg = when (step.type) {
                    "thought" -> Message("agent_think", step.content)
                    "action" -> Message("agent_action", step.content, step.toolName, step.toolArgs)
                    "observation" -> Message("agent_obs", step.toolResult, step.toolName, toolResult = step.toolResult)
                    "answer" -> Message("agent_answer", step.content)
                    else -> Message("system", step.content)
                }
                _messages.value = _messages.value + msg
            }
        }
        refreshModels()
        checkModelLoaded()
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
        app.loadModel(path, contextSize) { success ->
            _isModelLoaded.value = success
            if (!success) {
                _messages.value = _messages.value + Message("system", "Failed to load model")
            }
        }
    }

    fun sendMessage() {
        val text = _inputText.value.trim()
        if (text.isEmpty() || _isGenerating.value) return
        _inputText.value = ""
        _messages.value = _messages.value + Message("user", text)
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
                }
            }
            AgentMode.AGENT -> {
                app.runAgent(text) { steps ->
                    _isGenerating.value = false
                    Log.i("ChatVM", "Agent completed with ${steps.size} steps")
                }
            }
        }
    }

    fun getTokensPerSecond(): Float {
        val tokens = _tokenCount.value
        val elapsed = _elapsedMs.value
        if (elapsed <= 0) return 0f
        return (tokens.toFloat() / elapsed) * 1000f
    }
}
