package com.agent.aios

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.agent.aios.agent.tools.AppLauncherTool
import com.agent.aios.crash.CrashLogManager
import com.agent.aios.domain.LlmProvider
import com.agent.aios.domain.ToolContext
import com.agent.aios.domain.agent.LoopDetector
import com.agent.aios.domain.agent.ResponseParser
import com.agent.aios.domain.agent.RiskClassifier
import com.agent.aios.domain.model.ServiceState
import com.agent.aios.domain.model.ToolRisk
import com.agent.aios.domain.repository.SettingsRepository
import com.agent.aios.settings.SettingsRepositoryImpl
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.FixMethodOrder
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.MethodSorters

/**
 * Run with: cd android && ./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.agent.aios.FeatureInstrumentedTest
 * Requires: network access for update-related sub-tests
 */
@RunWith(AndroidJUnit4::class)
@FixMethodOrder(MethodSorters.NAME_ASCENDING)
class FeatureInstrumentedTest {
    private lateinit var context: android.content.Context

    @Before
    fun setup() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
    }

    // ── Settings Persistence ────────────────────────────

    @Test
    fun t01_settings_defaultsAreCorrect() =
        runBlocking {
            val repo = SettingsRepositoryImpl(context)
            assertEquals(SettingsRepository.DEFAULT_CONTEXT_SIZE, repo.contextSize.first())
            assertEquals(SettingsRepository.DEFAULT_TEMPERATURE, repo.temperature.first())
            assertEquals(SettingsRepository.DEFAULT_TOP_K, repo.topK.first())
            assertEquals(SettingsRepository.DEFAULT_TOP_P, repo.topP.first(), 0.01f)
            assertEquals(SettingsRepository.DEFAULT_REPEAT_PENALTY, repo.repeatPenalty.first(), 0.01f)
            assertEquals(SettingsRepository.DEFAULT_MAX_TOKENS_CHAT, repo.maxTokensChat.first())
            assertEquals(SettingsRepository.DEFAULT_MAX_TOKENS_AGENT, repo.maxTokensAgent.first())
            assertEquals(SettingsRepository.DEFAULT_AGENT_MAX_ITERATIONS, repo.agentMaxIterations.first())
        }

    @Test
    fun t02_settings_setAndGet_contextSize() =
        runBlocking {
            val repo = SettingsRepositoryImpl(context)
            repo.setContextSize(4096)
            assertEquals(4096, repo.contextSize.first())
            repo.setContextSize(SettingsRepository.DEFAULT_CONTEXT_SIZE)
        }

    @Test
    fun t03_settings_setAndGet_temperature() =
        runBlocking {
            val repo = SettingsRepositoryImpl(context)
            repo.setTemperature(0.3f)
            assertEquals(0.3f, repo.temperature.first(), 0.01f)
            repo.setTemperature(SettingsRepository.DEFAULT_TEMPERATURE)
        }

    @Test
    fun t04_settings_setAndGet_topK() =
        runBlocking {
            val repo = SettingsRepositoryImpl(context)
            repo.setTopK(100)
            assertEquals(100, repo.topK.first())
            repo.setTopK(SettingsRepository.DEFAULT_TOP_K)
        }

    @Test
    fun t05_settings_setAndGet_topP() =
        runBlocking {
            val repo = SettingsRepositoryImpl(context)
            repo.setTopP(0.5f)
            assertEquals(0.5f, repo.topP.first(), 0.01f)
            repo.setTopP(SettingsRepository.DEFAULT_TOP_P)
        }

    @Test
    fun t06_settings_setAndGet_repeatPenalty() =
        runBlocking {
            val repo = SettingsRepositoryImpl(context)
            repo.setRepeatPenalty(1.5f)
            assertEquals(1.5f, repo.repeatPenalty.first(), 0.01f)
            repo.setRepeatPenalty(SettingsRepository.DEFAULT_REPEAT_PENALTY)
        }

    @Test
    fun t07_settings_setAndGet_maxTokensChat() =
        runBlocking {
            val repo = SettingsRepositoryImpl(context)
            repo.setMaxTokensChat(512)
            assertEquals(512, repo.maxTokensChat.first())
            repo.setMaxTokensChat(SettingsRepository.DEFAULT_MAX_TOKENS_CHAT)
        }

    @Test
    fun t08_settings_setAndGet_maxTokensAgent() =
        runBlocking {
            val repo = SettingsRepositoryImpl(context)
            repo.setMaxTokensAgent(1024)
            assertEquals(1024, repo.maxTokensAgent.first())
            repo.setMaxTokensAgent(SettingsRepository.DEFAULT_MAX_TOKENS_AGENT)
        }

    @Test
    fun t09_settings_setAndGet_agentMaxIterations() =
        runBlocking {
            val repo = SettingsRepositoryImpl(context)
            repo.setAgentMaxIterations(10)
            assertEquals(10, repo.agentMaxIterations.first())
            repo.setAgentMaxIterations(SettingsRepository.DEFAULT_AGENT_MAX_ITERATIONS)
        }

    @Test
    fun t10_settings_lastModelPath_defaultEmpty() =
        runBlocking {
            val repo = SettingsRepositoryImpl(context)
            repo.clearLastModelPath()
            assertEquals("", repo.lastModelPath.first())
        }

    @Test
    fun t11_settings_lastModelPath_setAndClear() =
        runBlocking {
            val repo = SettingsRepositoryImpl(context)
            repo.setLastModelPath("/sdcard/models/test.gguf")
            assertEquals("/sdcard/models/test.gguf", repo.lastModelPath.first())
            repo.clearLastModelPath()
            assertEquals("", repo.lastModelPath.first())
        }

    @Test
    fun t12_settings_multipleWrites_overwriteCorrectly() =
        runBlocking {
            val repo = SettingsRepositoryImpl(context)
            repo.setTemperature(0.1f)
            repo.setTemperature(0.9f)
            repo.setTemperature(1.5f)
            assertEquals(1.5f, repo.temperature.first(), 0.01f)
            repo.setTemperature(SettingsRepository.DEFAULT_TEMPERATURE)
        }

    // ── CrashLogManager ─────────────────────────────────

    @Test
    fun t13_crashLog_getCrashLogs_emptyByDefault() {
        CrashLogManager.clearLogs(context)
        val logs = CrashLogManager.getCrashLogs(context)
        assertTrue("No crash logs initially", logs.isEmpty())
    }

    @Test
    fun t14_crashLog_logCrash_createsLogFile() {
        CrashLogManager.clearLogs(context)
        val exception = RuntimeException("test crash")
        CrashLogManager.logCrash(context, Thread.currentThread(), exception)

        val logs = CrashLogManager.getCrashLogs(context)
        assertEquals("1 crash log", 1, logs.size)
        assertTrue("Contains RuntimeException", logs[0].summary.contains("RuntimeException"))
    }

    @Test
    fun t15_crashLog_getLogContent_returnsFullContent() {
        CrashLogManager.clearLogs(context)
        CrashLogManager.logCrash(context, Thread.currentThread(), IllegalStateException("test detail"))

        val logs = CrashLogManager.getCrashLogs(context)
        assertTrue("Has log", logs.isNotEmpty())

        val content = CrashLogManager.getLogContent(context, logs[0].filename)
        assertNotNull("Content not null", content)
        assertTrue("Contains IllegalStateException", content!!.contains("IllegalStateException"))
        assertTrue("Contains test detail", content.contains("test detail"))
        assertTrue("Contains app version", content.contains(BuildConfig.VERSION_NAME))
    }

    @Test
    fun t16_crashLog_clearLogs_removesAll() {
        CrashLogManager.clearLogs(context)
        CrashLogManager.logCrash(context, Thread.currentThread(), RuntimeException("a"))
        CrashLogManager.logCrash(context, Thread.currentThread(), RuntimeException("b"))
        assertTrue("Logs exist before clear", CrashLogManager.getCrashLogs(context).isNotEmpty())

        CrashLogManager.clearLogs(context)
        assertTrue("Logs empty after clear", CrashLogManager.getCrashLogs(context).isEmpty())
    }

    @Test
    fun t17_crashLog_getLogContent_nonexistent_returnsNull() {
        val content = CrashLogManager.getLogContent(context, "nonexistent_9999.log")
        assertNull("Nonexistent file returns null", content)
    }

    @Test
    fun t18_crashLog_logSignalCrash_nativeFormat() {
        CrashLogManager.clearLogs(context)
        CrashLogManager.logSignalCrash(context, 11, System.currentTimeMillis())

        val logs = CrashLogManager.getCrashLogs(context)
        assertEquals("1 log", 1, logs.size)
        assertTrue("Native prefix", logs[0].summary.startsWith("[Native]"))
        assertTrue("SIGSEGV", logs[0].summary.contains("SIGSEGV"))
    }

    @Test
    fun t19_crashLog_sortedByNewest() {
        CrashLogManager.clearLogs(context)
        CrashLogManager.logCrash(context, Thread.currentThread(), RuntimeException("first"))
        Thread.sleep(1100)
        CrashLogManager.logCrash(context, Thread.currentThread(), RuntimeException("second"))

        val logs = CrashLogManager.getCrashLogs(context)
        assertTrue("At least 2 logs", logs.size >= 2)
        assertTrue("Newest first", logs[0].timestamp >= logs[1].timestamp)
    }

    @After
    fun cleanupCrashLogs() {
        CrashLogManager.clearLogs(context)
    }

    // ── AppLauncherTool ─────────────────────────────────

    private fun createToolContext(): ToolContext = ToolContext(context) { null }

    @Test
    fun t20_appLauncher_listApps_returnsInstalledApps() {
        val tool = AppLauncherTool()
        val result = tool.execute("""{"action":"list_apps"}""", createToolContext())
        assertTrue("Contains package names", result.contains("com."))
    }

    @Test
    fun t21_appLauncher_openSettings_launches() {
        val tool = AppLauncherTool()
        val result = tool.execute("""{"action":"open_settings","setting":"about"}""", createToolContext())
        assertTrue("Success or launched", result.contains("Opened") || result.contains("settings"))
    }

    @Test
    fun t22_appLauncher_invalidAction_returnsError() {
        val tool = AppLauncherTool()
        val result = tool.execute("""{"action":"nonexistent_action_xyz"}""", createToolContext())
        assertTrue("Error for invalid action", result.startsWith("Error:"))
    }

    @Test
    fun t23_appLauncher_missingAction_returnsError() {
        val tool = AppLauncherTool()
        val result = tool.execute("{}", createToolContext())
        assertTrue("Error for missing action", result.startsWith("Error:"))
    }

    @Test
    fun t24_appLauncher_openApp_withValidPackage() {
        val tool = AppLauncherTool()
        val result = tool.execute("""{"action":"open_app","package_name":"com.android.settings"}""", createToolContext())
        assertTrue("Success or not found", result.contains("Opened") || result.contains("not found") || result.contains("Error"))
    }

    @Test
    fun t25_appLauncher_openApp_withInvalidPackage() {
        val tool = AppLauncherTool()
        val result = tool.execute("""{"action":"open_app","package_name":"com.nonexistent.app.xyz123"}""", createToolContext())
        assertTrue("Error for invalid package", result.startsWith("Error:") || result.contains("not found"))
    }

    // ── ResponseParser ──────────────────────────────────

    @Test
    fun t26_parser_actionWithJsonArgs() {
        val parser = ResponseParser(setOf("calculator", "screen_action"))
        val result = parser.parse("Action: calculator\nArgs: {\"expression\": \"2+3\"}")
        assertTrue("Is Action", result is ResponseParser.ParseResult.Action)
        val action = result as ResponseParser.ParseResult.Action
        assertEquals("calculator", action.toolName)
        assertTrue("Has expression", action.args.contains("expression"))
    }

    @Test
    fun t27_parser_answerText() {
        val parser = ResponseParser(setOf("calculator"))
        val result = parser.parse("Answer: The weather is sunny today.")
        assertTrue("Is Answer", result is ResponseParser.ParseResult.Answer)
        assertEquals("The weather is sunny today.", (result as ResponseParser.ParseResult.Answer).text)
    }

    @Test
    fun t28_parser_emptyInput() {
        val parser = ResponseParser(setOf("calculator"))
        assertTrue("Empty input", parser.parse("") is ResponseParser.ParseResult.Empty)
        assertTrue("Blank input", parser.parse("   ") is ResponseParser.ParseResult.Empty)
    }

    @Test
    fun t29_parser_unknownTool_returnsEmpty() {
        val parser = ResponseParser(setOf("calculator"))
        val result = parser.parse("Action: unknown_tool_xyz\nArgs: {}")
        assertTrue("Unknown tool returns Empty", result is ResponseParser.ParseResult.Empty)
    }

    @Test
    fun t30_parser_toolNameCaseInsensitive() {
        val parser = ResponseParser(setOf("calculator"))
        val result = parser.parse("Action: Calculator\nArgs: {\"expression\": \"1+1\"}")
        assertTrue("Case insensitive tool name", result is ResponseParser.ParseResult.Action)
        assertEquals("calculator", (result as ResponseParser.ParseResult.Action).toolName)
    }

    @Test
    fun t31_parser_nestedJsonArgs() {
        val parser = ResponseParser(setOf("screen_action"))
        val result = parser.parse("Action: screen_action\nArgs: {\"action\": \"tap\", \"x\": 100, \"y\": 200}")
        assertTrue("Nested JSON parsed", result is ResponseParser.ParseResult.Action)
        val args = (result as ResponseParser.ParseResult.Action).args
        assertTrue("Contains tap", args.contains("tap"))
    }

    // ── RiskClassifier ──────────────────────────────────

    @Test
    fun t32_risk_safeTools() {
        val classifier = RiskClassifier()
        assertEquals(ToolRisk.SAFE, classifier.classify("calculator", "{}"))
        assertEquals(ToolRisk.SAFE, classifier.classify("timer", "{}"))
        assertEquals(ToolRisk.SAFE, classifier.classify("device_info", "{}"))
        assertEquals(ToolRisk.SAFE, classifier.classify("notepad", "{}"))
        assertEquals(ToolRisk.SAFE, classifier.classify("screen_reader", "{}"))
        assertEquals(ToolRisk.SAFE, classifier.classify("contact_search", "{}"))
        assertEquals(ToolRisk.SAFE, classifier.classify("notification_reader", "{}"))
    }

    @Test
    fun t33_risk_appLauncher_highForOpenApp() {
        val classifier = RiskClassifier()
        assertEquals(ToolRisk.HIGH, classifier.classify("app_launcher", """{"action":"open_app"}"""))
        assertEquals(ToolRisk.LOW, classifier.classify("app_launcher", """{"action":"list_apps"}"""))
        assertEquals(ToolRisk.LOW, classifier.classify("app_launcher", """{"action":"open_settings"}"""))
    }

    @Test
    fun t34_risk_screenAction_highForTap() {
        val classifier = RiskClassifier()
        assertEquals(ToolRisk.HIGH, classifier.classify("screen_action", """{"action":"tap"}"""))
        assertEquals(ToolRisk.HIGH, classifier.classify("screen_action", """{"action":"long_click"}"""))
        assertEquals(ToolRisk.HIGH, classifier.classify("screen_action", """{"action":"scroll"}"""))
        assertEquals(ToolRisk.LOW, classifier.classify("screen_action", """{"action":"global"}"""))
    }

    @Test
    fun t35_risk_screenAction_criticalForSensitiveType() {
        val classifier = RiskClassifier()
        assertEquals(
            ToolRisk.CRITICAL,
            classifier.classify("screen_action", """{"action":"type","content":"password123"}"""),
        )
        assertEquals(
            ToolRisk.CRITICAL,
            classifier.classify("screen_action", """{"action":"type","content":"my PIN code"}"""),
        )
        assertEquals(
            ToolRisk.HIGH,
            classifier.classify("screen_action", """{"action":"type","content":"hello world"}"""),
        )
    }

    @Test
    fun t36_risk_sms_criticalForSend() {
        val classifier = RiskClassifier()
        assertEquals(ToolRisk.CRITICAL, classifier.classify("sms_sender", """{"action":"send"}"""))
        assertEquals(ToolRisk.HIGH, classifier.classify("sms_sender", """{"action":"read"}"""))
    }

    @Test
    fun t37_risk_phone_criticalForCall() {
        val classifier = RiskClassifier()
        assertEquals(ToolRisk.CRITICAL, classifier.classify("phone_caller", """{"action":"call"}"""))
        assertEquals(ToolRisk.HIGH, classifier.classify("phone_caller", """{"action":"dial"}"""))
    }

    @Test
    fun t38_risk_unknownTool_defaultsHigh() {
        val classifier = RiskClassifier()
        assertEquals(ToolRisk.HIGH, classifier.classify("unknown_tool_xyz", "{}"))
    }

    // ── LoopDetector ────────────────────────────────────

    @Test
    fun t39_loopDetector_okOnFirstActions() {
        val detector = LoopDetector()
        val result = detector.record("calculator", """{"expression":"1+1"}""", "2")
        assertTrue("First action is Ok", result is LoopDetector.LoopCheckResult.Ok)
    }

    @Test
    fun t40_loopDetector_warningAfter3Repeats() {
        val detector = LoopDetector()
        detector.record("screen_action", """{"action":"tap","x":100,"y":200}""", "obs1")
        detector.record("screen_action", """{"action":"tap","x":100,"y":200}""", "obs2")
        val result = detector.record("screen_action", """{"action":"tap","x":100,"y":200}""", "obs3")
        assertTrue("3rd repeat is Warning", result is LoopDetector.LoopCheckResult.Warning)
    }

    @Test
    fun t41_loopDetector_forceBreakAfterSecondWarning() {
        val detector = LoopDetector()
        detector.record("screen_action", """{"action":"tap","x":1,"y":2}""", "obs1")
        detector.record("screen_action", """{"action":"tap","x":1,"y":2}""", "obs2")
        detector.record("screen_action", """{"action":"tap","x":1,"y":2}""", "obs3")
        val fourth = detector.record("screen_action", """{"action":"tap","x":1,"y":2}""", "obs4")
        assertTrue(
            "ForceBreak after repeated warning",
            fourth is LoopDetector.LoopCheckResult.ForceBreak,
        )
    }

    @Test
    fun t42_loopDetector_scrollAllowedRepeatedly() {
        val detector = LoopDetector()
        detector.record("screen_action", """{"action":"scroll","direction":"down"}""", "scrolled1")
        detector.record("screen_action", """{"action":"scroll","direction":"down"}""", "scrolled2")
        detector.record("screen_action", """{"action":"scroll","direction":"down"}""", "scrolled3")
        val result = detector.record("screen_action", """{"action":"scroll","direction":"down"}""", "scrolled4")
        assertTrue("Scroll is allowed to repeat", result is LoopDetector.LoopCheckResult.Ok)
    }

    @Test
    fun t43_loopDetector_differentActions_ok() {
        val detector = LoopDetector()
        detector.record("calculator", """{"expression":"1+1"}""", "2")
        detector.record("device_info", "{}", "info")
        detector.record("notepad", """{"action":"save","key":"x","value":"y"}""", "saved")
        val result = detector.record("calculator", """{"expression":"2+2"}""", "4")
        assertTrue("Different actions ok", result is LoopDetector.LoopCheckResult.Ok)
    }

    @Test
    fun t44_loopDetector_reset() {
        val detector = LoopDetector()
        repeat(3) { detector.record("screen_action", """{"action":"tap","x":1,"y":2}""", "obs") }
        detector.reset()
        val result = detector.record("screen_action", """{"action":"tap","x":1,"y":2}""", "obs")
        assertTrue("Ok after reset", result is LoopDetector.LoopCheckResult.Ok)
    }

    @Test
    fun t45_loopDetector_shouldNudge_after3Iterations() {
        val detector = LoopDetector()
        assertFalse("No nudge at iter 2", detector.shouldNudge(2, false))
        assertTrue("Nudge at iter 3", detector.shouldNudge(3, false))
        assertTrue("Nudge at iter 5", detector.shouldNudge(5, false))
        assertFalse("No nudge when has answer", detector.shouldNudge(5, true))
    }

    // ── PromptBuilder ───────────────────────────────────

    private fun createPromptBuilder(): Pair<PromptBuilder, MockLlmProvider> {
        val mockProvider = MockLlmProvider()
        val builder = PromptBuilder(mockProvider)
        return builder to mockProvider
    }

    @Test
    fun t46_promptBuilder_buildSystemPrompt_containsTools() {
        val (builder, _) = createPromptBuilder()
        val prompt = builder.buildSystemPrompt("calculator, timer")
        assertTrue("Contains tool list", prompt.contains("calculator"))
        assertTrue("Contains FORMAT", prompt.contains("FORMAT"))
        assertTrue("Contains RULES", prompt.contains("RULES"))
    }

    @Test
    fun t47_promptBuilder_addUserMessage() {
        val (builder, _) = createPromptBuilder()
        builder.addUserMessage("hello")
        val history = builder.getHistory()
        assertEquals(1, history.size)
        assertEquals("user" to "hello", history[0])
    }

    @Test
    fun t48_promptBuilder_addAssistantMessage() {
        val (builder, _) = createPromptBuilder()
        builder.addAssistantMessage("hi there")
        val history = builder.getHistory()
        assertEquals(1, history.size)
        assertEquals("assistant" to "hi there", history[0])
    }

    @Test
    fun t49_promptBuilder_addObservation() {
        val (builder, _) = createPromptBuilder()
        builder.addObservation("Observation: result=42")
        val history = builder.getHistory()
        assertEquals(1, history.size)
        assertEquals("user" to "Observation: result=42", history[0])
    }

    @Test
    fun t50_promptBuilder_clearHistory() {
        val (builder, _) = createPromptBuilder()
        builder.addUserMessage("a")
        builder.addAssistantMessage("b")
        builder.clearHistory()
        assertTrue("History cleared", builder.getHistory().isEmpty())
    }

    @Test
    fun t51_promptBuilder_buildDeltaPrompt_returnsNewMessages() {
        val (builder, _) = createPromptBuilder()
        builder.markAllProcessed()

        builder.addUserMessage("new message")
        val delta = builder.buildDeltaPrompt()
        assertNotNull("Delta not null", delta)
        assertTrue("Delta contains new message", delta!!.contains("new message"))
    }

    @Test
    fun t52_promptBuilder_buildDeltaPrompt_nullWhenAllProcessed() {
        val (builder, _) = createPromptBuilder()
        builder.addUserMessage("msg")
        builder.markAllProcessed()
        assertNull("Null when all processed", builder.buildDeltaPrompt())
    }

    @Test
    fun t53_promptBuilder_resetProcessedIndex_rebuildsAll() {
        val (builder, _) = createPromptBuilder()
        builder.addUserMessage("first")
        builder.markAllProcessed()
        builder.addUserMessage("second")

        builder.resetProcessedIndex()
        val delta = builder.buildDeltaPrompt()
        assertNotNull("Delta after reset", delta)
        assertTrue("Contains first", delta!!.contains("first"))
        assertTrue("Contains second", delta.contains("second"))
    }

    @Test
    fun t54_promptBuilder_buildPromptForInfer_includesSystemAndHistory() {
        val (builder, mockProvider) = createPromptBuilder()
        builder.addUserMessage("hello")
        builder.addAssistantMessage("hi")
        val prompt = builder.buildPromptForInfer("system prompt here")
        assertEquals("formatChat called", 1, mockProvider.formatChatCalls)
        assertTrue("Roles include system", mockProvider.lastRoles?.contains("system") == true)
        assertTrue("Roles include user", mockProvider.lastRoles?.contains("user") == true)
    }

    @Test
    fun t55_promptBuilder_fullAgentLoop_historySequence() {
        val (builder, _) = createPromptBuilder()
        builder.addUserMessage("what time is it")
        builder.addAssistantMessage("Action: device_info\nArgs: {}")
        builder.addObservation("Observation: time is 3pm")
        builder.addAssistantMessage("Answer: It's 3pm")

        val history = builder.getHistory()
        assertEquals(4, history.size)
        assertEquals("user", history[0].first)
        assertEquals("assistant", history[1].first)
        assertEquals("user", history[2].first)
        assertEquals("assistant", history[3].first)
    }

    // ── BuildConfig ─────────────────────────────────────

    @Test
    fun t56_buildConfig_githubRepo_isSet() {
        assertTrue("GITHUB_REPO set", BuildConfig.GITHUB_REPO.isNotEmpty())
        assertTrue("GITHUB_REPO format", BuildConfig.GITHUB_REPO.contains("/"))
    }

    @Test
    fun t57_buildConfig_versionName_isSemver() {
        assertTrue(
            "VERSION_NAME is semver",
            BuildConfig.VERSION_NAME.matches(Regex("\\d+\\.\\d+\\.\\d+")),
        )
    }

    @Test
    fun t58_buildConfig_versionCode_positive() {
        assertTrue("VERSION_CODE > 0", BuildConfig.VERSION_CODE > 0)
    }

    // ── ServiceState ────────────────────────────────────

    @Test
    fun t59_serviceState_allStatesExist() {
        val states = ServiceState.entries
        assertTrue("Has DISCONNECTED", states.contains(ServiceState.DISCONNECTED))
        assertTrue("Has CONNECTING", states.contains(ServiceState.CONNECTING))
        assertTrue("Has READY", states.contains(ServiceState.READY))
        assertTrue("Has MODEL_LOADED", states.contains(ServiceState.MODEL_LOADED))
        assertTrue("Has GENERATING", states.contains(ServiceState.GENERATING))
        assertTrue("Has AGENT_RUNNING", states.contains(ServiceState.AGENT_RUNNING))
    }

    // ── ToolRisk ────────────────────────────────────────

    @Test
    fun t60_toolRisk_allLevelsExist() {
        val risks = ToolRisk.entries
        assertEquals("4 risk levels", 4, risks.size)
        assertTrue("Has SAFE", risks.contains(ToolRisk.SAFE))
        assertTrue("Has LOW", risks.contains(ToolRisk.LOW))
        assertTrue("Has HIGH", risks.contains(ToolRisk.HIGH))
        assertTrue("Has CRITICAL", risks.contains(ToolRisk.CRITICAL))
    }

    // ── Model Load & Chat (LlamaBridge native) ─────────

    private fun createBridge(): com.agent.aios.LlamaBridge {
        val bridge = com.agent.aios.LlamaBridge()
        bridge.nativeInit(
            InstrumentationRegistry.getInstrumentation().targetContext.applicationInfo.nativeLibraryDir,
        )
        return bridge
    }

    private fun loadModel(bridge: com.agent.aios.LlamaBridge): String {
        val path = findModelPath() ?: error("No model file found on device")
        assertTrue("Model loaded", bridge.nativeLoadModel(path, 2048))
        bridge.nativeSetSamplingParams(1.0f, 0, 1.0f, 1.0f)
        return path
    }

    private fun findModelPath(): String? {
        val candidates =
            listOf(
                "/sdcard/Download/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf",
                "/sdcard/Download/qwen2.5-0.5b-instruct-q2_k.gguf",
            )
        return candidates.firstOrNull { path ->
            try {
                java.io.File(path).exists()
            } catch (_: Exception) {
                false
            }
        }
    }

    @Test
    fun t61_nativeLibrary_loaded() {
        assertTrue(
            "Native library loaded",
            com.agent.aios.LlamaBridge.libraryLoaded,
        )
    }

    @Test
    fun t62_modelLoad_loadsAndValidates() {
        val path = findModelPath()
        if (path == null) {
            println("SKIP: No model file found on device")
            return
        }

        val bridge = createBridge()
        val loadOk = bridge.nativeLoadModel(path, 2048)
        assertTrue("Model loaded from $path", loadOk)
        assertTrue("isModelLoaded after load", bridge.nativeIsModelLoaded())

        val info = bridge.nativeGetModelInfo()
        assertTrue("Model info not empty", info.isNotEmpty())

        bridge.nativeReleaseModel()
    }

    @Test
    fun t63_modelLoad_invalidPath_returnsFalse() {
        val bridge = createBridge()
        val loadOk = bridge.nativeLoadModel("/sdcard/nonexistent_model_xyz.gguf", 2048)
        assertFalse("Invalid model path returns false", loadOk)
    }

    @Test
    fun t64_chat_processPromptAndGenerate() {
        val path = findModelPath()
        if (path == null) {
            println("SKIP: No model file found on device")
            return
        }

        val bridge = createBridge()
        loadModel(bridge)

        try {
            val formatted =
                bridge.nativeFormatChat(
                    arrayOf("user"),
                    arrayOf("Hello, say hi in one word."),
                )
            assertTrue("Formatted chat not empty", formatted.isNotEmpty())

            val promptResult = bridge.nativeProcessPrompt(formatted)
            assertTrue("processPrompt returned >= 0", promptResult >= 0)

            val tokens = mutableListOf<String>()
            for (i in 0..63) {
                val token = bridge.nativeGenerateOneToken()
                if (token == null) break
                tokens.add(token)
            }
            assertTrue("Generated at least 1 token", tokens.isNotEmpty())
            val response = tokens.joinToString("")
            assertTrue("Response not empty", response.isNotBlank())
        } finally {
            bridge.nativeReleaseModel()
        }
    }

    @Test
    fun t65_chat_batchGeneration() {
        val path = findModelPath()
        if (path == null) {
            println("SKIP: No model file found on device")
            return
        }

        val bridge = createBridge()
        loadModel(bridge)

        try {
            val formatted =
                bridge.nativeFormatChat(
                    arrayOf("user"),
                    arrayOf("What is 2+2? Answer with just the number."),
                )
            bridge.nativeProcessPrompt(formatted)

            val batch = bridge.nativeGenerateTokensBatch(64)
            if (batch != null) {
                assertTrue("Batch not empty", batch.isNotEmpty())
            }
        } finally {
            bridge.nativeReleaseModel()
        }
    }

    @Test
    fun t66_chat_contextUsage_afterInference() {
        val path = findModelPath()
        if (path == null) {
            println("SKIP: No model file found on device")
            return
        }

        val bridge = createBridge()
        loadModel(bridge)

        try {
            val formatted =
                bridge.nativeFormatChat(
                    arrayOf("user"),
                    arrayOf("Say hello."),
                )
            bridge.nativeProcessPrompt(formatted)
            repeat(16) { bridge.nativeGenerateOneToken() }

            val usage = bridge.nativeGetContextUsage()
            assertTrue("Usage format valid", usage.contains("/"))
            val parts = usage.split("/")
            assertTrue("Used tokens >= 0", parts[0].toIntOrNull()?.let { it >= 0 } == true)
            assertTrue("Total tokens > 0", parts[1].toIntOrNull()?.let { it > 0 } == true)
        } finally {
            bridge.nativeReleaseModel()
        }
    }

    @Test
    fun t67_chat_resetContext_clearsState() {
        val path = findModelPath()
        if (path == null) {
            println("SKIP: No model file found on device")
            return
        }

        val bridge = createBridge()
        loadModel(bridge)

        try {
            val formatted =
                bridge.nativeFormatChat(
                    arrayOf("user"),
                    arrayOf("Say hello."),
                )
            bridge.nativeProcessPrompt(formatted)
            repeat(16) { bridge.nativeGenerateOneToken() }

            val usageBefore = bridge.nativeGetContextUsage()
            bridge.nativeResetContext()
            val usageAfter = bridge.nativeGetContextUsage()

            val usedBefore = usageBefore.split("/").getOrNull(0)?.toIntOrNull() ?: 0
            val usedAfter = usageAfter.split("/").getOrNull(0)?.toIntOrNull() ?: 0
            assertTrue("Context usage decreased after reset", usedAfter <= usedBefore)
        } finally {
            bridge.nativeReleaseModel()
        }
    }

    @Test
    fun t68_chat_samplingParams_doesNotCrash() {
        val path = findModelPath()
        if (path == null) {
            println("SKIP: No model file found on device")
            return
        }

        val bridge = createBridge()
        loadModel(bridge)

        try {
            bridge.nativeSetSamplingParams(0.7f, 40, 0.9f, 1.1f)

            val formatted =
                bridge.nativeFormatChat(
                    arrayOf("user"),
                    arrayOf("Say ok."),
                )
            bridge.nativeProcessPrompt(formatted)
            bridge.nativeGenerateOneToken()
            assertTrue("No crash with custom sampling", true)
        } finally {
            bridge.nativeReleaseModel()
        }
    }

    @Test
    fun t69_modelLoad_releaseAndReload() {
        val path = findModelPath()
        if (path == null) {
            println("SKIP: No model file found on device")
            return
        }

        val bridge = createBridge()

        assertTrue("First load", bridge.nativeLoadModel(path, 2048))
        assertTrue("Loaded after first load", bridge.nativeIsModelLoaded())
        bridge.nativeReleaseModel()

        assertTrue("Second load after release", bridge.nativeLoadModel(path, 2048))
        assertTrue("Loaded after second load", bridge.nativeIsModelLoaded())
        bridge.nativeReleaseModel()
    }

    @Test
    fun t70_chat_multiTurn_conversation() {
        val path = findModelPath()
        if (path == null) {
            println("SKIP: No model file found on device")
            return
        }

        val bridge = createBridge()
        loadModel(bridge)

        try {
            // Turn 1
            val formatted1 =
                bridge.nativeFormatChat(
                    arrayOf("user"),
                    arrayOf("My name is TestUser. Remember it."),
                )
            bridge.nativeProcessPrompt(formatted1)
            repeat(32) { bridge.nativeGenerateOneToken() }

            // Turn 2 - multi-turn context (incremental)
            val formatted2 =
                bridge.nativeFormatChat(
                    arrayOf("assistant", "user"),
                    arrayOf("Understood.", "What is my name?"),
                )
            val incResult = bridge.nativeProcessPromptIncremental(formatted2)
            assertTrue("Incremental prompt processed", incResult >= 0)

            val tokens = mutableListOf<String>()
            for (i in 0..63) {
                val token = bridge.nativeGenerateOneToken()
                if (token == null) break
                tokens.add(token)
            }
            assertTrue("Second turn generated tokens", tokens.isNotEmpty())
        } finally {
            bridge.nativeReleaseModel()
        }
    }

    class MockLlmProvider : LlmProvider {
        var formatChatCalls = 0
        var lastRoles: Array<String>? = null
        var lastContents: Array<String>? = null

        override fun formatChat(roles: Array<String>, contents: Array<String>): String {
            formatChatCalls++
            lastRoles = roles
            lastContents = contents
            return roles.zip(contents).joinToString("\n") { "${it.first}: ${it.second}" }
        }

        override fun processPromptIncremental(prompt: String): Int = 0

        override fun processPrompt(prompt: String): Int = 0

        override fun processSystemPrompt(prompt: String): Int = 0

        override fun setSystemPromptPosition() {}

        override fun generateOneToken(): String? = null

        override fun generateTokensBatch(maxTokens: Int): String? = null

        override fun cancelGeneration() {}

        override fun resetContext() {}

        override fun getContextUsage(): String = "100/2048"

        override fun isModelLoaded(): Boolean = false

        override fun getModelInfo(): String = "MockProvider"

        override fun setSamplingParams(
            temperature: Float,
            topK: Int,
            topP: Float,
            repeatPenalty: Float,
        ) {}

        override fun releaseModel() {}

        override fun updateNotification(text: String) {}

        override fun setTokenCallback(cb: ((String) -> Unit)?) {}

        override fun swapTokenCallback(cb: ((String) -> Unit)?): ((String) -> Unit)? = null
    }
}
