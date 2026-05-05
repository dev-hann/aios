package com.agent.aios

import com.agent.aios.domain.agent.ReactStrategy
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

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], manifest = Config.NONE)
class BenchmarkTest {
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

    private fun setupMocks() {
        every { mockService.processPrompt(any()) } returns 0
        every { mockService.processPromptIncremental(any()) } returns 0
        every { mockService.setSystemPromptPosition() } answers { nothing }
        every { mockService.processSystemPrompt(any()) } returns 0
        every { mockService.formatChat(any(), any()) } returns "formatted"
        every { mockService.getContextUsage() } returns "100/1000"

        every { mockService.generateTokensBatch(any()) } answers {
            responseQueue.poll()
        }
    }

    @Test
    fun benchmark_kvCacheReuse_secondIterationCallsProcessPrompt() {
        setupMocks()
        responseQueue.add("Action: calculator\nArgs: {\"expression\": \"1+1\"}")
        responseQueue.add("Answer: 2")

        val result = runBlocking { strategy.execute("Calculate 1+1") {} }

        assertTrue(result.steps.any { it.type == "answer" })
        verify(exactly = 1) { mockService.processPromptIncremental(any()) }
        verify(atLeast = 1) { mockService.processPrompt(any()) }
    }

    @Test
    fun benchmark_batchGeneration_singleJniCall() {
        setupMocks()
        responseQueue.add("Answer: batch works")

        runBlocking { strategy.execute("Hello") {} }

        verify(exactly = 1) { mockService.generateTokensBatch(any()) }
        verify(exactly = 0) { mockService.generateOneToken() }
    }

    @Test
    fun benchmark_systemPromptTemplate_shorterThanOriginal() {
        val template = PromptBuilder(mockService).buildSystemPrompt("")
        val originalLength = 926
        assertTrue(
            "Template should be shorter than $originalLength chars, was ${template.length}",
            template.length < originalLength,
        )
    }

    @Test
    fun benchmark_systemPromptContainsAllTools() {
        val manifest = strategy.getToolManifest()
        val prompt = PromptBuilder(mockService).buildSystemPrompt(manifest)
        val toolNames =
            listOf(
                "calculator", "timer", "device_info", "notepad",
                "screen_reader", "screen_find", "screen_action", "app_launcher",
                "notification_reader", "sms_sender", "phone_caller", "contact_search",
            )
        for (tool in toolNames) {
            assertTrue(
                "System prompt should contain tool '$tool'",
                prompt.contains(tool),
            )
        }
    }
}
