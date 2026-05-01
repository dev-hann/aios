package com.agent.aios.ui.viewmodel

import com.agent.aios.AIOSApp
import com.agent.aios.settings.SettingsRepository
import com.google.common.truth.Truth.assertThat
import io.mockk.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.*
import org.junit.After
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SettingsViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var mockApp: AIOSApp
    private lateinit var mockRepo: SettingsRepository
    private lateinit var viewModel: SettingsViewModel

    private val contextSizeFlow = MutableStateFlow(SettingsRepository.DEFAULT_CONTEXT_SIZE)
    private val maxTokensChatFlow = MutableStateFlow(SettingsRepository.DEFAULT_MAX_TOKENS_CHAT)
    private val maxTokensAgentFlow = MutableStateFlow(SettingsRepository.DEFAULT_MAX_TOKENS_AGENT)
    private val temperatureFlow = MutableStateFlow(SettingsRepository.DEFAULT_TEMPERATURE)
    private val topKFlow = MutableStateFlow(SettingsRepository.DEFAULT_TOP_K)
    private val topPFlow = MutableStateFlow(SettingsRepository.DEFAULT_TOP_P)
    private val agentMaxIterationsFlow = MutableStateFlow(SettingsRepository.DEFAULT_AGENT_MAX_ITERATIONS)
    private val repeatPenaltyFlow = MutableStateFlow(SettingsRepository.DEFAULT_REPEAT_PENALTY)

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        mockkObject(AIOSApp.Companion)
        mockApp = mockk<AIOSApp>(relaxed = true)
        every { AIOSApp.instance } returns mockApp

        mockRepo = mockk<SettingsRepository>(relaxed = true)
        every { mockApp.settingsRepository } returns mockRepo

        every { mockRepo.contextSize } returns contextSizeFlow
        every { mockRepo.maxTokensChat } returns maxTokensChatFlow
        every { mockRepo.maxTokensAgent } returns maxTokensAgentFlow
        every { mockRepo.temperature } returns temperatureFlow
        every { mockRepo.topK } returns topKFlow
        every { mockRepo.topP } returns topPFlow
        every { mockRepo.agentMaxIterations } returns agentMaxIterationsFlow
        every { mockRepo.repeatPenalty } returns repeatPenaltyFlow

        viewModel = SettingsViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        unmockkAll()
    }

    @Test
    fun defaultContextSize() {
        assertThat(viewModel.contextSize.value).isEqualTo(SettingsRepository.DEFAULT_CONTEXT_SIZE)
    }

    @Test
    fun defaultMaxTokensChat() {
        assertThat(viewModel.maxTokensChat.value).isEqualTo(SettingsRepository.DEFAULT_MAX_TOKENS_CHAT)
    }

    @Test
    fun defaultMaxTokensAgent() {
        assertThat(viewModel.maxTokensAgent.value).isEqualTo(SettingsRepository.DEFAULT_MAX_TOKENS_AGENT)
    }

    @Test
    fun defaultTemperature() {
        assertThat(viewModel.temperature.value).isEqualTo(SettingsRepository.DEFAULT_TEMPERATURE)
    }

    @Test
    fun defaultTopK() {
        assertThat(viewModel.topK.value).isEqualTo(SettingsRepository.DEFAULT_TOP_K)
    }

    @Test
    fun defaultTopP() {
        assertThat(viewModel.topP.value).isEqualTo(SettingsRepository.DEFAULT_TOP_P)
    }

    @Test
    fun defaultRepeatPenalty() {
        assertThat(viewModel.repeatPenalty.value).isEqualTo(SettingsRepository.DEFAULT_REPEAT_PENALTY)
    }

    @Test
    fun defaultAgentMaxIterations() {
        assertThat(viewModel.agentMaxIterations.value).isEqualTo(SettingsRepository.DEFAULT_AGENT_MAX_ITERATIONS)
    }

    @Test
    fun updateContextSize_persistsNewValue() {
        viewModel.updateContextSize(4096)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { mockRepo.setContextSize(4096) }
    }

    @Test
    fun updateTemperature_persistsNewValue() {
        viewModel.updateTemperature(0.9f)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { mockRepo.setTemperature(0.9f) }
    }

    @Test
    fun updateMaxTokensChat_persistsNewValue() {
        viewModel.updateMaxTokensChat(256)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { mockRepo.setMaxTokensChat(256) }
    }

    @Test
    fun updateMaxTokensAgent_persistsNewValue() {
        viewModel.updateMaxTokensAgent(512)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { mockRepo.setMaxTokensAgent(512) }
    }

    @Test
    fun updateTopK_persistsNewValue() {
        viewModel.updateTopK(100)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { mockRepo.setTopK(100) }
    }

    @Test
    fun updateTopP_persistsNewValue() {
        viewModel.updateTopP(0.95f)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { mockRepo.setTopP(0.95f) }
    }

    @Test
    fun updateAgentMaxIterations_persistsNewValue() {
        viewModel.updateAgentMaxIterations(10)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { mockRepo.setAgentMaxIterations(10) }
    }

    @Test
    fun updateRepeatPenalty_persistsNewValue() {
        viewModel.updateRepeatPenalty(1.2f)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { mockRepo.setRepeatPenalty(1.2f) }
    }

    @Test
    fun contextSize_reflectsRepoChange() {
        contextSizeFlow.value = 8192
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.contextSize.value).isEqualTo(8192)
    }

    @Test
    fun temperature_reflectsRepoChange() {
        temperatureFlow.value = 0.5f
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.temperature.value).isEqualTo(0.5f)
    }
}
