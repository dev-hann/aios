package com.agent.aios

import com.agent.aios.data.llm.LlmRepositoryImpl
import com.agent.aios.data.tool.ToolContextImpl
import com.agent.aios.domain.agent.AgentStrategy
import com.agent.aios.domain.model.AgentResult
import com.agent.aios.domain.model.AgentStep
import com.agent.aios.domain.model.ServiceState
import com.agent.aios.domain.repository.LlmRepository
import com.agent.aios.domain.repository.SettingsRepository
import com.agent.aios.domain.repository.UpdateRepository
import com.agent.aios.service.ServiceRegistry
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
class LlmRepositoryImplTest {
    private lateinit var repo: LlmRepositoryImpl
    private lateinit var mockSettingsRepo: SettingsRepository
    private lateinit var mockUpdateRepo: UpdateRepository
    private lateinit var mockServiceRegistry: ServiceRegistry
    private lateinit var mockToolContextImpl: ToolContextImpl
    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        mockkStatic(android.util.Log::class)
        every { android.util.Log.i(any(), any()) } returns 0
        every { android.util.Log.e(any(), any(), any()) } returns 0
        every { android.util.Log.d(any(), any()) } returns 0
        every { android.util.Log.w(any(), any<String>()) } returns 0

        mockSettingsRepo = mockk(relaxed = true)
        mockUpdateRepo = mockk(relaxed = true)
        mockServiceRegistry = mockk(relaxed = true)
        mockToolContextImpl = mockk(relaxed = true)

        every { mockSettingsRepo.agentMaxIterations } returns flowOf(8)
        every { mockSettingsRepo.maxTokensAgent } returns flowOf(512)

        repo = LlmRepositoryImpl(
            context = mockk(relaxed = true),
            settingsRepository = mockSettingsRepo,
            serviceRegistry = mockServiceRegistry,
            toolContextImpl = mockToolContextImpl,
            updateRepository = mockUpdateRepo,
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        unmockkAll()
    }

    @Test
    fun serviceState_initiallyDisconnected() {
        assertThat(repo.serviceState.value).isEqualTo(ServiceState.DISCONNECTED)
    }

    @Test
    fun updateAvailableState_initiallyNull() {
        assertThat(repo.updateAvailable.value).isNull()
    }

    @Test
    fun updateErrorState_initiallyNull() {
        assertThat(repo.updateError.value).isNull()
    }

    @Test
    fun latestVersionState_initiallyEmpty() {
        assertThat(repo.latestVersion.value).isEmpty()
    }

    @Test
    fun isModelLoaded_whenNoService_returnsFalse() {
        assertThat(repo.isModelLoaded()).isFalse()
    }

    @Test
    fun getModelInfo_whenNoService_returnsNA() {
        assertThat(repo.getModelInfo()).isEqualTo("N/A")
    }

    @Test
    fun getContextUsage_whenNoService_returnsEmpty() {
        assertThat(repo.getContextUsage()).isEmpty()
    }

    @Test
    fun resolveConfirmation_whenNoStrategy_noCrash() {
        repo.resolveConfirmation(true)
        repo.resolveConfirmation(false)
    }

    @Test
    fun cancelInference_whenNothingRunning_noCrash() {
        repo.cancelInference()
        assertThat(repo.serviceState.value).isEqualTo(ServiceState.MODEL_LOADED)
    }

    @Test
    fun runAgent_whenNoService_callsOnCompleteWithEmptyList() {
        var result: List<AgentStep>? = null
        repo.runAgent("test") { steps -> result = steps }
        assertThat(result).isNotNull()
        assertThat(result).isEmpty()
    }

    @Test
    fun runAgent_whenNoStrategy_callsOnCompleteWithEmptyList() {
        var result: List<AgentStep>? = null
        repo.runAgent("test") { steps -> result = steps }
        assertThat(result).isNotNull()
        assertThat(result).isEmpty()
    }

    @Test
    fun serviceState_containsAllExpectedStates() {
        val states = ServiceState.entries
        assertThat(states).containsExactly(
            ServiceState.DISCONNECTED,
            ServiceState.CONNECTING,
            ServiceState.READY,
            ServiceState.MODEL_LOADED,
            ServiceState.GENERATING,
            ServiceState.AGENT_RUNNING,
        )
    }
}
