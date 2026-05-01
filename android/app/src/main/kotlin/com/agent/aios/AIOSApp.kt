package com.agent.aios

import android.app.Application
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import android.util.Log
import com.agent.aios.settings.SettingsRepository
import com.agent.aios.update.UpdateChecker
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

class AIOSApp : Application() {

    private val TAG = "AIOS-App"

    var llmService: LlmService? = null
        private set
    var isBound = false
        private set
    var currentAgentEngine: AgentEngine? = null
        private set

    lateinit var settingsRepository: SettingsRepository
        private set

    private val _tokenFlow = MutableSharedFlow<String>(extraBufferCapacity = 64)
    val tokenFlow: SharedFlow<String> = _tokenFlow.asSharedFlow()

    private val _agentStepFlow = MutableSharedFlow<AgentStep>(extraBufferCapacity = 64)
    val agentStepFlow: SharedFlow<AgentStep> = _agentStepFlow.asSharedFlow()

    private val _serviceState = MutableSharedFlow<ServiceState>(replay = 1)
    val serviceState: SharedFlow<ServiceState> = _serviceState.asSharedFlow()

    private val _updateAvailable = MutableStateFlow<Boolean?>(null)
    val updateAvailable: StateFlow<Boolean?> = _updateAvailable.asStateFlow()

    private val _latestVersion = MutableStateFlow("")
    val latestVersion: StateFlow<String> = _latestVersion.asStateFlow()

    enum class ServiceState {
        DISCONNECTED, CONNECTING, READY, MODEL_LOADED, GENERATING, AGENT_RUNNING
    }

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val binder = service as LlmService.LlmBinder
            llmService = binder.getService()
            isBound = true
            llmService!!.setTokenCallback { token ->
                _tokenFlow.tryEmit(token)
            }
            _serviceState.tryEmit(ServiceState.READY)
            Log.i(TAG, "Service connected")
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            llmService = null
            isBound = false
            _serviceState.tryEmit(ServiceState.DISCONNECTED)
            Log.i(TAG, "Service disconnected")
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        settingsRepository = SettingsRepository(this)
        bindLlmService()
        checkForUpdateBackground()
    }

    private fun checkForUpdateBackground() {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val checker = UpdateChecker(this@AIOSApp)
                val info = checker.checkForUpdate()
                if (info != null) {
                    _updateAvailable.value = info.isUpdateAvailable
                    _latestVersion.value = info.latestVersion
                }
            } catch (_: Exception) {}
        }
    }

    private fun bindLlmService() {
        _serviceState.tryEmit(ServiceState.CONNECTING)
        val intent = Intent(this, LlmService::class.java)
        startForegroundService(intent)
        bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
    }

    fun loadModel(path: String, contextSize: Int? = null, onResult: (Boolean) -> Unit) {
        val svc = llmService
        if (svc == null) {
            onResult(false)
            return
        }
        _serviceState.tryEmit(ServiceState.GENERATING)
        Thread {
            val ctxSize = runCatching {
                runBlocking { contextSize ?: settingsRepository.contextSize.first() }
            }.getOrNull() ?: 2048
            svc.updateNotification("Loading model...")
            val success = svc.loadModel(path, ctxSize)
            if (success) {
                _serviceState.tryEmit(ServiceState.MODEL_LOADED)
                svc.updateNotification("Model loaded - Ready")
            } else {
                _serviceState.tryEmit(ServiceState.READY)
            }
            onResult(success)
        }.start()
    }

    fun generateStream(prompt: String, maxTokens: Int? = null, onComplete: (Int) -> Unit) {
        val svc = llmService
        if (svc == null) {
            onComplete(-1)
            return
        }
        _serviceState.tryEmit(ServiceState.GENERATING)
        Thread {
            val tokens = runCatching {
                runBlocking { maxTokens ?: settingsRepository.maxTokensChat.first() }
            }.getOrNull() ?: 128
            svc.updateNotification("Generating...")
            val count = svc.generateStream(prompt, tokens)
            _serviceState.tryEmit(ServiceState.MODEL_LOADED)
            svc.updateNotification("Ready")
            onComplete(count)
        }.start()
    }

    fun runAgent(prompt: String, maxIterations: Int? = null, maxTokensAgent: Int = 512, onComplete: (List<AgentStep>) -> Unit) {
        val svc = llmService
        if (svc == null) {
            onComplete(emptyList())
            return
        }
        val engine = svc.getAgentEngine()
        if (engine == null) {
            onComplete(emptyList())
            return
        }
        currentAgentEngine = engine
        _serviceState.tryEmit(ServiceState.AGENT_RUNNING)
        Thread {
            val iters = runCatching {
                runBlocking { maxIterations ?: settingsRepository.agentMaxIterations.first() }
            }.getOrNull() ?: 5
            svc.updateNotification("Agent running...")
            engine.setStepCallback { step ->
                _agentStepFlow.tryEmit(step)
            }
            val steps = engine.run(prompt, iters)
            currentAgentEngine = null
            _serviceState.tryEmit(ServiceState.MODEL_LOADED)
            svc.updateNotification("Ready")
            onComplete(steps)
        }.start()
    }

    fun resolveConfirmation(approved: Boolean) {
        currentAgentEngine?.resolveConfirmation(approved)
    }

    fun releaseModel() {
        llmService?.releaseModel()
        llmService?.updateNotification("Ready")
        _serviceState.tryEmit(ServiceState.READY)
    }

    override fun onTerminate() {
        if (isBound) {
            try { unbindService(serviceConnection) } catch (_: Exception) {}
        }
        super.onTerminate()
    }

    companion object {
        lateinit var instance: AIOSApp
            private set
    }
}
