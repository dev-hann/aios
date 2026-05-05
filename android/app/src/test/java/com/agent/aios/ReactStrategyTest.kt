package com.agent.aios

import com.agent.aios.domain.agent.ReactStrategy
import com.agent.aios.domain.agent.ResponseParser
import com.agent.aios.domain.agent.RiskClassifier
import com.agent.aios.domain.model.AgentResult
import com.agent.aios.domain.model.AgentStep
import com.agent.aios.domain.model.ToolRisk
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import io.mockk.verify
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.LinkedList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], manifest = Config.NONE)
class ReactStrategyTest {
    private lateinit var mockService: LlmService
    private lateinit var strategy: ReactStrategy
    private val responseQueue = LinkedList<String>()

    @Before
    fun setup() {
        mockkStatic(android.util.Log::class)
        every { android.util.Log.i(any(), any()) } returns 0
        every { android.util.Log.e(any(), any(), any()) } returns 0
        every { android.util.Log.d(any(), any()) } returns 0
        every { android.util.Log.w(any(), any<String>()) } returns 0

        mockService = mockk(relaxed = true)
        strategy = ReactStrategy(mockService)
        responseQueue.clear()
    }

    @After
    fun tearDown() {
        unmockkStatic(android.util.Log::class)
    }

    private fun setupRunMock(blockOnEmpty: Boolean = false) {
        var returnedThisSession = false

        every { mockService.processPrompt(any()) } answers {
            returnedThisSession = false
            0
        }

        every { mockService.processPromptIncremental(any()) } answers {
            returnedThisSession = false
            0
        }

        every { mockService.setSystemPromptPosition() } answers { nothing }

        every { mockService.processSystemPrompt(any()) } returns 0

        every { mockService.generateTokensBatch(any()) } returns null

        every { mockService.generateOneToken() } answers {
            if (returnedThisSession) {
                if (blockOnEmpty) {
                    Thread.sleep(30000)
                }
                null
            } else {
                val response = responseQueue.poll()
                if (response != null) {
                    returnedThisSession = true
                    response
                } else if (blockOnEmpty) {
                    Thread.sleep(30000)
                    null
                } else {
                    null
                }
            }
        }

        every { mockService.formatChat(any(), any()) } returns "formatted"
        every { mockService.getContextUsage() } returns "100/1000"
    }

    // ==================== ResponseParser ====================

    @Test
    fun parseResponse_actionWithArgs() {
        val parser = ResponseParser(setOf("calculator"))
        val parsed = parser.parse("Action: calculator\nArgs: {\"expression\": \"2+3\"}")
        assertTrue(parsed is ResponseParser.ParseResult.Action)
        val action = parsed as ResponseParser.ParseResult.Action
        assertEquals("calculator", action.toolName)
        assertTrue(action.args.contains("expression"))
        assertTrue(action.args.contains("2+3"))
    }

    @Test
    fun parseResponse_actionWithoutArgs_returnsDefaultEmptyJson() {
        val parser = ResponseParser(setOf("calculator"))
        val parsed = parser.parse("Action: calculator")
        assertTrue(parsed is ResponseParser.ParseResult.Action)
        assertEquals("calculator", (parsed as ResponseParser.ParseResult.Action).toolName)
        assertEquals("{}", parsed.args)
    }

    @Test
    fun parseResponse_answer() {
        val parser = ResponseParser(setOf("calculator"))
        val parsed = parser.parse("Answer: The result is 42")
        assertTrue(parsed is ResponseParser.ParseResult.Answer)
        assertEquals("The result is 42", (parsed as ResponseParser.ParseResult.Answer).text)
    }

    @Test
    fun parseResponse_plainText_returnsEmpty() {
        val parser = ResponseParser(setOf("calculator"))
        val parsed = parser.parse("Just some random text without action or answer")
        assertEquals(ResponseParser.ParseResult.Empty, parsed)
    }

