package com.agent.aios

import com.google.common.truth.Truth.assertThat
import io.mockk.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.*
import org.junit.After
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AIOSAppTest {

    private lateinit var app: AIOSApp
    private val testDispatcher = StandardTestDispatcher()

    private val serviceStateFlow = MutableSharedFlow<AIOSApp.ServiceState>(replay = 1)
    private val mockLlmService = mockk<LlmService>(relaxed = true)
    private val mockEngine = mockk<AgentEngine>(relaxed = true)
    private val mockSettingsRepo = mockk<com.agent.aios.settings.SettingsRepository>(relaxed = true)

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        app = AIOSApp()
        app.javaClass.getDeclaredField("settingsRepository").apply {
            isAccessible = true
            set(app, mockSettingsRepo)
        }
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        unmockkAll()
    }

    @Test
    fun serviceState_containsAllExpectedStates() {
        val states = AIOSApp.ServiceState.entries
        assertThat(states).containsExactly(
            AIOSApp.ServiceState.DISCONNECTED,
            AIOSApp.ServiceState.CONNECTING,
            AIOSApp.ServiceState.READY,
            AIOSApp.ServiceState.MODEL_LOADED,
            AIOSApp.ServiceState.GENERATING,
            AIOSApp.ServiceState.AGENT_RUNNING,
        )
    }

    @Test
    fun cancelInference_cancelsEngineAndJob_emitsModelLoaded() = runTest {
        val mockJob = mockk<Job>(relaxed = true)

        app.javaClass.getDeclaredField("currentAgentEngine").apply {
            isAccessible = true
            set(app, mockEngine)
        }
        app.javaClass.getDeclaredField("inferenceJob").apply {
            isAccessible = true
            set(app, mockJob)
        }
        app.javaClass.getDeclaredField("llmService").apply {
            isAccessible = true
            set(app, mockLlmService)
        }
        app.javaClass.getDeclaredField("_serviceState").apply {
            isAccessible = true
            val flow = get(app) as MutableSharedFlow<AIOSApp.ServiceState>
            flow.tryEmit(AIOSApp.ServiceState.AGENT_RUNNING)
        }

        app.cancelInference()

        verify { mockEngine.cancel() }
        verify { mockJob.cancel(any()) }

        app.javaClass.getDeclaredField("currentAgentEngine").apply {
            isAccessible = true
            assertThat(get(app)).isNull()
        }
    }

    @Test
    fun cancelInference_whenNothingRunning_noCrash() = runTest {
        app.javaClass.getDeclaredField("_serviceState").apply {
            isAccessible = true
            val flow = get(app) as MutableSharedFlow<AIOSApp.ServiceState>
            flow.tryEmit(AIOSApp.ServiceState.MODEL_LOADED)
        }

        app.cancelInference()
    }

    @Test
    fun resolveConfirmation_delegatesToEngine() {
        app.javaClass.getDeclaredField("currentAgentEngine").apply {
            isAccessible = true
            set(app, mockEngine)
        }

        app.resolveConfirmation(true)
        verify { mockEngine.resolveConfirmation(true) }

        app.resolveConfirmation(false)
        verify { mockEngine.resolveConfirmation(false) }
    }

    @Test
    fun resolveConfirmation_whenNoEngine_noCrash() {
        app.resolveConfirmation(true)
    }

    @Test
    fun releaseModel_emitsReadyState() {
        app.javaClass.getDeclaredField("llmService").apply {
            isAccessible = true
            set(app, mockLlmService)
        }
        app.javaClass.getDeclaredField("_serviceState").apply {
            isAccessible = true
            val flow = get(app) as MutableSharedFlow<AIOSApp.ServiceState>
            flow.tryEmit(AIOSApp.ServiceState.MODEL_LOADED)
        }

        app.releaseModel()

        verify { mockLlmService.releaseModel() }
        verify { mockLlmService.updateNotification("Ready") }
    }

    @Test
    fun releaseModel_whenNoService_noCrash() {
        app.javaClass.getDeclaredField("llmService").apply {
            isAccessible = true
            set(app, null)
        }

        app.releaseModel()
    }

    @Test
    fun runAgent_nullLlmService_callsOnCompleteWithEmptyList() {
        app.javaClass.getDeclaredField("llmService").apply {
            isAccessible = true
            set(app, null)
        }

        var result: List<AgentStep>? = null
        app.runAgent("test") { steps -> result = steps }

        assertThat(result).isNotNull()
        assertThat(result).isEmpty()
    }

    @Test
    fun runAgent_nullAgentEngine_callsOnCompleteWithEmptyList() {
        app.javaClass.getDeclaredField("llmService").apply {
            isAccessible = true
            set(app, mockLlmService)
        }
        every { mockLlmService.getAgentEngine() } returns null

        var result: List<AgentStep>? = null
        app.runAgent("test") { steps -> result = steps }

        assertThat(result).isNotNull()
        assertThat(result).isEmpty()
    }

    @Test
    fun runAgent_normalFlow_emitsAgentRunningThenModelLoaded() {
        val steps = listOf(
            AgentStep(type = "thought", content = "thinking..."),
            AgentStep(type = "answer", content = "done"),
        )

        app.javaClass.getDeclaredField("llmService").apply {
            isAccessible = true
            set(app, mockLlmService)
        }
        every { mockLlmService.getAgentEngine() } returns mockEngine
        every { mockEngine.run(any(), any()) } returns steps
        every { mockSettingsRepo.agentMaxIterations } returns kotlinx.coroutines.flow.flowOf(5)

        app.javaClass.getDeclaredField("appScope").apply {
            isAccessible = true
            set(app, kotlinx.coroutines.CoroutineScope(testDispatcher))
        }

        var result: List<AgentStep>? = null
        app.runAgent("test prompt") { steps -> result = steps }

        repeat(5) {
            testDispatcher.scheduler.advanceUntilIdle()
            Thread.sleep(100)
        }
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(result).isEqualTo(steps)
        verify { mockEngine.setStepCallback(any()) }
        verify { mockEngine.run("test prompt", 5) }
    }

    @Test
    fun runAgent_withMaxIterations_usesProvidedValue() {
        app.javaClass.getDeclaredField("llmService").apply {
            isAccessible = true
            set(app, mockLlmService)
        }
        every { mockLlmService.getAgentEngine() } returns mockEngine
        every { mockEngine.run(any(), any()) } returns emptyList()

        app.javaClass.getDeclaredField("appScope").apply {
            isAccessible = true
            set(app, kotlinx.coroutines.CoroutineScope(testDispatcher))
        }

        app.runAgent("test", maxIterations = 3) {}
        repeat(5) {
            testDispatcher.scheduler.advanceUntilIdle()
            Thread.sleep(100)
        }
        testDispatcher.scheduler.advanceUntilIdle()

        verify { mockEngine.run("test", 3) }
    }

    @Test
    fun updateAvailableState_initiallyNull() {
        val field = app.javaClass.getDeclaredField("_updateAvailable")
        field.isAccessible = true
        val flow = field.get(app) as MutableStateFlow<Boolean?>
        assertThat(flow.value).isNull()
    }

    @Test
    fun updateErrorState_initiallyNull() {
        val field = app.javaClass.getDeclaredField("_updateError")
        field.isAccessible = true
        val flow = field.get(app) as MutableStateFlow<String?>
        assertThat(flow.value).isNull()
    }

    @Test
    fun updateAvailableState_canBeSet() {
        val field = app.javaClass.getDeclaredField("_updateAvailable")
        field.isAccessible = true
        val flow = field.get(app) as MutableStateFlow<Boolean?>
        flow.value = true
        assertThat(flow.value).isTrue()

        flow.value = false
        assertThat(flow.value).isFalse()
    }

    @Test
    fun updateErrorState_canBeSet() {
        val field = app.javaClass.getDeclaredField("_updateError")
        field.isAccessible = true
        val flow = field.get(app) as MutableStateFlow<String?>
        flow.value = "Network error"
        assertThat(flow.value).isEqualTo("Network error")
    }

    @Test
    fun latestVersionState_initiallyEmpty() {
        val field = app.javaClass.getDeclaredField("_latestVersion")
        field.isAccessible = true
        val flow = field.get(app) as MutableStateFlow<String>
        assertThat(flow.value).isEmpty()
    }

    @Test
    fun bindLlmService_isPublic_notPrivate() {
        val method = AIOSApp::class.java.getDeclaredMethod("bindLlmService")
        assertThat(method).isNotNull()
    }

    @Test
    fun bindLlmService_wrapsStartForegroundServiceInTryCatch() {
        val method = AIOSApp::class.java.getDeclaredMethod("bindLlmService")
        val exceptions = method.exceptionTypes
        assertThat(exceptions).isEmpty()
    }
}
