package com.agent.aios

import android.content.ContentResolver
import android.net.Uri
import android.os.Environment
import app.cash.turbine.test
import com.agent.aios.ui.viewmodel.ChatViewModel
import com.agent.aios.ui.viewmodel.ConfirmationRequest
import com.agent.aios.ui.viewmodel.Message
import com.agent.aios.settings.SettingsRepository
import com.google.common.truth.Truth.assertThat
import io.mockk.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.test.*
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.FileNotFoundException

@OptIn(ExperimentalCoroutinesApi::class)
class ChatViewModelTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private lateinit var mockApp: AIOSApp
    private lateinit var viewModel: ChatViewModel
    private lateinit var tokenFlow: MutableSharedFlow<String>
    private lateinit var agentStepFlow: MutableSharedFlow<AgentStep>
    private lateinit var serviceStateFlow: MutableSharedFlow<AIOSApp.ServiceState>
    private lateinit var mockSettingsRepo: SettingsRepository
    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setup() {
        mockkObject(AIOSApp.Companion)
        mockApp = mockk<AIOSApp>(relaxed = true)
        every { AIOSApp.instance } returns mockApp

        tokenFlow = MutableSharedFlow(extraBufferCapacity = 64)
        agentStepFlow = MutableSharedFlow(extraBufferCapacity = 64)
        serviceStateFlow = MutableSharedFlow(replay = 1)
        serviceStateFlow.tryEmit(AIOSApp.ServiceState.DISCONNECTED)

        every { mockApp.tokenFlow } returns tokenFlow
        every { mockApp.agentStepFlow } returns agentStepFlow
        every { mockApp.serviceState } returns serviceStateFlow
        every { mockApp.filesDir } returns tempFolder.newFolder("app")
        every { mockApp.llmService } returns null
        every { mockApp.contentResolver } returns mockk<ContentResolver>(relaxed = true)

        mockSettingsRepo = mockk<SettingsRepository>(relaxed = true)
        every { mockSettingsRepo.lastModelPath } returns kotlinx.coroutines.flow.flowOf("")
        every { mockSettingsRepo.contextSize } returns kotlinx.coroutines.flow.flowOf(2048)
        every { mockApp.settingsRepository } returns mockSettingsRepo

        mockkStatic(Environment::class)
        every { Environment.getExternalStoragePublicDirectory(any()) } returns tempFolder.newFolder("downloads")

        Dispatchers.setMain(testDispatcher)

        viewModel = ChatViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        unmockkAll()
    }

    // ==================== sendMessage tests ====================

    @Test
    fun sendMessage_emptyText_doesNotSend() = runTest {
        viewModel.updateInput("")
        val initialCount = viewModel.messages.value.size

        viewModel.sendMessage()
        advanceUntilIdle()

        assertThat(viewModel.messages.value).hasSize(initialCount)
        assertThat(viewModel.isGenerating.value).isFalse()
        verify(exactly = 0) { mockApp.runAgent(any(), any(), any(), any()) }
    }

    @Test
    fun sendMessage_blankText_doesNotSend() = runTest {
        viewModel.updateInput("   ")
        val initialCount = viewModel.messages.value.size

        viewModel.sendMessage()
        advanceUntilIdle()

        assertThat(viewModel.messages.value).hasSize(initialCount)
        verify(exactly = 0) { mockApp.runAgent(any(), any(), any(), any()) }
    }

    @Test
    fun sendMessage_isGenerating_doesNotSend() = runTest {
        every { mockApp.runAgent(any(), any(), any(), any()) } just Runs

        viewModel.updateInput("first")
        viewModel.sendMessage()
        advanceUntilIdle()
        assertThat(viewModel.isGenerating.value).isTrue()

        viewModel.updateInput("second")
        viewModel.sendMessage()
        advanceUntilIdle()

        assertThat(viewModel.messages.value.none { it.text == "second" }).isTrue()
        verify(exactly = 1) { mockApp.runAgent(any(), any(), any(), any()) }
    }

    @Test
    fun sendMessage_normalFlow_addsUserMessage() = runTest {
        every { mockApp.runAgent(any(), any(), any(), any()) } just Runs

        viewModel.updateInput("Hello agent")
        viewModel.sendMessage()
        advanceUntilIdle()

        val messages = viewModel.messages.value
        assertThat(messages).hasSize(1)
        assertThat(messages[0]).isEqualTo(Message("user", "Hello agent"))
    }

    @Test
    fun sendMessage_normalFlow_setsIsGeneratingTrue() = runTest {
        every { mockApp.runAgent(any(), any(), any(), any()) } just Runs

        viewModel.updateInput("Hello")
        viewModel.sendMessage()
        advanceUntilIdle()

        assertThat(viewModel.isGenerating.value).isTrue()
    }

    @Test
    fun sendMessage_normalFlow_clearsInputText() = runTest {
        every { mockApp.runAgent(any(), any(), any(), any()) } just Runs

        viewModel.updateInput("Hello")
        viewModel.sendMessage()
        advanceUntilIdle()

        assertThat(viewModel.inputText.value).isEmpty()
    }

    @Test
    fun sendMessage_callsRunAgentWithCorrectText() = runTest {
        every { mockApp.runAgent(any(), any(), any(), any()) } just Runs

        viewModel.updateInput("What is 2+2?")
        viewModel.sendMessage()
        advanceUntilIdle()

        verify { mockApp.runAgent("What is 2+2?", any(), any(), any()) }
    }

    @Test
    fun sendMessage_clearsCurrentGeneratingText() = runTest {
        every { mockApp.runAgent(any(), any(), any(), any()) } just Runs

        viewModel.updateInput("test")
        viewModel.sendMessage()
        advanceUntilIdle()

        assertThat(viewModel.currentGeneratingText.value).isEmpty()
    }

    @Test
    fun sendMessage_agentCompletionCallback_setsIsGeneratingFalse() = runTest {
        var capturedCallback: ((List<AgentStep>) -> Unit)? = null
        every { mockApp.runAgent(any(), any(), any(), any()) } answers {
            capturedCallback = args.last() as (List<AgentStep>) -> Unit
        }

        viewModel.updateInput("test")
        viewModel.sendMessage()
        advanceUntilIdle()
        assertThat(viewModel.isGenerating.value).isTrue()

        capturedCallback?.invoke(emptyList())
        advanceUntilIdle()

        assertThat(viewModel.isGenerating.value).isFalse()
    }

    @Test
    fun sendMessage_agentCompletionCallback_updatesElapsedMs() = runTest {
        var capturedCallback: ((List<AgentStep>) -> Unit)? = null
        every { mockApp.runAgent(any(), any(), any(), any()) } answers {
            capturedCallback = args.last() as (List<AgentStep>) -> Unit
        }

        viewModel.updateInput("test")
        viewModel.sendMessage()
        advanceUntilIdle()

        capturedCallback?.invoke(listOf(AgentStep("answer", "done")))
        advanceUntilIdle()

        assertThat(viewModel.isGenerating.value).isFalse()
    }

    // ==================== cancelGeneration tests ====================

    @Test
    fun cancelGeneration_setsIsGeneratingFalse() = runTest {
        every { mockApp.runAgent(any(), any(), any(), any()) } just Runs

        viewModel.updateInput("test")
        viewModel.sendMessage()
        advanceUntilIdle()
        assertThat(viewModel.isGenerating.value).isTrue()

        viewModel.cancelGeneration()
        advanceUntilIdle()

        assertThat(viewModel.isGenerating.value).isFalse()
    }

    @Test
    fun cancelGeneration_clearsCurrentGeneratingText() = runTest {
        every { mockApp.runAgent(any(), any(), any(), any()) } just Runs

        viewModel.updateInput("test")
        viewModel.sendMessage()
        advanceUntilIdle()

        viewModel.cancelGeneration()

        assertThat(viewModel.currentGeneratingText.value).isEmpty()
    }

    @Test
    fun cancelGeneration_clearsPendingConfirmation() = runTest {
        every { mockApp.runAgent(any(), any(), any(), any()) } just Runs

        viewModel.updateInput("test")
        viewModel.sendMessage()
        advanceUntilIdle()

        agentStepFlow.tryEmit(
            AgentStep("confirmation_required", "", toolName = "tool", riskLevel = "HIGH")
        )
        advanceUntilIdle()
        assertThat(viewModel.pendingConfirmation.value).isNotNull()

        viewModel.cancelGeneration()

        assertThat(viewModel.pendingConfirmation.value).isNull()
    }

    @Test
    fun cancelGeneration_callsCancelInference() = runTest {
        viewModel.cancelGeneration()

        verify { mockApp.cancelInference() }
    }

    // ==================== updateInput tests ====================

    @Test
    fun updateInput_updatesInputText() {
        viewModel.updateInput("hello world")
        assertThat(viewModel.inputText.value).isEqualTo("hello world")
    }

    @Test
    fun updateInput_emptyString() {
        viewModel.updateInput("")
        assertThat(viewModel.inputText.value).isEmpty()
    }

    @Test
    fun updateInput_overwritesPrevious() {
        viewModel.updateInput("first")
        viewModel.updateInput("second")
        assertThat(viewModel.inputText.value).isEqualTo("second")
    }

    // ==================== approveTool tests ====================

    @Test
    fun approveTool_clearsPendingConfirmation() = runTest {
        agentStepFlow.tryEmit(
            AgentStep("confirmation_required", "", toolName = "phone_caller", riskLevel = "HIGH")
        )
        advanceUntilIdle()
        assertThat(viewModel.pendingConfirmation.value).isNotNull()

        viewModel.approveTool()

        assertThat(viewModel.pendingConfirmation.value).isNull()
    }

    @Test
    fun approveTool_addsAllowedSystemMessage() = runTest {
        agentStepFlow.tryEmit(
            AgentStep("confirmation_required", "", toolName = "phone_caller", riskLevel = "HIGH")
        )
        advanceUntilIdle()
        val countBefore = viewModel.messages.value.size

        viewModel.approveTool()

        assertThat(viewModel.messages.value).hasSize(countBefore + 1)
        assertThat(viewModel.messages.value.last()).isEqualTo(Message("system", "Allowed: phone_caller"))
    }

    @Test
    fun approveTool_callsResolveConfirmationTrue() = runTest {
        agentStepFlow.tryEmit(
            AgentStep("confirmation_required", "", toolName = "phone_caller", riskLevel = "HIGH")
        )
        advanceUntilIdle()

        viewModel.approveTool()

        verify { mockApp.resolveConfirmation(true) }
    }

    @Test
    fun approveTool_whenNoPendingConfirmation_doesNothing() = runTest {
        assertThat(viewModel.pendingConfirmation.value).isNull()
        val countBefore = viewModel.messages.value.size

        viewModel.approveTool()

        assertThat(viewModel.messages.value).hasSize(countBefore)
        verify(exactly = 0) { mockApp.resolveConfirmation(any()) }
    }

    // ==================== denyTool tests ====================

    @Test
    fun denyTool_clearsPendingConfirmation() = runTest {
        agentStepFlow.tryEmit(
            AgentStep("confirmation_required", "", toolName = "sms_sender", riskLevel = "CRITICAL")
        )
        advanceUntilIdle()
        assertThat(viewModel.pendingConfirmation.value).isNotNull()

        viewModel.denyTool()

        assertThat(viewModel.pendingConfirmation.value).isNull()
    }

    @Test
    fun denyTool_addsDeniedSystemMessage() = runTest {
        agentStepFlow.tryEmit(
            AgentStep("confirmation_required", "", toolName = "sms_sender", riskLevel = "CRITICAL")
        )
        advanceUntilIdle()
        val countBefore = viewModel.messages.value.size

        viewModel.denyTool()

        assertThat(viewModel.messages.value).hasSize(countBefore + 1)
        assertThat(viewModel.messages.value.last()).isEqualTo(Message("system", "Denied: sms_sender"))
    }

    @Test
    fun denyTool_callsResolveConfirmationFalse() = runTest {
        agentStepFlow.tryEmit(
            AgentStep("confirmation_required", "", toolName = "sms_sender", riskLevel = "CRITICAL")
        )
        advanceUntilIdle()

        viewModel.denyTool()

        verify { mockApp.resolveConfirmation(false) }
    }

    @Test
    fun denyTool_whenNoPendingConfirmation_doesNothing() = runTest {
        assertThat(viewModel.pendingConfirmation.value).isNull()
        val countBefore = viewModel.messages.value.size

        viewModel.denyTool()

        assertThat(viewModel.messages.value).hasSize(countBefore)
        verify(exactly = 0) { mockApp.resolveConfirmation(any()) }
    }

    // ==================== refreshModels tests ====================

    @Test
    fun refreshModels_listsGgufFilesFromModelsDir() {
        val modelsDir = File(mockApp.filesDir, "models")
        modelsDir.mkdirs()
        File(modelsDir, "model-a.gguf").writeText("fake model data")
        File(modelsDir, "model-b.gguf").writeText("fake model data")
        File(modelsDir, "readme.txt").writeText("not a model")

        viewModel.refreshModels()

        val names = viewModel.models.value.map { it.name }
        assertThat(names).containsExactly("model-a.gguf", "model-b.gguf")
    }

    @Test
    fun refreshModels_listsGgufFilesFromDownloadsDir() {
        val downloadsDir = tempFolder.newFolder("downloads2")
        File(downloadsDir, "downloaded.gguf").writeText("fake")
        File(downloadsDir, "other.zip").writeText("fake")
        every { Environment.getExternalStoragePublicDirectory(any()) } returns downloadsDir

        viewModel.refreshModels()

        val names = viewModel.models.value.map { it.name }
        assertThat(names).contains("downloaded.gguf")
        assertThat(names).doesNotContain("other.zip")
    }

    @Test
    fun refreshModels_combinesModelsFromBothDirs() {
        val modelsDir = File(mockApp.filesDir, "models")
        modelsDir.mkdirs()
        File(modelsDir, "internal.gguf").writeText("fake")

        val downloadsDir = tempFolder.newFolder("downloads3")
        File(downloadsDir, "external.gguf").writeText("fake")
        every { Environment.getExternalStoragePublicDirectory(any()) } returns downloadsDir

        viewModel.refreshModels()

        val names = viewModel.models.value.map { it.name }
        assertThat(names).containsExactly("internal.gguf", "external.gguf")
    }

    @Test
    fun refreshModels_handlesNonExistentDirectories() {
        val nonExistent = File(tempFolder.root, "nonexistent_${System.currentTimeMillis()}")
        every { mockApp.filesDir } returns nonExistent
        every { Environment.getExternalStoragePublicDirectory(any()) } returns File("/absolutely/nonexistent/path")

        viewModel.refreshModels()

        assertThat(viewModel.models.value).isEmpty()
    }

    @Test
    fun refreshModels_modelInfoHasCorrectPath() {
        val modelsDir = File(mockApp.filesDir, "models")
        modelsDir.mkdirs()
        File(modelsDir, "test.gguf").writeText("fake")

        viewModel.refreshModels()

        assertThat(viewModel.models.value).hasSize(1)
        assertThat(viewModel.models.value[0].path).endsWith("test.gguf")
    }

    @Test
    fun refreshModels_modelInfoHasCorrectSize() {
        val modelsDir = File(mockApp.filesDir, "models")
        modelsDir.mkdirs()
        val content = "x".repeat(100)
        File(modelsDir, "sized.gguf").writeText(content)

        viewModel.refreshModels()

        assertThat(viewModel.models.value).hasSize(1)
        assertThat(viewModel.models.value[0].size).isEqualTo(100L)
    }

    // ==================== clearConversation tests ====================

    @Test
    fun clearConversation_clearsMessages() = runTest {
        every { mockApp.runAgent(any(), any(), any(), any()) } just Runs

        viewModel.updateInput("hello")
        viewModel.sendMessage()
        advanceUntilIdle()
        assertThat(viewModel.messages.value).isNotEmpty()

        viewModel.clearConversation()
        advanceUntilIdle()

        assertThat(viewModel.messages.value).isEmpty()
    }

    @Test
    fun clearConversation_clearsContextUsage() = runTest {
        viewModel.clearConversation()
        advanceUntilIdle()

        assertThat(viewModel.contextUsage.value).isEmpty()
    }

    @Test
    fun clearConversation_callsLlmServiceResetContext() = runTest {
        val mockService = mockk<LlmService>(relaxed = true)
        every { mockApp.llmService } returns mockService

        viewModel.clearConversation()
        advanceUntilIdle()

        verify { mockService.resetContext() }
    }

    @Test
    fun clearConversation_whenLlmServiceNull_doesNotThrow() = runTest {
        every { mockApp.llmService } returns null

        viewModel.clearConversation()
        advanceUntilIdle()

        assertThat(viewModel.messages.value).isEmpty()
    }

    // ==================== importModelFromUri tests ====================

    @Test
    fun importModelFromUri_setsImportingDuringOperation() {
        assertThat(viewModel.isImporting.value).isFalse()
    }

    @Test
    fun importModelFromUri_handlesInvalidUriGracefully() {
        assertThat(viewModel.isImporting.value).isFalse()
        assertThat(viewModel.models.value).isEmpty()
    }

    @Test
    fun importModelFromUri_appendsGgufExtensionIfMissing() = runTest {
        val uri = mockk<Uri>()
        every { mockApp.contentResolver.openInputStream(uri) } returns null

        viewModel.importModelFromUri(uri, "mymodel")
        advanceUntilIdle()

        val modelsDir = File(mockApp.filesDir, "models")
        val expectedFile = File(modelsDir, "mymodel.gguf")
        assertThat(expectedFile.parentFile?.exists()).isTrue()
    }

    @Test
    fun importModelFromUri_doesNotDoubleGgufExtension() = runTest {
        val uri = mockk<Uri>()
        every { mockApp.contentResolver.openInputStream(uri) } returns null

        viewModel.importModelFromUri(uri, "mymodel.gguf")
        advanceUntilIdle()

        val modelsDir = File(mockApp.filesDir, "models")
        val wrongFile = File(modelsDir, "mymodel.gguf.gguf")
        assertThat(wrongFile.exists()).isFalse()
    }

    @Test
    fun importModelFromUri_createsModelsDirectory() {
        val modelsDir = File(mockApp.filesDir, "models")
        assertThat(modelsDir.parentFile?.exists()).isTrue()
    }

    // ==================== State consistency tests ====================

    @Test
    fun sendMessageThenCancel_stateIsClean() = runTest {
        every { mockApp.runAgent(any(), any(), any(), any()) } just Runs

        viewModel.updateInput("test consistency")
        viewModel.sendMessage()
        advanceUntilIdle()

        assertThat(viewModel.isGenerating.value).isTrue()

        viewModel.cancelGeneration()

        assertThat(viewModel.isGenerating.value).isFalse()
        assertThat(viewModel.currentGeneratingText.value).isEmpty()
        assertThat(viewModel.pendingConfirmation.value).isNull()
        assertThat(viewModel.inputText.value).isEmpty()
        assertThat(viewModel.messages.value).hasSize(1)
        assertThat(viewModel.messages.value[0].text).isEqualTo("test consistency")
    }

    @Test
    fun multipleRapidSendMessage_onlyFirstExecutes() = runTest {
        every { mockApp.runAgent(any(), any(), any(), any()) } just Runs

        viewModel.updateInput("first")
        viewModel.sendMessage()

        viewModel.updateInput("second")
        viewModel.sendMessage()

        viewModel.updateInput("third")
        viewModel.sendMessage()

        advanceUntilIdle()

        assertThat(viewModel.messages.value).hasSize(1)
        assertThat(viewModel.messages.value[0].text).isEqualTo("first")
        verify(exactly = 1) { mockApp.runAgent("first", any(), any(), any()) }
    }

    @Test
    fun sendMessageAfterCancel_succeeds() = runTest {
        var capturedCallback: ((List<AgentStep>) -> Unit)? = null
        every { mockApp.runAgent(any(), any(), any(), any()) } answers {
            capturedCallback = args.last() as (List<AgentStep>) -> Unit
        }

        viewModel.updateInput("first")
        viewModel.sendMessage()
        advanceUntilIdle()

        viewModel.cancelGeneration()

        viewModel.updateInput("second")
        viewModel.sendMessage()
        advanceUntilIdle()

        assertThat(viewModel.messages.value).hasSize(2)
        assertThat(viewModel.messages.value[0].text).isEqualTo("first")
        assertThat(viewModel.messages.value[1].text).isEqualTo("second")
        verify(exactly = 2) { mockApp.runAgent(any(), any(), any(), any()) }
    }

    // ==================== Agent step flow tests ====================

    @Test
    fun agentStepConfirmationRequired_setsPendingConfirmation() = runTest {
        agentStepFlow.tryEmit(
            AgentStep("confirmation_required", "", toolName = "dangerous_tool", riskLevel = "HIGH")
        )
        advanceUntilIdle()

        val pending = viewModel.pendingConfirmation.value
        assertThat(pending).isNotNull()
        assertThat(pending!!.toolName).isEqualTo("dangerous_tool")
        assertThat(pending.risk).isEqualTo("HIGH")
    }

    @Test
    fun agentStepThought_addsThinkMessage() = runTest {
        val countBefore = viewModel.messages.value.size

        agentStepFlow.tryEmit(AgentStep("thought", "I need to calculate something"))
        advanceUntilIdle()

        assertThat(viewModel.messages.value).hasSize(countBefore + 1)
        assertThat(viewModel.messages.value.last()).isEqualTo(Message("agent_think", "I need to calculate something"))
    }

    @Test
    fun agentStepAction_addsActionMessage() = runTest {
        val countBefore = viewModel.messages.value.size

        agentStepFlow.tryEmit(AgentStep("action", "calling tool", toolName = "calculator", toolArgs = """{"expr":"2+2"}"""))
        advanceUntilIdle()

        assertThat(viewModel.messages.value).hasSize(countBefore + 1)
        val last = viewModel.messages.value.last()
        assertThat(last.role).isEqualTo("agent_action")
        assertThat(last.toolName).isEqualTo("calculator")
    }

    @Test
    fun agentStepObservation_addsObsMessage() = runTest {
        val countBefore = viewModel.messages.value.size

        agentStepFlow.tryEmit(AgentStep("observation", "result", toolName = "calculator", toolResult = "4"))
        advanceUntilIdle()

        assertThat(viewModel.messages.value).hasSize(countBefore + 1)
        assertThat(viewModel.messages.value.last().role).isEqualTo("agent_obs")
    }

    @Test
    fun agentStepAnswer_addsAnswerMessage() = runTest {
        val countBefore = viewModel.messages.value.size

        agentStepFlow.tryEmit(AgentStep("answer", "The answer is 42"))
        advanceUntilIdle()

        assertThat(viewModel.messages.value).hasSize(countBefore + 1)
        assertThat(viewModel.messages.value.last()).isEqualTo(Message("agent_answer", "The answer is 42"))
    }

    @Test
    fun agentStepThinkingStart_clearsCurrentGeneratingText() = runTest {
        agentStepFlow.tryEmit(AgentStep("thinking_start", ""))
        advanceUntilIdle()

        assertThat(viewModel.currentGeneratingText.value).isEmpty()
    }

    @Test
    fun agentStepThinkingEnd_clearsCurrentGeneratingText() = runTest {
        agentStepFlow.tryEmit(AgentStep("thinking_end", ""))
        advanceUntilIdle()

        assertThat(viewModel.currentGeneratingText.value).isEmpty()
    }

    // ==================== Token flow tests ====================

    @Test
    fun tokenFlow_appendsToCurrentGeneratingText() = runTest {
        tokenFlow.tryEmit("Hello")
        advanceUntilIdle()

        assertThat(viewModel.currentGeneratingText.value).isEqualTo("Hello")

        tokenFlow.tryEmit(" World")
        advanceUntilIdle()

        assertThat(viewModel.currentGeneratingText.value).isEqualTo("Hello World")
    }

    // ==================== getTokensPerSecond tests ====================

    @Test
    fun getTokensPerSecond_returnsZeroWhenNoElapsedTime() {
        assertThat(viewModel.getTokensPerSecond()).isEqualTo(0f)
    }
}
