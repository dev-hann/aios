package com.agent.aios

import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
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
class AgentEngineTest {

    private lateinit var mockService: LlmService
    private lateinit var engine: AgentEngine
    private val responseQueue = LinkedList<String>()

    @Before
    fun setup() {
        mockkStatic(android.util.Log::class)
        every { android.util.Log.i(any(), any()) } returns 0
        every { android.util.Log.e(any(), any(), any()) } returns 0
        every { android.util.Log.d(any(), any()) } returns 0
        every { android.util.Log.w(any(), any<String>()) } returns 0

        mockService = mockk(relaxed = true)
        engine = AgentEngine(mockService)
        responseQueue.clear()
    }

    @After
    fun tearDown() {
        unmockkStatic(android.util.Log::class)
    }

    private fun parseResponse(response: String): Map<String, String> {
        val method = AgentEngine::class.java.getDeclaredMethod("parseResponse", String::class.java)
        method.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        return method.invoke(engine, response) as Map<String, String>
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

    // ==================== parseResponse ====================

    @Test
    fun parseResponse_actionWithArgs() {
        val parsed = parseResponse("Action: calculator\nArgs: {\"expression\": \"2+3\"}")
        assertEquals("calculator", parsed["action"])
        assertTrue(parsed["args"]!!.contains("expression"))
        assertTrue(parsed["args"]!!.contains("2+3"))
    }

    @Test
    fun parseResponse_actionWithoutArgs_returnsDefaultEmptyJson() {
        val parsed = parseResponse("Action: screen_tap")
        assertEquals("screen_tap", parsed["action"])
        assertEquals("{}", parsed["args"])
    }

    @Test
    fun parseResponse_answer() {
        val parsed = parseResponse("Answer: The result is 42")
        assertEquals("The result is 42", parsed["answer"])
        assertNull(parsed["action"])
    }

    @Test
    fun parseResponse_plainText_returnsEmptyMap() {
        val parsed = parseResponse("Just some random text without action or answer")
        assertTrue(parsed.isEmpty())
    }

    @Test
    fun parseResponse_caseInsensitiveAction() {
        val parsed = parseResponse("ACTION: timer\nARGS: {\"seconds\": 5}")
        assertEquals("timer", parsed["action"])
    }

    @Test
    fun parseResponse_caseInsensitiveAnswer() {
        val parsed = parseResponse("ANSWER: yes it works")
        assertEquals("yes it works", parsed["answer"])
    }

    @Test
    fun parseResponse_mixedCaseAction() {
        val parsed = parseResponse("AcTiOn: device_info\nArGs: {}")
        assertEquals("device_info", parsed["action"])
    }

    @Test
    fun parseResponse_multilineActionWithComplexJsonArgs() {
        val input = """
            Action: screen_action
            Args: {"action": "tap", "x": 100, "y": 200}
        """.trimIndent()
        val parsed = parseResponse(input)
        assertEquals("screen_action", parsed["action"])
        assertNotNull(parsed["args"])
        assertTrue(parsed["args"]!!.contains("tap"))
        assertTrue(parsed["args"]!!.contains("100"))
        assertTrue(parsed["args"]!!.contains("200"))
    }

    @Test
    fun parseResponse_nestedJsonInArgs_capturesUpToFirstClosingBrace() {
        val input = "Action: screen_action\nArgs: {\"action\": \"type\", \"target\": {\"x\": 100}}"
        val parsed = parseResponse(input)
        assertEquals("screen_action", parsed["action"])
        val args = parsed["args"]
        assertNotNull(args)
        assertFalse(args!!.endsWith("}}"))
        assertTrue(args.contains("type"))
    }

    @Test
    fun parseResponse_whitespaceAroundColon() {
        val parsed = parseResponse("Action :  calculator  \n Args : {\"expression\": \"1+1\"}")
        assertEquals("calculator", parsed["action"])
        assertEquals("{\"expression\": \"1+1\"}", parsed["args"])
    }

    @Test
    fun parseResponse_actionAndArgsOnSameLine() {
        val parsed = parseResponse("Action: calculator Args: {\"expression\": \"2+3\"}")
        assertEquals("calculator", parsed["action"])
    }

    @Test
    fun parseResponse_emptyString_returnsEmpty() {
        val parsed = parseResponse("")
        assertTrue(parsed.isEmpty())
    }

    @Test
    fun parseResponse_whitespaceOnly_returnsEmpty() {
        val parsed = parseResponse("   \n\t  ")
        assertTrue(parsed.isEmpty())
    }

    @Test
    fun parseResponse_answerWithMultilineContent() {
        val input = "Answer: First line\nSecond line\nThird line"
        val parsed = parseResponse(input)
        assertEquals("First line\nSecond line\nThird line", parsed["answer"])
    }

    // ==================== classifyRisk ====================

    @Test
    fun classifyRisk_calculator_isSafe() {
        assertEquals(ToolRisk.SAFE, engine.classifyRisk("calculator", "{}"))
    }

    @Test
    fun classifyRisk_timer_isSafe() {
        assertEquals(ToolRisk.SAFE, engine.classifyRisk("timer", "{}"))
    }

    @Test
    fun classifyRisk_deviceInfo_isSafe() {
        assertEquals(ToolRisk.SAFE, engine.classifyRisk("device_info", "{}"))
    }

    @Test
    fun classifyRisk_notepad_isSafe() {
        assertEquals(ToolRisk.SAFE, engine.classifyRisk("notepad", "{}"))
    }

    @Test
    fun classifyRisk_screenReader_isSafe() {
        assertEquals(ToolRisk.SAFE, engine.classifyRisk("screen_reader", "{}"))
    }

    @Test
    fun classifyRisk_screenFind_isSafe() {
        assertEquals(ToolRisk.SAFE, engine.classifyRisk("screen_find", "{}"))
    }

    @Test
    fun classifyRisk_notificationReader_isSafe() {
        assertEquals(ToolRisk.SAFE, engine.classifyRisk("notification_reader", "{}"))
    }

    @Test
    fun classifyRisk_contactSearch_isSafe() {
        assertEquals(ToolRisk.SAFE, engine.classifyRisk("contact_search", "{}"))
    }

    // --- sms_sender ---

    @Test
    fun classifyRisk_smsSender_send_isCritical() {
        assertEquals(ToolRisk.CRITICAL, engine.classifyRisk("sms_sender", "{\"action\": \"send\"}"))
    }

    @Test
    fun classifyRisk_smsSender_read_isHigh() {
        assertEquals(ToolRisk.HIGH, engine.classifyRisk("sms_sender", "{\"action\": \"read\"}"))
    }

    @Test
    fun classifyRisk_smsSender_unknownAction_isHigh() {
        assertEquals(ToolRisk.HIGH, engine.classifyRisk("sms_sender", "{\"action\": \"unknown\"}"))
    }

    // --- phone_caller ---

    @Test
    fun classifyRisk_phoneCaller_call_isCritical() {
        assertEquals(ToolRisk.CRITICAL, engine.classifyRisk("phone_caller", "{\"action\": \"call\"}"))
    }

    @Test
    fun classifyRisk_phoneCaller_dial_isHigh() {
        assertEquals(ToolRisk.HIGH, engine.classifyRisk("phone_caller", "{\"action\": \"dial\"}"))
    }

    @Test
    fun classifyRisk_phoneCaller_unknownAction_isHigh() {
        assertEquals(ToolRisk.HIGH, engine.classifyRisk("phone_caller", "{\"action\": \"unknown\"}"))
    }

    // --- screen_action ---

    @Test
    fun classifyRisk_screenAction_tap_isHigh() {
        assertEquals(ToolRisk.HIGH, engine.classifyRisk("screen_action", "{\"action\": \"tap\"}"))
    }

    @Test
    fun classifyRisk_screenAction_longClick_isHigh() {
        assertEquals(ToolRisk.HIGH, engine.classifyRisk("screen_action", "{\"action\": \"long_click\"}"))
    }

    @Test
    fun classifyRisk_screenAction_scroll_isHigh() {
        assertEquals(ToolRisk.HIGH, engine.classifyRisk("screen_action", "{\"action\": \"scroll\"}"))
    }

    @Test
    fun classifyRisk_screenAction_swipe_isHigh() {
        assertEquals(ToolRisk.HIGH, engine.classifyRisk("screen_action", "{\"action\": \"swipe\"}"))
    }

    @Test
    fun classifyRisk_screenAction_type_normalContent_isHigh() {
        assertEquals(ToolRisk.HIGH, engine.classifyRisk("screen_action", "{\"action\": \"type\", \"content\": \"hello\"}"))
    }

    @Test
    fun classifyRisk_screenAction_global_isLow() {
        assertEquals(ToolRisk.LOW, engine.classifyRisk("screen_action", "{\"action\": \"global\"}"))
    }

    @Test
    fun classifyRisk_screenAction_unknownAction_isHigh() {
        assertEquals(ToolRisk.HIGH, engine.classifyRisk("screen_action", "{\"action\": \"unknown\"}"))
    }

    // --- screen_action type with sensitive keywords (CRITICAL) ---

    @Test
    fun classifyRisk_screenAction_typePassword_isCritical() {
        assertEquals(ToolRisk.CRITICAL, engine.classifyRisk("screen_action", "{\"action\": \"type\", \"content\": \"enter your password\"}"))
    }

    @Test
    fun classifyRisk_screenAction_typePin_isCritical() {
        assertEquals(ToolRisk.CRITICAL, engine.classifyRisk("screen_action", "{\"action\": \"type\", \"content\": \"enter your pin\"}"))
    }

    @Test
    fun classifyRisk_screenAction_typePasscode_isCritical() {
        assertEquals(ToolRisk.CRITICAL, engine.classifyRisk("screen_action", "{\"action\": \"type\", \"content\": \"passcode entry\"}"))
    }

    @Test
    fun classifyRisk_screenAction_typeSsn_isCritical() {
        assertEquals(ToolRisk.CRITICAL, engine.classifyRisk("screen_action", "{\"action\": \"type\", \"content\": \"social security number\"}"))
    }

    @Test
    fun classifyRisk_screenAction_typeSocialSecurity_isCritical() {
        assertEquals(ToolRisk.CRITICAL, engine.classifyRisk("screen_action", "{\"action\": \"type\", \"content\": \"my social security\"}"))
    }

    @Test
    fun classifyRisk_screenAction_typeCreditCard_isCritical() {
        assertEquals(ToolRisk.CRITICAL, engine.classifyRisk("screen_action", "{\"action\": \"type\", \"content\": \"credit card number\"}"))
    }

    @Test
    fun classifyRisk_screenAction_typeCvv_isCritical() {
        assertEquals(ToolRisk.CRITICAL, engine.classifyRisk("screen_action", "{\"action\": \"type\", \"content\": \"cvv code\"}"))
    }

    @Test
    fun classifyRisk_screenAction_typeOtp_isCritical() {
        assertEquals(ToolRisk.CRITICAL, engine.classifyRisk("screen_action", "{\"action\": \"type\", \"content\": \"otp verification\"}"))
    }

    // --- app_launcher ---

    @Test
    fun classifyRisk_appLauncher_openApp_isHigh() {
        assertEquals(ToolRisk.HIGH, engine.classifyRisk("app_launcher", "{\"action\": \"open_app\"}"))
    }

    @Test
    fun classifyRisk_appLauncher_openUrl_isHigh() {
        assertEquals(ToolRisk.HIGH, engine.classifyRisk("app_launcher", "{\"action\": \"open_url\"}"))
    }

    @Test
    fun classifyRisk_appLauncher_openSettings_isLow() {
        assertEquals(ToolRisk.LOW, engine.classifyRisk("app_launcher", "{\"action\": \"open_settings\"}"))
    }

    @Test
    fun classifyRisk_appLauncher_listApps_isLow() {
        assertEquals(ToolRisk.LOW, engine.classifyRisk("app_launcher", "{\"action\": \"list_apps\"}"))
    }

    @Test
    fun classifyRisk_appLauncher_unknownAction_isLow() {
        assertEquals(ToolRisk.LOW, engine.classifyRisk("app_launcher", "{\"action\": \"unknown\"}"))
    }

    // --- unknown / invalid ---

    @Test
    fun classifyRisk_unknownTool_isHigh() {
        assertEquals(ToolRisk.HIGH, engine.classifyRisk("nonexistent_tool", "{}"))
    }

    @Test
    fun classifyRisk_invalidJson_defaultsActionToEmpty() {
        assertEquals(ToolRisk.SAFE, engine.classifyRisk("calculator", "not json"))
        assertEquals(ToolRisk.HIGH, engine.classifyRisk("screen_action", "not json"))
        assertEquals(ToolRisk.LOW, engine.classifyRisk("app_launcher", "not json"))
    }

    @Test
    fun classifyRisk_emptyArgs_defaultsActionToEmpty() {
        assertEquals(ToolRisk.SAFE, engine.classifyRisk("calculator", ""))
        assertEquals(ToolRisk.HIGH, engine.classifyRisk("screen_action", ""))
        assertEquals(ToolRisk.LOW, engine.classifyRisk("app_launcher", ""))
    }

    @Test
    fun classifyRisk_caseInsensitiveAction() {
        assertEquals(ToolRisk.CRITICAL, engine.classifyRisk("sms_sender", "{\"action\": \"SEND\"}"))
        assertEquals(ToolRisk.CRITICAL, engine.classifyRisk("phone_caller", "{\"action\": \"CALL\"}"))
    }

    // ==================== Confirmation Flow ====================

    @Test
    fun safeTool_executesWithoutConfirmation() {
        setupRunMock()
        responseQueue.add("Action: calculator\nArgs: {\"expression\": \"2+3\"}")

        val steps = engine.run("Calculate 2+3")

        assertFalse(steps.any { it.type == "confirmation_required" })
        assertTrue(steps.any { it.type == "action" && it.toolName == "calculator" })
        assertTrue(steps.any { it.type == "observation" })
    }

    @Test
    fun highRiskTool_approved_executes() {
        setupRunMock()
        responseQueue.add("Action: screen_action\nArgs: {\"action\": \"tap\", \"x\": 100, \"y\": 200}")

        val callbackSteps = mutableListOf<AgentStep>()
        engine.setStepCallback { callbackSteps.add(it) }

        val steps = mutableListOf<AgentStep>()
        val latch = CountDownLatch(1)

        thread {
            steps.addAll(engine.run("Tap the screen"))
            latch.countDown()
        }

        Thread.sleep(500)
        assertTrue(callbackSteps.any { it.type == "confirmation_required" })
        engine.resolveConfirmation(true)

        assertTrue(latch.await(5, TimeUnit.SECONDS))

        assertTrue(steps.any { it.type == "observation" })
        val obs = steps.find { it.type == "observation" }
        assertNotNull(obs)
        assertNotEquals("Action cancelled by user", obs!!.toolResult)
    }

    @Test
    fun highRiskTool_rejected_returnsCancelled() {
        setupRunMock()
        responseQueue.add("Action: screen_action\nArgs: {\"action\": \"tap\", \"x\": 100, \"y\": 200}")

        val steps = mutableListOf<AgentStep>()
        val latch = CountDownLatch(1)

        thread {
            steps.addAll(engine.run("Tap the screen"))
            latch.countDown()
        }

        Thread.sleep(500)
        engine.resolveConfirmation(false)

        assertTrue(latch.await(5, TimeUnit.SECONDS))

        val obs = steps.find { it.type == "observation" }
        assertNotNull(obs)
        assertEquals("Action cancelled by user", obs!!.toolResult)
    }

    @Test
    fun criticalTool_requiresConfirmation() {
        setupRunMock()
        responseQueue.add("Action: sms_sender\nArgs: {\"action\": \"send\", \"to\": \"1234\", \"body\": \"hi\"}")

        val callbackSteps = mutableListOf<AgentStep>()
        engine.setStepCallback { callbackSteps.add(it) }

        val steps = mutableListOf<AgentStep>()
        val latch = CountDownLatch(1)

        thread {
            steps.addAll(engine.run("Send a text"))
            latch.countDown()
        }

        Thread.sleep(500)

        val confirmationStep = callbackSteps.find { it.type == "confirmation_required" }
        assertNotNull(confirmationStep)
        assertEquals("CRITICAL", confirmationStep!!.riskLevel)
        assertEquals("sms_sender", confirmationStep.toolName)

        engine.resolveConfirmation(false)
        assertTrue(latch.await(5, TimeUnit.SECONDS))
    }

    @Test
    fun cancelDuringConfirmation_resolves() {
        setupRunMock()
        responseQueue.add("Action: screen_action\nArgs: {\"action\": \"tap\", \"x\": 50, \"y\": 50}")

        val callbackSteps = mutableListOf<AgentStep>()
        engine.setStepCallback { callbackSteps.add(it) }

        val steps = mutableListOf<AgentStep>()
        val latch = CountDownLatch(1)

        thread {
            steps.addAll(engine.run("Tap something"))
            latch.countDown()
        }

        Thread.sleep(500)

        assertTrue(callbackSteps.any { it.type == "confirmation_required" })

        engine.cancel()
        assertTrue(latch.await(5, TimeUnit.SECONDS))

        val obs = steps.find { it.type == "observation" }
        assertNotNull(obs)
        assertEquals("Action cancelled by user", obs!!.toolResult)
    }

    // ==================== Thread Safety ====================

    @Test
    fun cancelDuringInference_interruptedExceptionCaught() {
        val inferEntered = CountDownLatch(1)

        every { mockService.processPrompt(any()) } returns 0

        every { mockService.generateOneToken() } answers {
            inferEntered.countDown()
            Thread.sleep(30000)
            null
        }

        every { mockService.formatChat(any(), any()) } returns "formatted"
        every { mockService.getContextUsage() } returns "100/1000"

        val steps = mutableListOf<AgentStep>()
        val runLatch = CountDownLatch(1)

        thread {
            steps.addAll(engine.run("Do something"))
            runLatch.countDown()
        }

        assertTrue(inferEntered.await(5, TimeUnit.SECONDS))
        Thread.sleep(100)
        engine.cancel()

        assertTrue(runLatch.await(5, TimeUnit.SECONDS))
        assertTrue(steps.any { it.type == "answer" && it.content == "Task cancelled." })
    }

    @Test
    fun concurrentResolveConfirmation_doesNotCrash() {
        var error: Throwable? = null
        val threads = (1..10).map {
            thread {
                try {
                    engine.resolveConfirmation(it % 2 == 0)
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
    fun run_emptyPrompt_stillProcesses() {
        setupRunMock()
        responseQueue.add("Answer: I'm ready to help!")

        val steps = engine.run("")

        assertTrue(steps.any { it.type == "thought" })
        assertTrue(steps.any { it.type == "answer" })
    }

    @Test
    fun run_toolNotFound_returnsErrorListingAvailableTools() {
        setupRunMock()
        responseQueue.add("Action: nonexistent_tool\nArgs: {}")

        val steps = mutableListOf<AgentStep>()
        val latch = CountDownLatch(1)

        thread {
            steps.addAll(engine.run("Use a fake tool"))
            latch.countDown()
        }

        Thread.sleep(500)
        engine.resolveConfirmation(true)

        assertTrue(latch.await(5, TimeUnit.SECONDS))

        val obs = steps.find { it.type == "observation" }
        assertNotNull(obs)
        assertTrue(obs!!.toolResult.contains("Unknown tool 'nonexistent_tool'"))
        assertTrue(obs.toolResult.contains("Available:"))
        assertTrue(obs.toolResult.contains("calculator"))
    }

    @Test
    fun run_iterationLimitReached_returnsCouldNotComplete() {
        setupRunMock()
        repeat(20) {
            responseQueue.add("Action: calculator\nArgs: {\"expression\": \"1+1\"}")
        }

        val steps = engine.run("Loop forever", maxIterations = 3)

        val answerStep = steps.find { it.type == "answer" }
        assertNotNull(answerStep)
        assertTrue(answerStep!!.content.contains("couldn't complete"))
        assertTrue(answerStep.content.contains("iteration limit"))
    }

    @Test
    fun run_plainTextResponse_breaksAsDirectAnswer() {
        setupRunMock()
        responseQueue.add("This is just a plain text response without any action or answer prefix.")

        val steps = engine.run("Tell me something")

        val answerStep = steps.find { it.type == "answer" }
        assertNotNull(answerStep)
        assertEquals("This is just a plain text response without any action or answer prefix.", answerStep!!.content)
    }

    @Test
    fun run_multipleToolCallsThenAnswer() {
        setupRunMock()
        responseQueue.add("Action: calculator\nArgs: {\"expression\": \"2+3\"}")
        responseQueue.add("Action: calculator\nArgs: {\"expression\": \"10*5\"}")
        responseQueue.add("Answer: The results are 5 and 50.")

        val steps = engine.run("Calculate 2+3 and 10*5")

        val actionSteps = steps.filter { it.type == "action" }
        assertEquals(2, actionSteps.size)
        assertEquals("calculator", actionSteps[0].toolName)
        assertEquals("calculator", actionSteps[1].toolName)

        val answerStep = steps.find { it.type == "answer" }
        assertNotNull(answerStep)
        assertTrue(answerStep!!.content.contains("5"))
        assertTrue(answerStep.content.contains("50"))
    }

    // ==================== Audit Log ====================

    @Test
    fun auditLog_recordsSafeToolExecution() {
        setupRunMock()
        responseQueue.add("Action: calculator\nArgs: {\"expression\": \"2+3\"}")

        engine.run("Calculate 2+3")

        val log = engine.getAuditLog()
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

        val steps = mutableListOf<AgentStep>()
        val latch = CountDownLatch(1)

        thread {
            steps.addAll(engine.run("Tap something"))
            latch.countDown()
        }

        Thread.sleep(500)
        engine.resolveConfirmation(false)
        assertTrue(latch.await(5, TimeUnit.SECONDS))

        val log = engine.getAuditLog()
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
            engine.run("Calc")
        }

        val log = engine.getAuditLog()
        assertTrue(log.size <= 100)
    }

    // ==================== Step Callback ====================

    @Test
    fun stepCallback_receivesThoughtAndAnswerSteps() {
        setupRunMock()
        responseQueue.add("Answer: Hello!")

        val receivedSteps = mutableListOf<AgentStep>()
        engine.setStepCallback { receivedSteps.add(it) }

        engine.run("Say hello")

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
        engine.setStepCallback { receivedSteps.add(it) }

        engine.run("What is 3*7?")

        assertTrue(receivedSteps.any { it.type == "action" && it.toolName == "calculator" })
        assertTrue(receivedSteps.any { it.type == "observation" })
        assertTrue(receivedSteps.any { it.type == "thinking_start" })
        assertTrue(receivedSteps.any { it.type == "thinking_end" })
    }

    @Test
    fun stepCallback_null_doesNotCrash() {
        setupRunMock()
        responseQueue.add("Answer: test")

        engine.setStepCallback(null)

        engine.run("test")

        val steps = engine.run("test again")
        assertTrue(steps.any { it.type == "answer" })
    }

    // ==================== getToolManifest ====================

    @Test
    fun getToolManifest_containsBasicTools() {
        val manifest = engine.getToolManifest()
        assertTrue(manifest.contains("calculator"))
        assertTrue(manifest.contains("timer"))
        assertTrue(manifest.contains("device_info"))
        assertTrue(manifest.contains("notepad"))
    }

    @Test
    fun getToolManifest_containsExtendedTools() {
        val manifest = engine.getToolManifest()
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

        engine.run("hello")
        assertFalse(engine.getConversationHistory().isEmpty())

        engine.clearHistory()
        assertTrue(engine.getConversationHistory().isEmpty())
    }
}