    @Test
    fun parseResponse_caseInsensitiveAction() {
        val parser = ResponseParser(setOf("timer"))
        val parsed = parser.parse("ACTION: timer\nARGS: {\"seconds\": 5}")
        assertTrue(parsed is ResponseParser.ParseResult.Action)
        assertEquals("timer", (parsed as ResponseParser.ParseResult.Action).toolName)
    }

    @Test
    fun parseResponse_caseInsensitiveAnswer() {
        val parser = ResponseParser(setOf())
        val parsed = parser.parse("ANSWER: yes it works")
        assertTrue(parsed is ResponseParser.ParseResult.Answer)
        assertEquals("yes it works", (parsed as ResponseParser.ParseResult.Answer).text)
    }

    @Test
    fun parseResponse_mixedCaseAction() {
        val parser = ResponseParser(setOf("device_info"))
        val parsed = parser.parse("AcTiOn: device_info\nArGs: {}")
        assertTrue(parsed is ResponseParser.ParseResult.Action)
        assertEquals("device_info", (parsed as ResponseParser.ParseResult.Action).toolName)
    }

    @Test
    fun parseResponse_multilineActionWithComplexJsonArgs() {
        val parser = ResponseParser(setOf("screen_action"))
        val input =
            """
            Action: screen_action
            Args: {"action": "tap", "x": 100, "y": 200}
            """.trimIndent()
        val parsed = parser.parse(input)
        assertTrue(parsed is ResponseParser.ParseResult.Action)
        val action = parsed as ResponseParser.ParseResult.Action
        assertEquals("screen_action", action.toolName)
        assertTrue(action.args.contains("tap"))
        assertTrue(action.args.contains("100"))
        assertTrue(action.args.contains("200"))
    }

    @Test
    fun parseResponse_nestedJsonInArgs_handlesBalancedBraces() {
        val parser = ResponseParser(setOf("screen_action"))
        val input = "Action: screen_action\nArgs: {\"action\": \"type\", \"target\": {\"x\": 100}}"
        val parsed = parser.parse(input)
        assertTrue(parsed is ResponseParser.ParseResult.Action)
        val action = parsed as ResponseParser.ParseResult.Action
        assertTrue(action.args.endsWith("}}"))
        assertTrue(action.args.contains("type"))
    }

    @Test
    fun parseResponse_whitespaceAroundColon() {
        val parser = ResponseParser(setOf("calculator"))
        val parsed = parser.parse("Action :  calculator  \n Args : {\"expression\": \"1+1\"}")
        assertTrue(parsed is ResponseParser.ParseResult.Action)
        val action = parsed as ResponseParser.ParseResult.Action
        assertEquals("calculator", action.toolName)
        assertEquals("{\"expression\": \"1+1\"}", action.args)
    }

    @Test
    fun parseResponse_emptyString_returnsEmpty() {
        val parser = ResponseParser(setOf("calculator"))
        assertEquals(ResponseParser.ParseResult.Empty, parser.parse(""))
    }

    @Test
    fun parseResponse_whitespaceOnly_returnsEmpty() {
        val parser = ResponseParser(setOf("calculator"))
        assertEquals(ResponseParser.ParseResult.Empty, parser.parse("   \n\t  "))
    }

    @Test
    fun parseResponse_answerWithMultilineContent() {
        val parser = ResponseParser(setOf())
        val input = "Answer: First line\nSecond line\nThird line"
        val parsed = parser.parse(input)
        assertTrue(parsed is ResponseParser.ParseResult.Answer)
        assertEquals("First line\nSecond line\nThird line", (parsed as ResponseParser.ParseResult.Answer).text)
    }

    // ==================== RiskClassifier ====================

    @Test
    fun classifyRisk_calculator_isSafe() {
        assertEquals(ToolRisk.SAFE, RiskClassifier().classify("calculator", "{}"))
    }

    @Test
    fun classifyRisk_timer_isSafe() {
        assertEquals(ToolRisk.SAFE, RiskClassifier().classify("timer", "{}"))
    }

