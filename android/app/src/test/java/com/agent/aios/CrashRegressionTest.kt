package com.agent.aios

import com.agent.aios.data.llm.LlmRepositoryImpl
import com.agent.aios.data.tool.ToolContextImpl
import com.agent.aios.domain.agent.ConfirmationGate
import com.agent.aios.domain.agent.ReactStrategy
import com.agent.aios.domain.agent.ResponseParser
import com.agent.aios.domain.agent.RiskClassifier
import com.agent.aios.domain.model.AgentResult
import com.agent.aios.domain.model.AgentStep
import com.agent.aios.domain.model.ServiceState
import com.agent.aios.domain.model.ToolRisk
import com.agent.aios.domain.repository.SettingsRepository
import com.agent.aios.domain.repository.UpdateRepository
import com.agent.aios.service.ServiceRegistry
import io.mockk.*
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], manifest = Config.NONE)
class CrashRegressionTest {
    @Before
    fun setup() {
        mockkStatic(android.util.Log::class)
        every { android.util.Log.i(any(), any()) } returns 0
        every { android.util.Log.e(any(), any(), any()) } returns 0
        every { android.util.Log.d(any(), any()) } returns 0
        every { android.util.Log.w(any(), any<String>()) } returns 0
    }

    @After
    fun tearDown() {
        unmockkAll()
    }

    // ==================== ReactStrategy Crash Regressions ====================

    @Test
    fun `P1-4 ReactStrategy handles interruption gracefully`() {
        val mockService = mockk<LlmService>(relaxed = true)
        val strategy = ReactStrategy(mockService)

        every { mockService.processPrompt(any()) } returns 0
        every { mockService.generateOneToken() } throws InterruptedException("cancelled")
        every { mockService.formatChat(any(), any()) } returns "formatted"
        every { mockService.getContextUsage() } returns "100/1000"

        val result = runBlocking { strategy.execute("test") {} }
        assertTrue(result.steps.any { it.type == "answer" && it.content == "Task cancelled." })
    }

    @Test
    fun `P1 confirmationLatch race resolveConfirmation and cancel no crash`() {
        val gate = ConfirmationGate()
        val errors = Collections.synchronizedList(mutableListOf<Throwable>())
        val done = CountDownLatch(20)

        repeat(20) { idx ->
            thread(start = true) {
                try {
                    if (idx % 2 == 0) gate.resolve(true) else gate.cancel()
                } catch (e: Throwable) {
                    errors.add(e)
                } finally {
                    done.countDown()
                }
            }
        }

        assertTrue("All threads complete", done.await(5, TimeUnit.SECONDS))
        assertTrue("No exceptions during concurrent resolve/cancel: $errors", errors.isEmpty())
    }

    @Test
    fun `concurrent resolveConfirmation on ReactStrategy does not crash`() {
        val mockService = mockk<LlmService>(relaxed = true)
        val strategy = ReactStrategy(mockService)

        var error: Throwable? = null
        val done = CountDownLatch(20)
        repeat(20) { idx ->
            thread(start = true) {
                try {
                    strategy.resolveConfirmation(idx % 2 == 0)
                } catch (e: Throwable) {
                    error = e
                } finally {
                    done.countDown()
                }
            }
        }
        assertTrue(done.await(5, TimeUnit.SECONDS))
        assertNull(error)
    }

    // ==================== ResponseParser Edge Cases ====================

    @Test
    fun `parser handles unknown tool gracefully`() {
        val parser = ResponseParser(setOf("calculator"))
        val result = parser.parse("Action: unknown_tool\nArgs: {}")
        assertEquals(ResponseParser.ParseResult.Empty, result)
    }

    @Test
    fun `parser handles malformed json args`() {
        val parser = ResponseParser(setOf("screen_action"))
        val result = parser.parse("Action: screen_action\nArgs: {broken json")
        assertTrue(result is ResponseParser.ParseResult.Action)
        val action = result as ResponseParser.ParseResult.Action
        assertTrue(action.args.startsWith("{"))
    }

    // ==================== RiskClassifier Edge Cases ====================

    @Test
    fun `classifier handles all sensitive keywords`() {
        val classifier = RiskClassifier()
        val sensitive = listOf("password", "pin", "passcode", "ssn", "social security", "credit card", "cvv", "otp")
        for (keyword in sensitive) {
            assertEquals(
                "Expected CRITICAL for keyword '$keyword'",
                ToolRisk.CRITICAL,
                classifier.classify("screen_action", "{\"action\": \"type\", \"content\": \"$keyword\"}"),
            )
        }
    }

    @Test
    fun `classifier handles empty args gracefully`() {
        val classifier = RiskClassifier()
        assertEquals(ToolRisk.SAFE, classifier.classify("calculator", ""))
        assertEquals(ToolRisk.HIGH, classifier.classify("screen_action", ""))
        assertEquals(ToolRisk.LOW, classifier.classify("app_launcher", ""))
    }

    // ==================== LlmRepositoryImpl Crash Regressions ====================

    @Test
    fun `cancelInference when no strategy clears state`() {
        val mockSettingsRepo = mockk<SettingsRepository>(relaxed = true)
        val mockUpdateRepo = mockk<UpdateRepository>(relaxed = true)
        val mockServiceRegistry = mockk<ServiceRegistry>(relaxed = true)
        val mockToolContextImpl = mockk<ToolContextImpl>(relaxed = true)

        every { mockSettingsRepo.agentMaxIterations } returns kotlinx.coroutines.flow.flowOf(8)
        every { mockSettingsRepo.maxTokensAgent } returns kotlinx.coroutines.flow.flowOf(512)

        val repo = LlmRepositoryImpl(
            context = mockk(relaxed = true),
            settingsRepository = mockSettingsRepo,
            serviceRegistry = mockServiceRegistry,
            toolContextImpl = mockToolContextImpl,
            updateRepository = mockUpdateRepo,
        )

        repo.cancelInference()
        assertEquals(ServiceState.MODEL_LOADED, repo.serviceState.value)
    }

    @Test
    fun `resolveConfirmation when no strategy does not crash`() {
        val mockSettingsRepo = mockk<SettingsRepository>(relaxed = true)
        val mockUpdateRepo = mockk<UpdateRepository>(relaxed = true)
        val mockServiceRegistry = mockk<ServiceRegistry>(relaxed = true)
        val mockToolContextImpl = mockk<ToolContextImpl>(relaxed = true)

        val repo = LlmRepositoryImpl(
            context = mockk(relaxed = true),
            settingsRepository = mockSettingsRepo,
            serviceRegistry = mockServiceRegistry,
            toolContextImpl = mockToolContextImpl,
            updateRepository = mockUpdateRepo,
        )

        repo.resolveConfirmation(true)
        repo.resolveConfirmation(false)
    }

    // ==================== LlmService Crash Regressions ====================

    @Test
    fun `R-3 LlmService overrides onStartCommand`() {
        val method =
            LlmService::class.java.getDeclaredMethod(
                "onStartCommand",
                android.content.Intent::class.java,
                Int::class.java,
                Int::class.java,
            )
        val declaringClass = method.declaringClass
        assertTrue(
            "LlmService must override onStartCommand to call startForeground()",
            declaringClass == LlmService::class.java,
        )
    }

    @Test
    fun `R-4 LlmService extends Service`() {
        assertTrue(
            "LlmService must extend android.app.Service",
            android.app.Service::class.java.isAssignableFrom(LlmService::class.java),
        )
    }
}
