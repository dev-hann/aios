package com.agent.aios.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.agent.aios.domain.model.ConfirmationRequest
import com.agent.aios.domain.model.Message
import com.agent.aios.domain.model.ServiceState
import com.agent.aios.ui.screen.ChatScreen
import com.agent.aios.ui.theme.AIOSTheme
import com.agent.aios.ui.viewmodel.ChatUiState
import com.agent.aios.ui.viewmodel.ChatViewModel
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ChatScreenTest {
    @get:Rule
    val composeRule = createComposeRule()

    private lateinit var viewModel: ChatViewModel

    @Before
    fun setup() {
        mockkStatic(android.util.Log::class)
        every { android.util.Log.i(any(), any()) } returns 0
        every { android.util.Log.e(any(), any(), any()) } returns 0
        every { android.util.Log.w(any(), any<String>()) } returns 0

        val mockLlmRepo = mockk<com.agent.aios.domain.repository.LlmRepository>(relaxed = true)
        every { mockLlmRepo.tokenStream } returns kotlinx.coroutines.flow.flowOf()
        every { mockLlmRepo.agentStepStream } returns kotlinx.coroutines.flow.flowOf()
        every { mockLlmRepo.serviceState } returns MutableStateFlow(ServiceState.DISCONNECTED)
        every { mockLlmRepo.updateAvailable } returns MutableStateFlow(null)
        every { mockLlmRepo.latestVersion } returns MutableStateFlow("")
        every { mockLlmRepo.updateError } returns MutableStateFlow(null)
        every { mockLlmRepo.loadProgress } returns MutableStateFlow(0f)
        every { mockLlmRepo.loadStage } returns MutableStateFlow(0)
        every { mockLlmRepo.isModelLoaded() } returns false

        viewModel =
            ChatViewModel::class.java.getDeclaredConstructor(
                com.agent.aios.domain.repository.LlmRepository::class.java,
                com.agent.aios.domain.repository.ModelRepository::class.java,
                com.agent.aios.domain.repository.ConversationRepository::class.java,
                com.agent.aios.domain.repository.SettingsRepository::class.java,
            ).apply {
                isAccessible = true
            }.newInstance(
                mockLlmRepo,
                mockk<com.agent.aios.domain.repository.ModelRepository>(relaxed = true),
                mockk<com.agent.aios.domain.repository.ConversationRepository>(relaxed = true),
                mockk<com.agent.aios.domain.repository.SettingsRepository>(relaxed = true),
            )
    }

    @Suppress("UNCHECKED_CAST")
    private fun setFlow(
        fieldName: String,
        value: Any?,
    ) {
        val field = ChatViewModel::class.java.getDeclaredField(fieldName)
        field.isAccessible = true
        (field.get(viewModel) as MutableStateFlow<Any?>).value = value
    }

    private fun setState(transform: ChatUiState.() -> ChatUiState) {
        val field = ChatViewModel::class.java.getDeclaredField("_uiState")
        field.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val flow = field.get(viewModel) as MutableStateFlow<ChatUiState>
        flow.value = flow.value.transform()
    }

    @After
    fun tearDown() {
        unmockkAll()
    }

    private fun setContentWithTheme() {
        composeRule.setContent {
            AIOSTheme {
                ChatScreen(vm = viewModel)
            }
        }
    }

    @Test
    fun emptyState_displaysWelcome() {
        setState { copy(isModelLoaded = false) }
        setContentWithTheme()

        composeRule.onNodeWithText("Welcome to AIOS").assertIsDisplayed()
        composeRule.onNodeWithText("Go to Settings to load a model").assertIsDisplayed()
    }

    @Test
    fun inputBar_hiddenWhenNoModel() {
        setState { copy(isModelLoaded = false) }
        setContentWithTheme()

        composeRule.onNodeWithText("Ask AIOS to do something...").assertIsNotDisplayed()
        composeRule.onNodeWithContentDescription("Send").assertIsNotDisplayed()
    }

    @Test
    fun inputBar_visibleWhenModelLoaded() {
        setState { copy(isModelLoaded = true, inputText = "") }
        setContentWithTheme()

        composeRule.onNodeWithText("Ask AIOS to do something...").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Send").assertIsDisplayed()
    }

    @Test
    fun sendButton_disabledWhenTextEmpty() {
        setState { copy(isModelLoaded = true, inputText = "") }
        setContentWithTheme()

        composeRule.onNodeWithContentDescription("Send")
            .assertIsDisplayed()
            .assertIsNotEnabled()
    }

    @Test
    fun stopButton_appearsWhenGenerating() {
        setState { copy(isModelLoaded = true, isGenerating = true) }
        setContentWithTheme()

        composeRule.onNodeWithContentDescription("Stop").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Send").assertIsNotDisplayed()
    }

    @Test
    fun modelButton_showsLoadedState() {
        setState { copy(isModelLoaded = true) }
        setContentWithTheme()

        composeRule.onNodeWithText("AIOS").assertIsDisplayed()
    }

    @Test
    fun modelButton_showsModelState() {
        setState { copy(isModelLoaded = false) }
        setContentWithTheme()

        composeRule.onNodeWithText("AIOS").assertIsDisplayed()
    }

    @Test
    fun messages_areDisplayed() {
        setState {
            copy(
                isModelLoaded = true,
                messages =
                    listOf(
                        Message("user", "Hello AIOS"),
                        Message("assistant", "Hello! How can I help?"),
                    ),
            )
        }
        setContentWithTheme()

        composeRule.onNodeWithText("Hello AIOS").assertIsDisplayed()
        composeRule.onNodeWithText("Hello! How can I help?").assertIsDisplayed()
    }

    @Test
    fun confirmationDialog_appears() {
        setState {
            copy(
                isModelLoaded = true,
                pendingConfirmation =
                    ConfirmationRequest(
                        toolName = "screen_action",
                        args = """{"action":"tap","text":"OK"}""",
                        risk = "HIGH",
                    ),
            )
        }
        setContentWithTheme()

        composeRule.onNodeWithText("Action Confirmation").assertIsDisplayed()
        composeRule.onNodeWithText("Allow").assertIsDisplayed()
        composeRule.onNodeWithText("Deny").assertIsDisplayed()
        composeRule.onNodeWithText("HIGH").assertIsDisplayed()
        composeRule.onNodeWithText("screen_action").assertIsDisplayed()
    }

    @Test
    fun modelLoadingView_showsProgressWhenGenerating() {
        setState {
            copy(
                isModelLoaded = false,
                isGenerating = true,
                serviceState = ServiceState.GENERATING,
                loadProgress = 0.5f,
                loadStage = 1,
            )
        }
        setContentWithTheme()
        composeRule.waitForIdle()

        composeRule.onNodeWithText("Loading model weights...").assertIsDisplayed()
        composeRule.onNodeWithText("50%").assertIsDisplayed()
    }

    @Test
    fun modelLoadingView_showsPreparingWhenProgressZero() {
        setState {
            copy(
                isModelLoaded = false,
                isGenerating = true,
                serviceState = ServiceState.GENERATING,
                loadProgress = 0f,
                loadStage = 0,
            )
        }
        setContentWithTheme()

        composeRule.onNodeWithText("Preparing...").assertIsDisplayed()
    }

    @Test
    fun modelLoadingView_showsTemplateStage() {
        setState {
            copy(
                isModelLoaded = false,
                isGenerating = true,
                serviceState = ServiceState.GENERATING,
                loadProgress = 0.75f,
                loadStage = 2,
            )
        }
        setContentWithTheme()
        composeRule.waitForIdle()

        composeRule.onNodeWithText("Applying chat template...").assertIsDisplayed()
        composeRule.onNodeWithText("75%").assertIsDisplayed()
    }
}