    @Test
    fun classifyRisk_deviceInfo_isSafe() {
        assertEquals(ToolRisk.SAFE, RiskClassifier().classify("device_info", "{}"))
    }

    @Test
    fun classifyRisk_notepad_isSafe() {
        assertEquals(ToolRisk.SAFE, RiskClassifier().classify("notepad", "{}"))
    }

    @Test
    fun classifyRisk_screenReader_isSafe() {
        assertEquals(ToolRisk.SAFE, RiskClassifier().classify("screen_reader", "{}"))
    }

    @Test
    fun classifyRisk_screenFind_isSafe() {
        assertEquals(ToolRisk.SAFE, RiskClassifier().classify("screen_find", "{}"))
    }

    @Test
    fun classifyRisk_notificationReader_isSafe() {
        assertEquals(ToolRisk.SAFE, RiskClassifier().classify("notification_reader", "{}"))
    }

    @Test
    fun classifyRisk_contactSearch_isSafe() {
        assertEquals(ToolRisk.SAFE, RiskClassifier().classify("contact_search", "{}"))
    }

    @Test
    fun classifyRisk_smsSender_send_isCritical() {
        assertEquals(ToolRisk.CRITICAL, RiskClassifier().classify("sms_sender", "{\"action\": \"send\"}"))
    }

    @Test
    fun classifyRisk_smsSender_read_isHigh() {
        assertEquals(ToolRisk.HIGH, RiskClassifier().classify("sms_sender", "{\"action\": \"read\"}"))
    }

    @Test
    fun classifyRisk_phoneCaller_call_isCritical() {
        assertEquals(ToolRisk.CRITICAL, RiskClassifier().classify("phone_caller", "{\"action\": \"call\"}"))
    }

    @Test
    fun classifyRisk_phoneCaller_dial_isHigh() {
        assertEquals(ToolRisk.HIGH, RiskClassifier().classify("phone_caller", "{\"action\": \"dial\"}"))
    }

    @Test
    fun classifyRisk_screenAction_tap_isHigh() {
        assertEquals(ToolRisk.HIGH, RiskClassifier().classify("screen_action", "{\"action\": \"tap\"}"))
    }

    @Test
    fun classifyRisk_screenAction_global_isLow() {
        assertEquals(ToolRisk.LOW, RiskClassifier().classify("screen_action", "{\"action\": \"global\"}"))
    }

    @Test
    fun classifyRisk_screenAction_typePassword_isCritical() {
        assertEquals(ToolRisk.CRITICAL, RiskClassifier().classify("screen_action", "{\"action\": \"type\", \"content\": \"enter your password\"}"))
    }

    @Test
    fun classifyRisk_screenAction_typePin_isCritical() {
        assertEquals(ToolRisk.CRITICAL, RiskClassifier().classify("screen_action", "{\"action\": \"type\", \"content\": \"enter your pin\"}"))
    }

    @Test
    fun classifyRisk_screenAction_typeCvv_isCritical() {
        assertEquals(ToolRisk.CRITICAL, RiskClassifier().classify("screen_action", "{\"action\": \"type\", \"content\": \"cvv code\"}"))
    }

    @Test
    fun classifyRisk_screenAction_typeOtp_isCritical() {
        assertEquals(ToolRisk.CRITICAL, RiskClassifier().classify("screen_action", "{\"action\": \"type\", \"content\": \"otp verification\"}"))
    }

    @Test
    fun classifyRisk_appLauncher_openApp_isHigh() {
        assertEquals(ToolRisk.HIGH, RiskClassifier().classify("app_launcher", "{\"action\": \"open_app\"}"))
    }

    @Test
    fun classifyRisk_appLauncher_openSettings_isLow() {
        assertEquals(ToolRisk.LOW, RiskClassifier().classify("app_launcher", "{\"action\": \"open_settings\"}"))
    }

    @Test
    fun classifyRisk_unknownTool_isHigh() {
        assertEquals(ToolRisk.HIGH, RiskClassifier().classify("nonexistent_tool", "{}"))
    }

