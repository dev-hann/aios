package com.agent.aios

import android.app.Application
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import android.util.Log
import com.agent.aios.crash.CrashLogManager
import com.agent.aios.settings.SettingsRepository
import com.agent.aios.update.UpdateChecker
import com.agent.aios.update.UpdateResult
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

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

    var chatViewModel: com.agent.aios.ui.viewmodel.ChatViewModel? = null
        internal set

    private val _tokenFlow = MutableSharedFlow<String>(extraBufferCapacity = 64)
    val tokenFlow: SharedFlow<String> = _tokenFlow.asSharedFlow()

    private val _agentStepFlow = MutableSharedFlow<AgentStep>(extraBufferCapacity = 64)
    val agentStepFlow: SharedFlow<AgentStep> = _agentStepFlow.asSharedFlow()

    private val _serviceState = MutableSharedFlow<ServiceState>(replay = 1)
    val serviceState: SharedFlow<ServiceState> = _serviceState.asSharedFlow()

    private val appScope = CoroutineScope(Dispatchers.Main)
    private var inferenceJob: Job? = null

    private val _updateAvailable = MutableStateFlow<Boolean?>(null)
    val updateAvailable: StateFlow<Boolean?> = _updateAvailable.asStateFlow()

    private val _latestVersion = MutableStateFlow("")
    val latestVersion: StateFlow<String> = _latestVersion.asStateFlow()

    private val _updateError = MutableStateFlow<String?>(null)
    val updateError: StateFlow<String?> = _updateError.asStateFlow()

    enum class ServiceState {
        DISCONNECTED, CONNECTING, READY, MODEL_LOADED, GENERATING, AGENT_RUNNING
    }

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            if (service == null) {
                Log.e(TAG, "onServiceConnected: null binder")
                return
            }
            val binder = service as LlmService.LlmBinder
            llmService = binder.getService()
            isBound = true
            retryCount = 0
            llmService?.setTokenCallback { token ->
                _tokenFlow.tryEmit(token)
            }
            _serviceState.tryEmit(ServiceState.READY)
            Log.i(TAG, "Service connected")
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            llmService = null
            isBound = false
            _serviceState.tryEmit(ServiceState.DISCONNECTED)
            Log.i(TAG, "Service disconnected - scheduling reconnect")
            scheduleRebind()
        }
    }

    private var retryCount = 0
    private val maxRetries = 3
    private val retryDelaysMs = listOf(1000L, 3000L, 5000L)

    private fun scheduleRebind() {
        if (retryCount >= maxRetries) {
            Log.e(TAG, "Max rebind retries reached. Manual restart required.")
            return
        }
        val delay = retryDelaysMs.getOrElse(retryCount) { 5000L }
        retryCount++
        Log.i(TAG, "Scheduling rebind attempt $retryCount/$maxRetries in ${delay}ms")
        appScope.launch {
            kotlinx.coroutines.delay(delay)
            if (!isBound) {
                Log.i(TAG, "Attempting rebind...")
                bindLlmService()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        CrashLogManager.init(this)
        settingsRepository = SettingsRepository(this)
        checkForUpdateBackground()
    }

    fun bindLlmService() {
        try {
            _serviceState.tryEmit(ServiceState.CONNECTING)
            val intent = Intent(this, LlmService::class.java)
            startForegroundService(intent)
            bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start/bind LlmService", e)
            _serviceState.tryEmit(ServiceState.DISCONNECTED)
        }
    }

    private fun checkForUpdateBackground() {
        appScope.launch {
            try {
                val checker = UpdateChecker(this@AIOSApp)
                when (val result = withContext(Dispatchers.IO) { checker.checkForUpdate() }) {
                    is UpdateResult.Success -> {
                        _updateAvailable.value = result.info.isUpdateAvailable
                        _latestVersion.value = result.info.latestVersion
                        _updateError.value = null
                    }
                    is UpdateResult.NotAvailable -> {
                        _updateAvailable.value = false
                        _updateError.value = null
                    }
                    is UpdateResult.Error -> {
                        _updateError.value = result.message
                    }
                }
            } catch (_: Exception) {}
        }
    }

    fun loadModel(path: String, contextSize: Int? = null, onResult: (Boolean) -> Unit) {
        val svc = llmService
        if (svc == null) {
            onResult(false)
            return
        }
        _serviceState.tryEmit(ServiceState.GENERATING)
        inferenceJob = appScope.launch {
            val ctxSize = contextSize ?: settingsRepository.contextSize.first()
            withContext(Dispatchers.IO) {
                svc.updateNotification("Loading model...")
                val success = svc.loadModel(path, ctxSize)
                if (success) {
                    _serviceState.tryEmit(ServiceState.MODEL_LOADED)
                    svc.updateNotification("Model loaded - Ready")
                } else {
                    _serviceState.tryEmit(ServiceState.READY)
                }
                onResult(success)
            }
        }
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
        inferenceJob = appScope.launch {
            val iters = maxIterations ?: settingsRepository.agentMaxIterations.first()
            withContext(Dispatchers.IO) {
                svc.updateNotification("Agent running...")
                engine.setStepCallback { step ->
                    _agentStepFlow.tryEmit(step)
                }
                val steps = engine.run(prompt, iters)
                currentAgentEngine = null
                _serviceState.tryEmit(ServiceState.MODEL_LOADED)
                svc.updateNotification("Ready")
                onComplete(steps)
            }
        }
    }

    fun resolveConfirmation(approved: Boolean) {
        currentAgentEngine?.resolveConfirmation(approved)
    }

    fun cancelInference() {
        currentAgentEngine?.cancel()
        inferenceJob?.cancel()
        currentAgentEngine = null
        _serviceState.tryEmit(ServiceState.MODEL_LOADED)
        llmService?.updateNotification("Ready")
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
