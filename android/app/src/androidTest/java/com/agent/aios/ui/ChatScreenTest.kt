package com.agent.aios.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.agent.aios.ui.screen.ChatScreen
import com.agent.aios.ui.theme.AIOSTheme
import com.agent.aios.ui.viewmodel.ChatViewModel
import com.agent.aios.ui.viewmodel.ConfirmationRequest
import com.agent.aios.ui.viewmodel.Message
import kotlinx.coroutines.flow.MutableStateFlow
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
        viewModel = ChatViewModel()
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

    private fun setContentWithTheme() {
        composeRule.setContent {
            AIOSTheme {
                ChatScreen(vm = viewModel)
            }
        }
    }

    @Test
    fun emptyState_displaysWelcome() {
        setFlow("_isModelLoaded", false)
        setContentWithTheme()

        composeRule.onNodeWithText("Welcome to AIOS").assertIsDisplayed()
        composeRule.onNodeWithText("Get Started").assertIsDisplayed()
        composeRule.onNodeWithText("Import a GGUF model to get started").assertIsDisplayed()
    }

    @Test
    fun inputBar_hiddenWhenNoModel() {
        setFlow("_isModelLoaded", false)
        setContentWithTheme()

        composeRule.onNodeWithText("Ask AIOS to do something...").assertIsNotDisplayed()
        composeRule.onNodeWithContentDescription("Send").assertIsNotDisplayed()
    }

    @Test
    fun inputBar_visibleWhenModelLoaded() {
        setFlow("_isModelLoaded", true)
        setFlow("_inputText", "")
        setContentWithTheme()

        composeRule.onNodeWithText("Ask AIOS to do something...").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Send").assertIsDisplayed()
    }

    @Test
    fun sendButton_disabledWhenTextEmpty() {
        setFlow("_isModelLoaded", true)
        setFlow("_inputText", "")
        setContentWithTheme()

        composeRule.onNodeWithContentDescription("Send")
            .assertIsDisplayed()
            .assertIsNotEnabled()
    }

    @Test
    fun stopButton_appearsWhenGenerating() {
        setFlow("_isModelLoaded", true)
        setFlow("_isGenerating", true)
        setContentWithTheme()

        composeRule.onNodeWithContentDescription("Stop").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Send").assertIsNotDisplayed()
    }

    @Test
    fun modelButton_showsLoadedState() {
        setFlow("_isModelLoaded", true)
        setContentWithTheme()

        composeRule.onNodeWithText("Loaded").assertIsDisplayed()
    }

    @Test
    fun modelButton_showsModelState() {
        setFlow("_isModelLoaded", false)
        setContentWithTheme()

        composeRule.onNodeWithText("Model").assertIsDisplayed()
    }

    @Test
    fun messages_areDisplayed() {
        setFlow("_isModelLoaded", true)
        setFlow(
            "_messages",
            listOf(
                Message("user", "Hello AIOS"),
                Message("assistant", "Hello! How can I help?"),
            ),
        )
        setContentWithTheme()

        composeRule.onNodeWithText("Hello AIOS").assertIsDisplayed()
        composeRule.onNodeWithText("Hello! How can I help?").assertIsDisplayed()
    }

    @Test
    fun confirmationDialog_appears() {
        setFlow("_isModelLoaded", true)
        setFlow(
            "_pendingConfirmation",
            ConfirmationRequest(
                toolName = "screen_action",
                args = """{"action":"tap","text":"OK"}""",
                risk = "HIGH",
            ),
        )
        setContentWithTheme()

        composeRule.onNodeWithText("Action Confirmation").assertIsDisplayed()
        composeRule.onNodeWithText("Allow").assertIsDisplayed()
        composeRule.onNodeWithText("Deny").assertIsDisplayed()
        composeRule.onNodeWithText("HIGH").assertIsDisplayed()
        composeRule.onNodeWithText("screen_action").assertIsDisplayed()
    }
}