    @Test
    fun classifyRisk_invalidJson_defaultsActionToEmpty() {
        val classifier = RiskClassifier()
        assertEquals(ToolRisk.SAFE, classifier.classify("calculator", "not json"))
        assertEquals(ToolRisk.HIGH, classifier.classify("screen_action", "not json"))
        assertEquals(ToolRisk.LOW, classifier.classify("app_launcher", "not json"))
    }

    @Test
    fun classifyRisk_caseInsensitiveAction() {
        assertEquals(ToolRisk.CRITICAL, RiskClassifier().classify("sms_sender", "{\"action\": \"SEND\"}"))
        assertEquals(ToolRisk.CRITICAL, RiskClassifier().classify("phone_caller", "{\"action\": \"CALL\"}"))
    }

    // ==================== Confirmation Flow ====================

    @Test
    fun safeTool_executesWithoutConfirmation() {
        setupRunMock()
        responseQueue.add("Action: calculator\nArgs: {\"expression\": \"2+3\"}")

        val result = runBlocking { strategy.execute("Calculate 2+3") {} }

        assertFalse(result.steps.any { it.type == "confirmation_required" })
        assertTrue(result.steps.any { it.type == "action" && it.toolName == "calculator" })
        assertTrue(result.steps.any { it.type == "observation" })
    }

    @Test
    fun highRiskTool_approved_executes() {
        setupRunMock()
        responseQueue.add("Action: screen_action\nArgs: {\"action\": \"tap\", \"x\": 100, \"y\": 200}")

        val callbackSteps = mutableListOf<AgentStep>()
        var result: AgentResult? = null
        val latch = CountDownLatch(1)

        thread {
            result =
                runBlocking {
                    strategy.execute("Tap the screen") { step ->
                        callbackSteps.add(step)
                    }
                }
            latch.countDown()
        }

        Thread.sleep(500)
        assertTrue(callbackSteps.any { it.type == "confirmation_required" })
        strategy.resolveConfirmation(true)

        assertTrue(latch.await(5, TimeUnit.SECONDS))

        assertNotNull(result)
        assertTrue(result!!.steps.any { it.type == "observation" })
        val obs = result!!.steps.find { it.type == "observation" }
        assertNotNull(obs)
        assertNotEquals("Action cancelled by user", obs!!.toolResult)
    }

    @Test
    fun highRiskTool_rejected_returnsCancelled() {
        setupRunMock()
        responseQueue.add("Action: screen_action\nArgs: {\"action\": \"tap\", \"x\": 100, \"y\": 200}")

        var result: AgentResult? = null
        val latch = CountDownLatch(1)

        thread {
            result = runBlocking { strategy.execute("Tap the screen") {} }
            latch.countDown()
        }

        Thread.sleep(500)
        strategy.resolveConfirmation(false)

        assertTrue(latch.await(5, TimeUnit.SECONDS))

        val obs = result!!.steps.find { it.type == "observation" }
        assertNotNull(obs)
        assertEquals("Action cancelled by user", obs!!.toolResult)
    }

    @Test
    fun cancelDuringConfirmation_resolves() {
        setupRunMock()
        responseQueue.add("Action: screen_action\nArgs: {\"action\": \"tap\", \"x\": 50, \"y\": 50}")

        val callbackSteps = mutableListOf<AgentStep>()
        var result: AgentResult? = null
        val latch = CountDownLatch(1)

        thread {
            result =
                runBlocking {
                    strategy.execute("Tap something") { step ->
                        callbackSteps.add(step)
                    }
                }
            latch.countDown()
        }

        Thread.sleep(500)

        assertTrue(callbackSteps.any { it.type == "confirmation_required" })

        strategy.cancel()
        assertTrue(latch.await(5, TimeUnit.SECONDS))

        val obs = result!!.steps.find { it.type == "observation" }
        assertNotNull(obs)
        assertEquals("Action cancelled by user", obs!!.toolResult)
    }

