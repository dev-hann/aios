package com.agent.aios

import android.content.Context
import android.os.Environment
import android.util.Log
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.FixMethodOrder
import org.junit.Test
import org.junit.runners.MethodSorters
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

@FixMethodOrder(MethodSorters.NAME_ASCENDING)
class NativeInferenceTest {
    companion object {
        private const val TAG = "AIOS-NativeTest"
        private const val TEST_MODEL_URL =
            "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q2_k.gguf"
        private const val TEST_MODEL_FILENAME = "qwen2.5-0.5b-instruct-q2_k.gguf"
        private const val TEST_CONTEXT_SIZE = 512
        private const val DOWNLOAD_BUFFER_SIZE = 8192

        private var cachedModelPath: String? = null
    }

    private lateinit var context: Context
    private lateinit var bridge: LlamaBridge

    @Before
    fun setup() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        bridge = LlamaBridge()
    }

    @After
    fun teardown() {
        try {
            bridge.nativeReleaseModel()
        } catch (_: Exception) {
        }
    }

    private fun findOrDownloadModel(): File {
        val modelsDir = File(context.filesDir, "models")
        modelsDir.mkdirs()

        val existing =
            modelsDir.listFiles()
                ?.filter { it.extension == "gguf" && it.length() > 1_000_000 }
                ?.maxByOrNull { it.length() }

        if (existing != null) {
            Log.i(TAG, "Using existing model: ${existing.name} (${existing.length()} bytes)")
            cachedModelPath = existing.absolutePath
            return existing
        }

        val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val downloaded =
            downloadDir.listFiles()
                ?.filter { it.name.endsWith(".gguf") && it.length() > 1_000_000 }
                ?.maxByOrNull { it.length() }

        if (downloaded != null) {
            Log.i(TAG, "Using downloaded model: ${downloaded.name}")
            val target = File(modelsDir, downloaded.name)
            if (!target.exists()) {
                downloaded.inputStream().use { input ->
                    target.outputStream().use { output ->
                        input.copyTo(output, DOWNLOAD_BUFFER_SIZE)
                    }
                }
            }
            cachedModelPath = target.absolutePath
            return target
        }

        val target = File(modelsDir, TEST_MODEL_FILENAME)
        if (target.exists() && target.length() > 1_000_000) {
            Log.i(TAG, "Using previously downloaded test model")
            cachedModelPath = target.absolutePath
            return target
        }

        Log.i(TAG, "No model found. Downloading $TEST_MODEL_FILENAME ...")
        downloadModel(URL(TEST_MODEL_URL), target)
        cachedModelPath = target.absolutePath
        return target
    }

    private fun downloadModel(
        url: URL,
        target: File,
    ) {
        val conn = url.openConnection() as HttpURLConnection
        conn.connectTimeout = 30_000
        conn.readTimeout = 60_000
        conn.instanceFollowRedirects = true

        assertEquals("Download should succeed", 200, conn.responseCode)

        val contentLength = conn.contentLengthLong
        Log.i(TAG, "Downloading ${contentLength / 1024 / 1024}MB ...")

        val tmp = File(target.parent, "${target.name}.tmp")
        var downloaded = 0L
        var lastLog = 0L

        conn.inputStream.use { input ->
            FileOutputStream(tmp).use { output ->
                val buf = ByteArray(DOWNLOAD_BUFFER_SIZE)
                while (true) {
                    val n = input.read(buf)
                    if (n <= 0) break
                    output.write(buf, 0, n)
                    downloaded += n
                    val now = System.currentTimeMillis()
                    if (now - lastLog > 5000) {
                        val pct = if (contentLength > 0) (downloaded * 100 / contentLength) else -1
                        Log.i(TAG, "Download progress: ${downloaded / 1024 / 1024}MB ($pct%)")
                        lastLog = now
                    }
                }
            }
        }

        tmp.renameTo(target)
        Log.i(TAG, "Download complete: ${target.length()} bytes")
        conn.disconnect()
    }

    private fun inferHelper(
        formatted: String,
        maxTokens: Int,
    ): Int {
        bridge.nativeResetContext()
        val procResult = bridge.nativeProcessPrompt(formatted)
        if (procResult != 0) return procResult

        val buffer = StringBuffer()
        repeat(maxTokens) {
            val token = bridge.nativeGenerateOneToken() ?: return@repeat
            if (token.isNotEmpty()) {
                buffer.append(token)
                bridge.onTokenCallback?.invoke(token)
            }
        }
        return buffer.length
    }

    @Test
    fun test01_loadModel_validFile_returnsTrue() {
        val model = findOrDownloadModel()
        val result = bridge.nativeLoadModel(model.absolutePath, TEST_CONTEXT_SIZE)
        assertTrue("Model should load successfully", result)
        assertTrue("Model should be loaded", bridge.nativeIsModelLoaded())
    }

    @Test
    fun test02_loadModel_invalidPath_returnsFalse() {
        val result = bridge.nativeLoadModel("/nonexistent/model.gguf", TEST_CONTEXT_SIZE)
        assertFalse("Should fail for nonexistent file", result)
    }

    @Test
    fun test03_formatChat_basicPrompt_noException() {
        val model = findOrDownloadModel()
        assertTrue(bridge.nativeLoadModel(model.absolutePath, TEST_CONTEXT_SIZE))

        val result =
            bridge.nativeFormatChat(
                arrayOf("system", "user"),
                arrayOf("You are helpful.", "Hello"),
            )
        assertFalse("Formatted chat should not be empty", result.isEmpty())
    }

    @Test
    fun test04_infer_simplePrompt_returnsNonNegative() {
        val model = findOrDownloadModel()
        assertTrue(bridge.nativeLoadModel(model.absolutePath, TEST_CONTEXT_SIZE))

        val formatted =
            bridge.nativeFormatChat(
                arrayOf("user"),
                arrayOf("Say hi"),
            )
        assertFalse(formatted.isEmpty())

        val charCount = inferHelper(formatted, 16)
        assertTrue("Should generate some chars (got $charCount)", charCount > 0)
    }

    @Test
    fun test05_infer_streamingCallback_invoked() {
        val model = findOrDownloadModel()
        assertTrue(bridge.nativeLoadModel(model.absolutePath, TEST_CONTEXT_SIZE))

        val formatted =
            bridge.nativeFormatChat(
                arrayOf("user"),
                arrayOf("Say hello"),
            )

        val tokens = AtomicInteger(0)
        val latch = CountDownLatch(1)
        bridge.onTokenCallback = { _ ->
            tokens.incrementAndGet()
            if (tokens.get() >= 3) latch.countDown()
        }

        inferHelper(formatted, 32)

        latch.await(10, TimeUnit.SECONDS)
        assertTrue("Should receive at least 3 streaming tokens (got ${tokens.get()})", tokens.get() >= 3)
    }

    @Test
    fun test06_infer_contextOverflow_doesNotCrash() {
        val model = findOrDownloadModel()
        assertTrue(bridge.nativeLoadModel(model.absolutePath, TEST_CONTEXT_SIZE))

        val longPrompt = "Repeat: " + "A".repeat(2000)
        val formatted =
            bridge.nativeFormatChat(
                arrayOf("user"),
                arrayOf(longPrompt),
            )

        val result = inferHelper(formatted, 8)
        assertTrue("Should not crash on context overflow", result >= -1)
    }

    @Test
    fun test07_resetContext_thenInfer_worksCorrectly() {
        val model = findOrDownloadModel()
        assertTrue(bridge.nativeLoadModel(model.absolutePath, TEST_CONTEXT_SIZE))

        val formatted1 = bridge.nativeFormatChat(arrayOf("user"), arrayOf("Hello"))
        inferHelper(formatted1, 8)

        val formatted2 = bridge.nativeFormatChat(arrayOf("user"), arrayOf("World"))
        bridge.nativeResetContext()
        val result = inferHelper(formatted2, 8)
        assertTrue("Should generate after reset", result > 0)
    }

    @Test
    fun test08_infer_concurrentCalls_doesNotCrash() {
        val model = findOrDownloadModel()
        assertTrue(bridge.nativeLoadModel(model.absolutePath, TEST_CONTEXT_SIZE))

        val error = AtomicReference<Throwable?>(null)
        val latch = CountDownLatch(2)

        val threads =
            (1..2).map { i ->
                Thread {
                    try {
                        val formatted =
                            bridge.nativeFormatChat(
                                arrayOf("user"),
                                arrayOf("Thread $i says hi"),
                            )
                        inferHelper(formatted, 8)
                    } catch (e: Throwable) {
                        error.set(e)
                    } finally {
                        latch.countDown()
                    }
                }
            }

        threads.forEach { it.start() }
        latch.await(30, TimeUnit.SECONDS)

        assertNull("Concurrent calls should not crash: ${error.get()}", error.get())
    }

    @Test
    fun test09_releaseModel_canReloadAndInfer() {
        val model = findOrDownloadModel()
        assertTrue(bridge.nativeLoadModel(model.absolutePath, TEST_CONTEXT_SIZE))

        bridge.nativeReleaseModel()
        assertFalse(bridge.nativeIsModelLoaded())

        assertTrue(bridge.nativeLoadModel(model.absolutePath, TEST_CONTEXT_SIZE))
        assertTrue(bridge.nativeIsModelLoaded())

        val formatted = bridge.nativeFormatChat(arrayOf("user"), arrayOf("Test"))
        val result = inferHelper(formatted, 8)
        assertTrue("Should infer after reload", result > 0)
    }

    @Test
    fun test10_getContextUsage_reflectsState() {
        val model = findOrDownloadModel()
        assertTrue(bridge.nativeLoadModel(model.absolutePath, TEST_CONTEXT_SIZE))

        val usageBefore = bridge.nativeGetContextUsage()
        assertTrue("Usage format should be N/M", usageBefore.contains("/"))

        val formatted = bridge.nativeFormatChat(arrayOf("user"), arrayOf("Hello"))
        inferHelper(formatted, 8)

        val usageAfter = bridge.nativeGetContextUsage()
        assertTrue("Usage format should be N/M", usageAfter.contains("/"))
    }

    @Test
    fun test11_setSamplingParams_doesNotCrash() {
        val model = findOrDownloadModel()
        assertTrue(bridge.nativeLoadModel(model.absolutePath, TEST_CONTEXT_SIZE))

        bridge.nativeSetSamplingParams(0.5f, 20, 0.8f, 1.2f)

        val formatted = bridge.nativeFormatChat(arrayOf("user"), arrayOf("Hello"))
        val result = inferHelper(formatted, 8)
        assertTrue("Should infer with custom params", result > 0)
    }

    @Test
    fun test12_fullAgentLoop_thinkActObserve_completes() {
        val model = findOrDownloadModel()
        val service = LlmService()
        val loaded = service.loadModel(model.absolutePath, TEST_CONTEXT_SIZE)
        assertTrue("Service should load model", loaded)

        val strategy = com.agent.aios.domain.agent.ReactStrategy(service)

        val steps = mutableListOf<com.agent.aios.domain.model.AgentStep>()
        val result =
            kotlinx.coroutines.runBlocking {
                strategy.execute("What is 2+2?", maxIterations = 2) { step ->
                    steps.add(step)
                }
            }
        assertNotNull("Agent should return result", result)
        assertTrue("Agent should complete with at least 1 step", result.steps.isNotEmpty())

        Log.i(TAG, "Agent completed with ${result.steps.size} steps")
        result.steps.forEach { step ->
            Log.i(TAG, "  ${step.type}: ${step.content.take(80)}")
        }

        service.releaseModel()
    }

    @Test
    fun test13_infer_withSharedFlowCallback_doesNotCrash() {
        val model = findOrDownloadModel()
        assertTrue(bridge.nativeLoadModel(model.absolutePath, TEST_CONTEXT_SIZE))

        val flow = kotlinx.coroutines.flow.MutableSharedFlow<String>(extraBufferCapacity = 64)
        val tokens = AtomicInteger(0)

        bridge.onTokenCallback = { token ->
            flow.tryEmit(token)
            tokens.incrementAndGet()
        }

        val formatted = bridge.nativeFormatChat(arrayOf("user"), arrayOf("Hello"))
        val result = inferHelper(formatted, 16)

        assertTrue("Should not crash with SharedFlow callback (tokens=${tokens.get()})", result >= 0)
        assertTrue("Should have received tokens", tokens.get() > 0)
    }

    @Test
    fun test14_infer_callbackThrowsException_doesNotCrash() {
        val model = findOrDownloadModel()
        assertTrue(bridge.nativeLoadModel(model.absolutePath, TEST_CONTEXT_SIZE))

        var callCount = AtomicInteger(0)
        bridge.onTokenCallback = { _ ->
            callCount.incrementAndGet()
            if (callCount.get() == 3) {
                throw RuntimeException("Simulated callback exception")
            }
        }

        val formatted = bridge.nativeFormatChat(arrayOf("user"), arrayOf("Hello"))
        val result = inferHelper(formatted, 16)

        assertTrue("Should not crash even when callback throws (result=$result)", result >= -1)
    }

    @Test
    fun test15_agentLoop_withStepFlowEmit_doesNotCrash() {
        val model = findOrDownloadModel()
        val service = LlmService()
        assertTrue(service.loadModel(model.absolutePath, TEST_CONTEXT_SIZE))

        val strategy = com.agent.aios.domain.agent.ReactStrategy(service)

        val flow = kotlinx.coroutines.flow.MutableSharedFlow<com.agent.aios.domain.model.AgentStep>(extraBufferCapacity = 64)
        var stepCount = 0

        val result =
            kotlinx.coroutines.runBlocking {
                strategy.execute("Hi", maxIterations = 1) { step ->
                    try {
                        flow.tryEmit(step)
                    } catch (e: Exception) {
                        Log.e(TAG, "Step flow error: ${e.message}")
                    }
                    stepCount++
                }
            }
        assertTrue("Agent should complete without crash (steps=$stepCount)", result.steps.isNotEmpty())

        Log.i(TAG, "AgentLoop with SharedFlow: ${result.steps.size} steps, $stepCount callbacks")
        service.releaseModel()
    }

    @Test
    fun test16_infer_longStreaming_manyTokens_doesNotCrash() {
        val model = findOrDownloadModel()
        assertTrue(bridge.nativeLoadModel(model.absolutePath, 2048))

        val tokens = AtomicInteger(0)
        val exceptions = mutableListOf<Throwable>()

        bridge.onTokenCallback = { _ ->
            try {
                tokens.incrementAndGet()
            } catch (e: Throwable) {
                exceptions.add(e)
            }
        }

        val formatted = bridge.nativeFormatChat(arrayOf("user"), arrayOf("Write a short poem about the moon"))
        val result = inferHelper(formatted, 64)

        assertTrue("Should not crash during long streaming (tokens=${tokens.get()}, result=$result)", result >= 0)
        assertTrue("No exceptions in callback", exceptions.isEmpty())

        Log.i(TAG, "Long streaming: ${tokens.get()} tokens, $result chars")
    }
}
