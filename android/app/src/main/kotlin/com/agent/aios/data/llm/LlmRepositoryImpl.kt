package com.agent.aios.data.llm

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import android.util.Log
import com.agent.aios.LlmService
import com.agent.aios.data.tool.ToolContextImpl
import com.agent.aios.domain.agent.AgentStrategy
import com.agent.aios.domain.agent.ReactStrategy
import com.agent.aios.domain.model.AgentResult
import com.agent.aios.domain.model.AgentStep
import com.agent.aios.domain.model.ServiceState
import com.agent.aios.domain.model.UpdateResult
import com.agent.aios.domain.repository.LlmRepository
import com.agent.aios.domain.repository.SettingsRepository
import com.agent.aios.domain.repository.UpdateRepository
import com.agent.aios.service.ServiceRegistry
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class LlmRepositoryImpl
    @Inject
    constructor(
        @ApplicationContext private val context: Context,
        private val settingsRepository: SettingsRepository,
        private val serviceRegistry: ServiceRegistry,
        private val toolContextImpl: ToolContextImpl,
        private val updateRepository: UpdateRepository,
    ) : LlmRepository {
        private val TAG = "AIOS-LlmRepo"

        private var llmService: LlmService? = null
        private var isBound = false

        @Volatile
        private var currentStrategy: AgentStrategy? = null

        private val _tokenFlow = MutableSharedFlow<String>(extraBufferCapacity = 256)
        override val tokenStream: Flow<String> = _tokenFlow.asSharedFlow()

        private val _agentStepFlow = MutableSharedFlow<AgentStep>(extraBufferCapacity = 64)
        override val agentStepStream: Flow<AgentStep> = _agentStepFlow.asSharedFlow()

        private val _serviceState = MutableStateFlow(ServiceState.DISCONNECTED)
        override val serviceState: StateFlow<ServiceState> = _serviceState.asStateFlow()

        private val _updateAvailable = MutableStateFlow<Boolean?>(null)
        override val updateAvailable: StateFlow<Boolean?> = _updateAvailable.asStateFlow()

        private val _latestVersion = MutableStateFlow("")
        override val latestVersion: StateFlow<String> = _latestVersion.asStateFlow()

        private val _updateError = MutableStateFlow<String?>(null)
        override val updateError: StateFlow<String?> = _updateError.asStateFlow()

        private val _loadProgress = MutableStateFlow(0f)
        override val loadProgress: StateFlow<Float> = _loadProgress.asStateFlow()

        private val _loadStage = MutableStateFlow(0)
        override val loadStage: StateFlow<Int> = _loadStage.asStateFlow()

        private val appScope = CoroutineScope(Dispatchers.Main)
        private var inferenceJob: Job? = null

        private var retryCount = 0
        private val maxRetries = 3
        private val retryDelaysMs = listOf(1000L, 3000L, 5000L)

        private val serviceConnection =
            object : ServiceConnection {
                override fun onServiceConnected(
                    name: ComponentName?,
                    service: IBinder?,
                ) {
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
                    _serviceState.value = ServiceState.READY
                    Log.i(TAG, "Service connected")
                }

                override fun onServiceDisconnected(name: ComponentName?) {
                    llmService = null
                    isBound = false
                    _serviceState.value = ServiceState.DISCONNECTED
                    Log.i(TAG, "Service disconnected - scheduling reconnect")
                    scheduleRebind()
                }
            }

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
                    bindService()
                }
            }
        }

        override fun bindService() {
            try {
                _serviceState.value = ServiceState.CONNECTING
                val intent = Intent(context, LlmService::class.java)
                context.startForegroundService(intent)
                context.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start/bind LlmService", e)
                _serviceState.value = ServiceState.DISCONNECTED
            }
        }

        fun checkForUpdateBackground() {
            appScope.launch {
                try {
                    when (val result = withContext(Dispatchers.IO) { updateRepository.checkForUpdate() }) {
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
                } catch (_: Exception) {
                }
            }
        }

        override suspend fun loadModel(
            path: String,
            contextSize: Int?,
        ): Boolean {
            val svc = llmService ?: return false
            _serviceState.value = ServiceState.GENERATING
            _loadProgress.value = 0f
            _loadStage.value = 0
            return try {
                val ctxSize = contextSize ?: settingsRepository.contextSize.first()
                val pollJob =
                    appScope.launch {
                        while (isActive) {
                            withContext(Dispatchers.IO) {
                                _loadProgress.value = svc.getLoadProgress()
                                _loadStage.value = svc.getLoadStage()
                            }
                            delay(200)
                        }
                    }
                val success =
                    withContext(Dispatchers.IO) {
                        svc.updateNotification("Loading model...")
                        val result = svc.loadModel(path, ctxSize)
                        if (result) {
                            _serviceState.value = ServiceState.MODEL_LOADED
                            svc.updateNotification("Model loaded - Ready")
                            val strategy = ReactStrategy(svc)
                            strategy.setToolContext(
                                com.agent.aios.domain.ToolContext(
                                    appContext = context,
                                    accessibilityService = { serviceRegistry.accessibilityService.value },
                                ),
                            )
                            currentStrategy = strategy
                            strategy.initSystemPrompt()
                        } else {
                            _serviceState.value = ServiceState.READY
                        }
                        result
                    }
                pollJob.cancel()
                _loadProgress.value = if (success) 1f else 0f
                success
            } catch (e: Exception) {
                Log.e(TAG, "loadModel failed", e)
                _serviceState.value = ServiceState.READY
                false
            }
        }

        fun runAgent(
            prompt: String,
            maxIterations: Int? = null,
            maxTokensAgent: Int = 512,
            onComplete: (List<AgentStep>) -> Unit,
        ) {
            val svc = llmService
            if (svc == null) {
                onComplete(emptyList())
                return
            }
            val strategy = currentStrategy
            if (strategy == null) {
                onComplete(emptyList())
                return
            }
            _serviceState.value = ServiceState.AGENT_RUNNING
            inferenceJob =
                appScope.launch {
                    val iters =
                        maxIterations ?: runCatching {
                            settingsRepository.agentMaxIterations.first()
                        }.getOrDefault(8)
                    val tokens =
                        runCatching {
                            settingsRepository.maxTokensAgent.first()
                        }.getOrDefault(512)
                    withContext(Dispatchers.IO) {
                        svc.updateNotification("Agent running...")
                    }
                    val result: AgentResult =
                        strategy.execute(prompt, iters, tokens) { step ->
                            _agentStepFlow.tryEmit(step)
                        }
                    _serviceState.value = ServiceState.MODEL_LOADED
                    svc.updateNotification("Ready")
                    Log.i(TAG, "Agent done: ${result.steps.size} steps, success=${result.success}")
                    onComplete(result.steps)
                }
        }

        override fun releaseModel() {
            currentStrategy = null
            llmService?.releaseModel()
            llmService?.updateNotification("Ready")
            _serviceState.value = ServiceState.READY
        }

        override fun isModelLoaded(): Boolean {
            return llmService?.isModelLoaded() ?: false
        }

        override fun getModelInfo(): String {
            return llmService?.getModelInfo() ?: "N/A"
        }

        override fun getContextUsage(): String {
            return llmService?.getContextUsage() ?: ""
        }

        override fun resetContext() {
            llmService?.resetContext()
        }

        override fun cancelInference() {
            currentStrategy?.cancel()
            inferenceJob?.cancel()
            currentStrategy = null
            _serviceState.value = ServiceState.MODEL_LOADED
            llmService?.updateNotification("Ready")
        }

        override fun resolveConfirmation(approved: Boolean) {
            currentStrategy?.resolveConfirmation(approved)
        }
    }