    // ==================== Thread Safety ====================

    @Test
    fun cancelDuringInference_interruptedExceptionCaught() {
        val inferEntered = CountDownLatch(1)

        every { mockService.processPrompt(any()) } returns 0
        every { mockService.generateTokensBatch(any()) } returns null

        every { mockService.generateOneToken() } answers {
            inferEntered.countDown()
            Thread.sleep(30000)
            null
        }

        every { mockService.formatChat(any(), any()) } returns "formatted"
        every { mockService.getContextUsage() } returns "100/1000"

        var result: AgentResult? = null
        val runLatch = CountDownLatch(1)

        thread {
            result = runBlocking { strategy.execute("Do something") {} }
            runLatch.countDown()
        }

        assertTrue(inferEntered.await(5, TimeUnit.SECONDS))
        Thread.sleep(100)
        strategy.cancel()

        assertTrue(runLatch.await(5, TimeUnit.SECONDS))
        assertTrue(result!!.steps.any { it.type == "answer" && it.content == "Task cancelled." })
    }

    @Test
    fun concurrentResolveConfirmation_doesNotCrash() {
        var error: Throwable? = null
        val threads =
            (1..10).map {
                thread {
                    try {
                        strategy.resolveConfirmation(it % 2 == 0)
                    } catch (e: Throwable) {
                        error = e
                    }
                }
            }
        threads.forEach { it.join(2000) }
        assertNull(error)
    }

    // ==================== Edge Cases ====================

    @Test
    fun execute_emptyPrompt_stillProcesses() {
        setupRunMock()
        responseQueue.add("Answer: I'm ready to help!")

        val result = runBlocking { strategy.execute("") {} }

        assertTrue(result.steps.any { it.type == "thought" })
        assertTrue(result.steps.any { it.type == "answer" })
    }

    @Test
    fun execute_iterationLimitReached_returnsCouldNotComplete() {
        setupRunMock()
        repeat(20) {
            responseQueue.add("Action: calculator\nArgs: {\"expression\": \"1+1\"}")
        }

        val result = runBlocking { strategy.execute("Loop forever", maxIterations = 3) {} }

        val answerStep = result.steps.find { it.type == "answer" }
        assertNotNull(answerStep)
        val content = answerStep!!.content
        assertTrue(
            "Answer should indicate failure, got: $content",
            content.contains("완료하지 못했") || content.contains("couldn't complete"),
        )
    }

    @Test
    fun execute_plainTextResponse_breaksAsDirectAnswer() {
        setupRunMock()
        responseQueue.add("This is just a plain text response without any action or answer prefix.")

        val result = runBlocking { strategy.execute("Tell me something") {} }

        val answerStep = result.steps.find { it.type == "answer" }
        assertNotNull(answerStep)
        assertEquals("This is just a plain text response without any action or answer prefix.", answerStep!!.content)
    }

    @Test
    fun execute_multipleToolCallsThenAnswer() {
        setupRunMock()
        responseQueue.add("Action: calculator\nArgs: {\"expression\": \"2+3\"}")
        responseQueue.add("Action: calculator\nArgs: {\"expression\": \"10*5\"}")
        responseQueue.add("Answer: The results are 5 and 50.")

        val result = runBlocking { strategy.execute("Calculate 2+3 and 10*5") {} }

        val actionSteps = result.steps.filter { it.type == "action" }
        assertEquals(2, actionSteps.size)
        assertEquals("calculator", actionSteps[0].toolName)
        assertEquals("calculator", actionSteps[1].toolName)

        val answerStep = result.steps.find { it.type == "answer" }
        assertNotNull(answerStep)
        assertTrue(answerStep!!.content.contains("5"))
        assertTrue(answerStep.content.contains("50"))
    }

    // ==================== Audit Log ====================

