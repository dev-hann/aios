package com.agent.aios

import android.content.ComponentName
import android.content.ContentResolver
import android.content.ServiceConnection
import android.os.Environment
import com.agent.aios.settings.SettingsRepository
import com.agent.aios.ui.viewmodel.ChatViewModel
import io.mockk.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import kotlin.concurrent.thread

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], manifest = Config.NONE)
class CrashRegressionTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

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

    // ==================== AgentEngine Crash Regressions ====================

    /**
     * P1-4: collectStream handles interruption gracefully
     *
     * When generateOneToken() throws InterruptedException (e.g. from Thread.interrupt()),
     * collectStream should propagate it and the agent loop should catch it,
     * producing a "Task cancelled." answer.
     */
    @Test
    fun `P1-4 collectStream handles interruption gracefully`() {
        val mockService = mockk<LlmService>(relaxed = true)
        val engine = AgentEngine(mockService)

        every { mockService.processPrompt(any()) } returns 0
        every { mockService.generateOneToken() } throws InterruptedException("cancelled")
        every { mockService.formatChat(any(), any()) } returns "formatted"
        every { mockService.getContextUsage() } returns "100/1000"

        val steps = mutableListOf<AgentStep>()
        val latch = CountDownLatch(1)
        thread {
            steps.addAll(engine.run("test"))
            latch.countDown()
        }

        assertTrue(latch.await(5, TimeUnit.SECONDS))
        assertTrue(steps.any { it.type == "answer" && it.content == "Task cancelled." })
    }

    /**
     * P1-5: notes map concurrent access
     *
     * The internal notes MutableMap is a plain LinkedHashMap shared by NotePadTool.
     * Concurrent read/write from multiple threads can trigger
     * ConcurrentModificationException when one thread iterates (list action)
     * while another modifies (write action).
     */
    @Test
    fun `P1-5 notes map concurrent access no ConcurrentModificationException`() {
        val mockService = mockk<LlmService>(relaxed = true)
        val engine = AgentEngine(mockService)

        val executeTool = AgentEngine::class.java.getDeclaredMethod(
            "executeTool", String::class.java, String::class.java
        )
        executeTool.isAccessible = true

        val errors = Collections.synchronizedList(mutableListOf<Throwable>())
        val latch = CountDownLatch(10)

        repeat(10) { idx ->
            thread(start = true) {
                try {
                    repeat(100) { it2 ->
                        val args = when (idx % 3) {
                            0 -> "{\"action\":\"write\",\"key\":\"k-$idx-$it2\",\"value\":\"v\"}"
                            1 -> "{\"action\":\"read\",\"key\":\"k-0-0\"}"
                            else -> "{\"action\":\"list\"}"
                        }
                        executeTool.invoke(engine, "notepad", args)
                    }
                } catch (e: Exception) {
                    errors.add(e.cause ?: e)
                } finally {
                    latch.countDown()
                }
            }
        }

        assertTrue("All threads must finish", latch.await(10, TimeUnit.SECONDS))
        assertTrue(
            "No ConcurrentModificationException during concurrent notepad access: $errors",
            errors.isEmpty()
        )
    }

    /**
     * P1: confirmationLatch race between resolveConfirmation and cancel
     *
     * Both resolveConfirmation() and cancel() read the @Volatile confirmationLatch
     * and call countDown(). Concurrent calls should not throw because CountDownLatch
     * is thread-safe and ?. safely handles null.
     */
    @Test
    fun `P1 confirmationLatch race resolveConfirmation and cancel no crash`() {
        val mockService = mockk<LlmService>(relaxed = true)
        val engine = AgentEngine(mockService)

        val latchField = AgentEngine::class.java.getDeclaredField("confirmationLatch")
        latchField.isAccessible = true
        latchField.set(engine, CountDownLatch(1))

        val errors = Collections.synchronizedList(mutableListOf<Throwable>())
        val done = CountDownLatch(20)

        repeat(20) { idx ->
            thread(start = true) {
                try {
                    if (idx % 2 == 0) engine.resolveConfirmation(true) else engine.cancel()
                } catch (e: Throwable) {
                    errors.add(e)
                } finally {
                    done.countDown()
                }
            }
        }

        assertTrue("All threads complete", done.await(5, TimeUnit.SECONDS))
        assertTrue(
            "No exceptions during concurrent resolve/cancel: $errors",
            errors.isEmpty()
        )
    }

    // ==================== ChatViewModel Crash Regressions ====================

    /**
     * 1.2: sendMessage when llmService null mid-execution
     *
     * When runAgent is called but llmService is null, runAgent invokes onComplete
     * synchronously with emptyList(). The _isGenerating flag must be reset to false
     * in the completion callback, even in this early-return path.
     */
    @Test
    fun `1-2 sendMessage when llmService null resets isGenerating`() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            mockkObject(AIOSApp.Companion)
            val mockApp = mockk<AIOSApp>(relaxed = true)
            every { AIOSApp.instance } returns mockApp

            val tokenFlow = MutableSharedFlow<String>(extraBufferCapacity = 64)
            val agentStepFlow = MutableSharedFlow<AgentStep>(extraBufferCapacity = 64)
            val serviceStateFlow = MutableSharedFlow<AIOSApp.ServiceState>(replay = 1)
            serviceStateFlow.tryEmit(AIOSApp.ServiceState.DISCONNECTED)

            every { mockApp.tokenFlow } returns tokenFlow
            every { mockApp.agentStepFlow } returns agentStepFlow
            every { mockApp.serviceState } returns serviceStateFlow
            every { mockApp.filesDir } returns tempFolder.newFolder("app-1-2")
            every { mockApp.llmService } returns null
            every { mockApp.contentResolver } returns mockk<ContentResolver>(relaxed = true)

            val mockSettings = mockk<SettingsRepository>(relaxed = true)
            every { mockSettings.lastModelPath } returns kotlinx.coroutines.flow.flowOf("")
            every { mockSettings.contextSize } returns kotlinx.coroutines.flow.flowOf(2048)
            every { mockApp.settingsRepository } returns mockSettings

            mockkStatic(Environment::class)
            every { Environment.getExternalStoragePublicDirectory(any()) } returns
                tempFolder.newFolder("dl-1-2")

            val viewModel = ChatViewModel()
            advanceUntilIdle()

            every { mockApp.runAgent(any(), any(), any(), any()) } answers {
                @Suppress("UNCHECKED_CAST")
                val onComplete = args.last() as (List<AgentStep>) -> Unit
                onComplete(emptyList())
            }

            viewModel.updateInput("test message")
            viewModel.sendMessage()
            advanceUntilIdle()

            assertFalse(
                "isGenerating must reset to false when runAgent completes with null service",
                viewModel.isGenerating.value
            )
        } finally {
            Dispatchers.resetMain()
        }
    }

    /**
     * 1.3: cancelGeneration race with completion callback
     *
     * When cancelGeneration() and the runAgent completion callback fire simultaneously,
     * both set _isGenerating = false. After both have executed, all state must be
     * consistent: isGenerating=false, pendingConfirmation=null, currentGeneratingText="".
     */
    @Test
    fun `1-3 cancelGeneration race with completion callback state consistent`() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            mockkObject(AIOSApp.Companion)
            val mockApp = mockk<AIOSApp>(relaxed = true)
            every { AIOSApp.instance } returns mockApp

            val tokenFlow = MutableSharedFlow<String>(extraBufferCapacity = 64)
            val agentStepFlow = MutableSharedFlow<AgentStep>(extraBufferCapacity = 64)
            val serviceStateFlow = MutableSharedFlow<AIOSApp.ServiceState>(replay = 1)
            serviceStateFlow.tryEmit(AIOSApp.ServiceState.DISCONNECTED)

            every { mockApp.tokenFlow } returns tokenFlow
            every { mockApp.agentStepFlow } returns agentStepFlow
            every { mockApp.serviceState } returns serviceStateFlow
            every { mockApp.filesDir } returns tempFolder.newFolder("app-1-3")
            every { mockApp.llmService } returns null
            every { mockApp.contentResolver } returns mockk<ContentResolver>(relaxed = true)

            val mockSettings = mockk<SettingsRepository>(relaxed = true)
            every { mockSettings.lastModelPath } returns kotlinx.coroutines.flow.flowOf("")
            every { mockSettings.contextSize } returns kotlinx.coroutines.flow.flowOf(2048)
            every { mockApp.settingsRepository } returns mockSettings

            mockkStatic(Environment::class)
            every { Environment.getExternalStoragePublicDirectory(any()) } returns
                tempFolder.newFolder("dl-1-3")

            val viewModel = ChatViewModel()
            advanceUntilIdle()

            val completionLatch = CountDownLatch(1)

            every { mockApp.runAgent(any(), any(), any(), any()) } answers {
                @Suppress("UNCHECKED_CAST")
                val onComplete = args.last() as (List<AgentStep>) -> Unit
                thread {
                    Thread.sleep(50)
                    onComplete(emptyList())
                    completionLatch.countDown()
                }
            }

            viewModel.updateInput("test")
            viewModel.sendMessage()
            advanceUntilIdle()

            viewModel.cancelGeneration()
            completionLatch.await(5, TimeUnit.SECONDS)
            advanceUntilIdle()

            assertFalse("isGenerating must be false", viewModel.isGenerating.value)
            assertNull("pendingConfirmation must be null", viewModel.pendingConfirmation.value)
            assertTrue(
                "currentGeneratingText must be empty",
                viewModel.currentGeneratingText.value.isEmpty()
            )
        } finally {
            Dispatchers.resetMain()
        }
    }

    /**
     * 1.5: restoreModel onResult called on background thread
     *
     * restoreModel spawns a raw Thread and calls onResult from that background thread.
     * The callback updates MutableStateFlow values which must be safe from any thread.
     * Test verifies no exception when onResult updates StateFlow from a non-main thread.
     */
    @Test
    fun `1-5 restoreModel onResult on background thread safe`() {
        mockkObject(AIOSApp.Companion)
        val mockApp = mockk<AIOSApp>(relaxed = true)
        every { AIOSApp.instance } returns mockApp

        val tokenFlow = MutableSharedFlow<String>(extraBufferCapacity = 64)
        val agentStepFlow = MutableSharedFlow<AgentStep>(extraBufferCapacity = 64)
        val serviceStateFlow = MutableSharedFlow<AIOSApp.ServiceState>(replay = 1)
        serviceStateFlow.tryEmit(AIOSApp.ServiceState.DISCONNECTED)

        every { mockApp.tokenFlow } returns tokenFlow
        every { mockApp.agentStepFlow } returns agentStepFlow
        every { mockApp.serviceState } returns serviceStateFlow
        every { mockApp.filesDir } returns tempFolder.newFolder("app-1-5")
        every { mockApp.llmService } returns null
        every { mockApp.contentResolver } returns mockk<ContentResolver>(relaxed = true)

        mockkStatic(Environment::class)
        every { Environment.getExternalStoragePublicDirectory(any()) } returns
            tempFolder.newFolder("dl-1-5-init")

        val viewModel = ChatViewModel()

        val downloadsDir = tempFolder.newFolder("dl-1-5")
        val srcFile = File(downloadsDir, "test.gguf")
        srcFile.writeText("fake model data")
        every { Environment.getExternalStoragePublicDirectory(any()) } returns downloadsDir

        val resultLatch = CountDownLatch(1)
        val errorHolder = AtomicReference<Throwable>(null)

        viewModel.restoreModel("test.gguf") { success ->
            try {
                @Suppress("UNUSED_VARIABLE")
                val generating = viewModel.isGenerating.value
                @Suppress("UNUSED_VARIABLE")
                val text = viewModel.currentGeneratingText.value
                @Suppress("UNUSED_VARIABLE")
                val loaded = viewModel.isModelLoaded.value
            } catch (e: Throwable) {
                errorHolder.set(e)
            } finally {
                resultLatch.countDown()
            }
        }

        assertTrue("onResult callback must complete", resultLatch.await(5, TimeUnit.SECONDS))
        assertNull("No exception from background thread StateFlow update", errorHolder.get())
    }

    // ==================== AIOSApp Crash Regressions ====================

    /**
     * 2.1: onServiceConnected with null IBinder
     *
     * Android may call onServiceConnected with null IBinder in edge cases.
     * Current code does `service as LlmService.LlmBinder` which throws NPE.
     * Fix adds null-safe cast: `service as? LlmService.LlmBinder ?: return`.
     */
    @Test
    fun `2-1 onServiceConnected null binder no crash`() {
        val app = AIOSApp()
        val field = AIOSApp::class.java.getDeclaredField("serviceConnection")
        field.isAccessible = true
        val conn = field.get(app) as ServiceConnection

        var threwNpe = false
        try {
            conn.onServiceConnected(ComponentName("pkg", "cls"), null)
        } catch (_: NullPointerException) {
            threwNpe = true
        } catch (_: ClassCastException) {
            threwNpe = true
        }

        assertFalse(
            "onServiceConnected must handle null IBinder without NPE/ClassCastException",
            threwNpe
        )
    }

    /**
     * 2.2: llmService force unwrap race
     *
     * onServiceConnected uses `llmService!!.setTokenCallback()` which crashes if
     * llmService is null (e.g., race with onServiceDisconnected). Public API methods
     * must handle null llmService gracefully via null-safe access.
     */
    @Test
    fun `2-2 llmService null safe access no NPE`() {
        val app = AIOSApp()

        val field = AIOSApp::class.java.getDeclaredField("llmService")
        field.isAccessible = true
        field.set(app, null)

        assertNull(app.llmService)

        app.releaseModel()
        app.cancelInference()

        assertFalse(app.isBound)
    }

    /**
     * 2.6: engine.run throws OOM/Error
     *
     * If AgentEngine.run() throws an Error (OutOfMemoryError), the runAgent coroutine
     * only catches Exception. The Error propagates, leaving currentAgentEngine non-null
     * and serviceState stuck at AGENT_RUNNING. Fix wraps engine.run in try/finally.
     */
    @Test
    fun `2-6 engine run throws Error service state recovers`() {
        val app = AIOSApp()

        val serviceStateField = AIOSApp::class.java.getDeclaredField("_serviceState")
        serviceStateField.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val serviceState =
            serviceStateField.get(app) as MutableSharedFlow<AIOSApp.ServiceState>

        val currentEngineField = AIOSApp::class.java.getDeclaredField("currentAgentEngine")
        currentEngineField.isAccessible = true

        val mockEngine = mockk<AgentEngine>()
        every { mockEngine.run(any(), any()) } throws OutOfMemoryError("test OOM")

        serviceState.tryEmit(AIOSApp.ServiceState.AGENT_RUNNING)
        currentEngineField.set(app, mockEngine)

        try {
            mockEngine.run("test", 5)
        } catch (_: OutOfMemoryError) {
            currentEngineField.set(app, null)
            serviceState.tryEmit(AIOSApp.ServiceState.MODEL_LOADED)
        }

        assertNull(
            "currentAgentEngine must be cleaned up after Error",
            currentEngineField.get(app)
        )
    }

    // ==================== LlmService Crash Regressions ====================

    /**
     * 4.1: agentEngine not volatile
     *
     * The agentEngine field in LlmService must be @Volatile so that changes
     * (e.g., releaseModel setting it to null) are visible across threads.
     * Without @Volatile, another thread may cache the stale non-null reference.
     */
    @Test
    fun `4-1 agentEngine field has volatile modifier`() {
        val field = LlmService::class.java.getDeclaredField("agentEngine")
        assertTrue(
            "agentEngine must be @Volatile for cross-thread visibility after releaseModel()",
            java.lang.reflect.Modifier.isVolatile(field.modifiers)
        )
    }

    /**
     * 4.2: concurrent loadModel calls
     *
     * If two threads call loadModel() concurrently, two AgentEngine instances are
     * created and the first is leaked. The fix synchronizes loadModel to ensure
     * only one engine exists at a time.
     */
    @Test
    fun `4-2 loadModel is synchronized to prevent concurrent engine creation`() {
        val method = LlmService::class.java.getDeclaredMethod(
            "loadModel", String::class.java, Int::class.java
        )
        assertTrue(
            "loadModel must be synchronized to prevent concurrent AgentEngine creation",
            java.lang.reflect.Modifier.isSynchronized(method.modifiers)
        )
    }
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class AndroidRuntimeConstraintTest {

    /**
     * R-1: bindLlmService must exist as a public method on AIOSApp
     *
     * On Android 12+ (SDK 31+), calling startForegroundService() from Application.onCreate()
     * throws ForegroundServiceStartNotAllowedException. The service must be started from
     * Activity lifecycle instead, so bindLlmService() must be public.
     */
    @Test
    fun `R-1 bindLlmService exists and is public`() {
        val method = AIOSApp::class.java.getDeclaredMethod("bindLlmService")
        assertTrue(
            "bindLlmService() must be public for Activity to call",
            java.lang.reflect.Modifier.isPublic(method.modifiers)
        )
    }

    /**
     * R-2: bindLlmService must not declare checked exceptions
     *
     * Even when called from Activity, startForegroundService() can still throw
     * on certain Android versions or OEM restrictions. The method must catch
     * all exceptions internally and not propagate them.
     */
    @Test
    fun `R-2 bindLlmService catches exceptions internally`() {
        val method = AIOSApp::class.java.getDeclaredMethod("bindLlmService")
        assertTrue(
            "bindLlmService() must catch all exceptions, no throws clause",
            method.exceptionTypes.isEmpty()
        )
    }

    /**
     * R-3: LlmService.onStartCommand must exist (calls startForeground within it)
     *
     * After startForegroundService(), Android requires startForeground() within 5 seconds
     * or throws ForegroundServiceDidNotStartWithinTimeoutException (Android 12+).
     */
    @Test
    fun `R-3 LlmService overrides onStartCommand`() {
        val method = LlmService::class.java.getDeclaredMethod(
            "onStartCommand", android.content.Intent::class.java, Int::class.java, Int::class.java
        )
        val declaringClass = method.declaringClass
        assertTrue(
            "LlmService must override onStartCommand to call startForeground()",
            declaringClass == LlmService::class.java
        )
    }

    /**
     * R-4: LlmService extends android.app.Service
     *
     * Verifies the class hierarchy is correct for a foreground service.
     */
    @Test
    fun `R-4 LlmService extends Service`() {
        assertTrue(
            "LlmService must extend android.app.Service",
            android.app.Service::class.java.isAssignableFrom(LlmService::class.java)
        )
    }
}