    @Test
    fun auditLog_recordsSafeToolExecution() {
        setupRunMock()
        responseQueue.add("Action: calculator\nArgs: {\"expression\": \"2+3\"}")

        runBlocking { strategy.execute("Calculate 2+3") {} }

        val log = strategy.getAuditLog()
        assertTrue(log.isNotEmpty())
        val entry = log.find { it.tool == "calculator" }
        assertNotNull(entry)
        assertTrue(entry!!.approved)
        assertEquals(ToolRisk.SAFE, entry.risk)
        assertTrue(entry.result.contains("5"))
    }

    @Test
    fun auditLog_recordsCancelledAction() {
        setupRunMock()
        responseQueue.add("Action: screen_action\nArgs: {\"action\": \"tap\", \"x\": 100, \"y\": 200}")

        var result: AgentResult? = null
        val latch = CountDownLatch(1)

        thread {
            result = runBlocking { strategy.execute("Tap something") {} }
            latch.countDown()
        }

        Thread.sleep(500)
        strategy.resolveConfirmation(false)
        assertTrue(latch.await(5, TimeUnit.SECONDS))

        val log = strategy.getAuditLog()
        val entry = log.find { it.tool == "screen_action" }
        assertNotNull(entry)
        assertFalse(entry!!.approved)
        assertEquals("Cancelled by user", entry.result)
        assertEquals(ToolRisk.HIGH, entry.risk)
    }

    @Test
    fun auditLog_cappedAt100() {
        setupRunMock()
        repeat(110) {
            responseQueue.add("Action: calculator\nArgs: {\"expression\": \"1+1\"}")
            responseQueue.add("Answer: done")
        }

        repeat(55) {
            runBlocking { strategy.execute("Calc") {} }
        }

        val log = strategy.getAuditLog()
        assertTrue(log.size <= 100)
    }

    // ==================== Step Callback ====================

    @Test
    fun stepCallback_receivesThoughtAndAnswerSteps() {
        setupRunMock()
        responseQueue.add("Answer: Hello!")

        val receivedSteps = mutableListOf<AgentStep>()
        runBlocking {
            strategy.execute("Say hello") { step ->
                receivedSteps.add(step)
            }
        }

        assertTrue(receivedSteps.isNotEmpty())
        assertTrue(receivedSteps.any { it.type == "thought" })
        assertTrue(receivedSteps.any { it.type == "answer" && it.content == "Hello!" })
    }

    @Test
    fun stepCallback_receivesActionAndObservationSteps() {
        setupRunMock()
        responseQueue.add("Action: calculator\nArgs: {\"expression\": \"3*7\"}")
        responseQueue.add("Answer: 21")

        val receivedSteps = mutableListOf<AgentStep>()
        runBlocking {
            strategy.execute("What is 3*7?") { step ->
                receivedSteps.add(step)
            }
        }

        assertTrue(receivedSteps.any { it.type == "action" && it.toolName == "calculator" })
        assertTrue(receivedSteps.any { it.type == "observation" })
        assertTrue(receivedSteps.any { it.type == "thinking_start" })
        assertTrue(receivedSteps.any { it.type == "thinking_end" })
    }

    // ==================== getToolManifest ====================

    @Test
    fun getToolManifest_containsBasicTools() {
        val manifest = strategy.getToolManifest()
        assertTrue(manifest.contains("calculator"))
        assertTrue(manifest.contains("timer"))
        assertTrue(manifest.contains("device_info"))
        assertTrue(manifest.contains("notepad"))
    }

    @Test
    fun getToolManifest_containsExtendedTools() {
        val manifest = strategy.getToolManifest()
        assertTrue(manifest.contains("screen_reader"))
        assertTrue(manifest.contains("screen_find"))
        assertTrue(manifest.contains("screen_action"))
        assertTrue(manifest.contains("app_launcher"))
        assertTrue(manifest.contains("notification_reader"))
        assertTrue(manifest.contains("sms_sender"))
        assertTrue(manifest.contains("phone_caller"))
        assertTrue(manifest.contains("contact_search"))
    }

    // ==================== History ====================

    @Test
    fun clearHistory_emptiesConversationHistory() {
        setupRunMock()
        responseQueue.add("Answer: hi")

        runBlocking { strategy.execute("hello") {} }
        assertFalse(strategy.getConversationHistory().isEmpty())

        strategy.clearHistory()
        assertTrue(strategy.getConversationHistory().isEmpty())
    }

    // ==================== Batch Token Generation ====================

    @Test
    fun generateTokensBatch_available_usesBatchInsteadOfSingleToken() {
        setupRunMock()
        every { mockService.generateTokensBatch(any()) } returns "Answer: batch result"

        val result = runBlocking { strategy.execute("Hello") {} }

        assertTrue(result.steps.any { it.type == "answer" && it.content == "batch result" })
        verify { mockService.generateTokensBatch(any()) }
        verify(exactly = 0) { mockService.generateOneToken() }
    }

    @Test
    fun generateTokensBatch_returnsNull_fallsBackToSingleToken() {
        setupRunMock()
        every { mockService.generateTokensBatch(any()) } returns null
        responseQueue.add("Answer: fallback result")

        val result = runBlocking { strategy.execute("Hello") {} }

        assertTrue(result.steps.any { it.type == "answer" })
        verify { mockService.generateTokensBatch(any()) }
        verify { mockService.generateOneToken() }
    }

    @Test
    fun cancelGeneration_calledOnCancel() {
        setupRunMock()
        every { mockService.generateTokensBatch(any()) } returns null

        val inferEntered = CountDownLatch(1)
        every { mockService.generateOneToken() } answers {
            inferEntered.countDown()
            Thread.sleep(30000)
            null
        }

        val runLatch = CountDownLatch(1)
        thread {
            runBlocking { strategy.execute("Do something") {} }
            runLatch.countDown()
        }

        assertTrue(inferEntered.await(5, TimeUnit.SECONDS))
        Thread.sleep(100)
        strategy.cancel()

        assertTrue(runLatch.await(5, TimeUnit.SECONDS))
        verify { mockService.cancelGeneration() }
    }

    // ==================== KV Cache Reuse ====================

    @Test
    fun kvCacheReuse_firstIteration_usesProcessPromptIncremental() {
        setupRunMock()
        every { mockService.generateTokensBatch(any()) } returns "Answer: done"

        runBlocking { strategy.execute("Hello") {} }

        verify(exactly = 1) { mockService.processPromptIncremental(any()) }
        verify(exactly = 0) { mockService.processPrompt(any()) }
    }

    @Test
    fun kvCacheReuse_secondIteration_usesProcessPrompt() {
        setupRunMock()
        responseQueue.add("Action: calculator\nArgs: {\"expression\": \"1+1\"}")
        responseQueue.add("Answer: 2")

        val result = runBlocking { strategy.execute("Calculate 1+1") {} }

        assertTrue(result.steps.any { it.type == "answer" })
        verify(exactly = 1) { mockService.processPromptIncremental(any()) }
        verify(atLeast = 1) { mockService.processPrompt(any()) }
    }

    @Test
    fun kvCacheReuse_afterTrim_fallsBackToIncremental() {
        setupRunMock()
        every { mockService.getContextUsage() } returns "900/1000"

        repeat(5) {
            responseQueue.add("Action: calculator\nArgs: {\"expression\": \"1+1\"}")
        }
        responseQueue.add("Answer: done")

        val result = runBlocking { strategy.execute("Calculate") {} }

        assertTrue(result.steps.any { it.type == "answer" })
        verify(atLeast = 2) { mockService.processPromptIncremental(any()) }
    }

    @Test
    fun kvCacheReuse_newSession_alwaysStartsWithIncremental() {
        setupRunMock()
        responseQueue.add("Answer: hi")
        runBlocking { strategy.execute("Hello") {} }

        strategy.clearHistory()

        setupRunMock()
        responseQueue.add("Answer: hello again")
        runBlocking { strategy.execute("Hi again") {} }

        verify(exactly = 2) { mockService.processPromptIncremental(any()) }
    }
}
