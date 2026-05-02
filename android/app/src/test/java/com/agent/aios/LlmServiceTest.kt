package com.agent.aios

import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicReference
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

class LlmServiceTest {

    private lateinit var service: LlmService

    @Before
    fun setUp() {
        service = LlmService()
        service.releaseModel()
    }

    // ========================================================
    // 1. Model lifecycle
    // ========================================================

    @Test
    fun loadModel_validPath_returnsTrue() {
        val result = service.loadModel("/valid/model.gguf", 2048)

        assertTrue(result)
    }

    @Test
    fun loadModel_validPath_isModelLoaded_returnsTrue() {
        service.loadModel("/valid/model.gguf", 2048)

        assertTrue(service.isModelLoaded())
    }

    @Test
    fun loadModel_invalidPath_returnsFalse() {
        val result = service.loadModel("/path/to/bad_file.bin", 2048)

        assertFalse(result)
    }

    @Test
    fun loadModel_invalidPath_isModelLoaded_returnsFalse() {
        service.loadModel("/path/to/bad_file.bin", 2048)

        assertFalse(service.isModelLoaded())
    }

    @Test
    fun getModelInfo_whenModelLoaded_returnsInfo() {
        service.loadModel("/valid/model.gguf", 2048)

        val info = service.getModelInfo()

        assertFalse(info.isEmpty())
        assertNotEquals("No model loaded", info)
    }

    @Test
    fun getModelInfo_whenNoModel_returnsNoModelLoaded() {
        val info = service.getModelInfo()

        assertEquals("No model loaded", info)
    }

    @Test
    fun releaseModel_isModelLoaded_returnsFalse() {
        service.loadModel("/valid/model.gguf", 2048)
        assertTrue(service.isModelLoaded())

        service.releaseModel()

        assertFalse(service.isModelLoaded())
    }

    @Test
    fun releaseModel_clearsAgentEngine() {
        service.loadModel("/valid/model.gguf", 2048)
        assertNotNull(service.getAgentEngine())

        service.releaseModel()

        assertNull(service.getAgentEngine())
    }

    @Test
    fun loadModel_afterRelease_canReload() {
        service.loadModel("/valid/first.gguf", 2048)
        assertTrue(service.isModelLoaded())
        assertNotNull(service.getAgentEngine())

        service.releaseModel()
        assertFalse(service.isModelLoaded())

        service.loadModel("/valid/second.gguf", 4096)
        assertTrue(service.isModelLoaded())
        assertNotNull(service.getAgentEngine())
    }

    // ========================================================
    // 2. Callback management
    // ========================================================

    @Test
    fun setTokenCallback_callbackIsInvoked() {
        var received: String? = null
        val cb: (String) -> Unit = { received = it }

        service.setTokenCallback(cb)

        val bridge = getBridge()
        bridge.onTokenGenerated("test_token")

        assertEquals("test_token", received)
    }

    @Test
    fun setTokenCallback_null_clearsCallback() {
        var called = false
        service.setTokenCallback { called = true }

        service.setTokenCallback(null)

        val bridge = getBridge()
        bridge.onTokenGenerated("test")
        assertFalse(called)
    }

    @Test
    fun swapTokenCallback_returnsOldCallback() {
        var oldReceived: String? = null
        val oldCb: (String) -> Unit = { oldReceived = it }
        service.setTokenCallback(oldCb)

        val returned = service.swapTokenCallback {}

        assertNotNull(returned)
        returned?.invoke("old_test")
        assertEquals("old_test", oldReceived)
    }

    @Test
    fun swapTokenCallback_storesNewCallback() {
        var newReceived: String? = null
        val newCb: (String) -> Unit = { newReceived = it }
        service.setTokenCallback {}

        service.swapTokenCallback(newCb)

        getBridge().onTokenGenerated("new_test")
        assertEquals("new_test", newReceived)
    }

    @Test
    fun swapTokenCallback_withNull_clearsCallback() {
        var oldCalled = false
        service.setTokenCallback { oldCalled = true }

        service.swapTokenCallback(null)

        getBridge().onTokenGenerated("test")
        assertFalse(oldCalled)
    }

    @Test
    fun swapTokenCallback_whenNoExistingCallback_returnsNull() {
        val returned = service.swapTokenCallback {}

        assertNull(returned)
    }

    @Test
    fun concurrentSetTokenCallback_noCrash() {
        val latch = CountDownLatch(10)
        val errors = AtomicReference<Throwable?>(null)

        repeat(10) { i ->
            thread(start = true) {
                try {
                    service.setTokenCallback { _ -> }
                } catch (e: Throwable) {
                    errors.compareAndSet(null, e)
                } finally {
                    latch.countDown()
                }
            }
        }

        assertTrue("Timeout waiting for threads", latch.await(5, TimeUnit.SECONDS))
        assertNull("Concurrent setTokenCallback threw: ${errors.get()}", errors.get())
    }

    @Test
    fun concurrentSwapTokenCallback_noCrash() {
        val latch = CountDownLatch(10)
        val errors = AtomicReference<Throwable?>(null)
        service.setTokenCallback { _ -> }

        repeat(10) {
            thread(start = true) {
                try {
                    service.swapTokenCallback { _ -> }
                } catch (e: Throwable) {
                    errors.compareAndSet(null, e)
                } finally {
                    latch.countDown()
                }
            }
        }

        assertTrue("Timeout waiting for threads", latch.await(5, TimeUnit.SECONDS))
        assertNull("Concurrent swapTokenCallback threw: ${errors.get()}", errors.get())
    }

    // ========================================================
    // 3. Context management
    // ========================================================

    @Test
    fun resetContext_resetsContextUsage() {
        service.loadModel("/valid/model.gguf", 2048)
        service.resetContext()
        val usage = service.getContextUsage()
        assertTrue(usage.startsWith("0/"))

        service.resetContext()

        val after = service.getContextUsage()
        assertTrue(after.startsWith("0/"))
    }

    @Test
    fun getContextUsage_returnsFormattedString() {
        service.loadModel("/valid/model.gguf", 4096)

        val usage = service.getContextUsage()

        assertTrue("Should be N/M format", usage.matches(Regex("\\d+/\\d+")))
    }

    // ========================================================
    // 4. Agent engine
    // ========================================================

    @Test
    fun getAgentEngine_whenModelLoaded_returnsNonNull() {
        service.loadModel("/valid/model.gguf", 2048)

        val engine = service.getAgentEngine()

        assertNotNull(engine)
    }

    @Test
    fun getAgentEngine_whenNoModel_returnsNull() {
        val engine = service.getAgentEngine()

        assertNull(engine)
    }

    @Test
    fun getAgentEngine_afterRelease_returnsNull() {
        service.loadModel("/valid/model.gguf", 2048)
        assertNotNull(service.getAgentEngine())

        service.releaseModel()

        assertNull(service.getAgentEngine())
    }

    @Test
    fun agentEngine_createdWithCorrectTools() {
        service.loadModel("/valid/model.gguf", 2048)

        val engine = service.getAgentEngine()!!
        val manifest = engine.getToolManifest()

        listOf(
            "calculator", "timer", "device_info", "notepad",
            "screen_reader", "screen_action", "app_launcher",
            "notification_reader", "screen_find", "contact_search",
            "sms_sender", "phone_caller"
        ).forEach { tool ->
            assertTrue("Manifest should contain tool: $tool", manifest.contains(tool))
        }
    }

    // ========================================================
    // 5. Thread safety
    // ========================================================

    @Test
    fun setTokenCallback_concurrentCalls_noCrash() {
        val errors = AtomicReference<Throwable?>(null)
        val threads = (1..10).map {
            thread {
                try {
                    service.setTokenCallback { _ -> }
                } catch (e: Throwable) {
                    errors.set(e)
                }
            }
        }
        threads.forEach { it.join(2000) }
        assertNull("Concurrent setTokenCallback threw: ${errors.get()}", errors.get())
    }

    @Test
    fun releaseModel_whileGetAgentEngineCalled_noCrash() {
        service.loadModel("/valid/model.gguf", 2048)
        val latch = CountDownLatch(2)
        val errors = AtomicReference<Throwable?>(null)

        thread(start = true) {
            try {
                repeat(100) { service.getAgentEngine() }
            } catch (e: Throwable) {
                errors.compareAndSet(null, e)
            } finally {
                latch.countDown()
            }
        }

        thread(start = true) {
            try {
                service.releaseModel()
            } catch (e: Throwable) {
                errors.compareAndSet(null, e)
            } finally {
                latch.countDown()
            }
        }

        assertTrue("Timeout", latch.await(5, TimeUnit.SECONDS))
        assertNull("Concurrent release/getAgentEngine threw: ${errors.get()}", errors.get())
    }

    @Test
    fun concurrentLoadAndRelease_noCrash() {
        val iterations = 20
        val latch = CountDownLatch(iterations * 2)
        val errors = AtomicReference<Throwable?>(null)

        repeat(iterations) {
            thread(start = true) {
                try {
                    service.loadModel("/valid/model.gguf", 2048)
                } catch (e: Throwable) {
                    errors.compareAndSet(null, e)
                } finally {
                    latch.countDown()
                }
            }
            thread(start = true) {
                try {
                    service.releaseModel()
                } catch (e: Throwable) {
                    errors.compareAndSet(null, e)
                } finally {
                    latch.countDown()
                }
            }
        }

        assertTrue("Timeout", latch.await(10, TimeUnit.SECONDS))
        assertNull("Concurrent load/release threw: ${errors.get()}", errors.get())
    }

    // ========================================================
    // 6. Edge cases
    // ========================================================

    @Test
    fun multipleLoadModel_secondCallReplacesAgentEngine() {
        service.loadModel("/valid/first.gguf", 2048)
        val firstEngine = service.getAgentEngine()

        service.loadModel("/valid/second.gguf", 4096)
        val secondEngine = service.getAgentEngine()

        assertNotNull(firstEngine)
        assertNotNull(secondEngine)
        assertNotSame("Second load should create new AgentEngine", firstEngine, secondEngine)
    }

    @Test
    fun multipleLoadModel_failureDoesNotClearAgentEngine() {
        service.loadModel("/path/model.gguf", 2048)
        assertNotNull(service.getAgentEngine())
        assertTrue(service.isModelLoaded())

        val result = service.loadModel("/path/to/bad_file.bin", 2048)

        assertFalse(result)
        assertFalse(service.isModelLoaded())
    }

    @Test
    fun releaseModel_whenNoModelLoaded_noCrash() {
        service.releaseModel()

        assertFalse(service.isModelLoaded())
        assertNull(service.getAgentEngine())
    }

    @Test
    fun setSamplingParams_noCrash() {
        service.loadModel("/valid/model.gguf", 2048)
        service.setSamplingParams(0.8f, 50, 0.95f, 1.1f)
    }

    @Test
    fun processPrompt_withoutModel_returnsError() {
        assertFalse(service.isModelLoaded())
    }

    @Test
    fun swapTokenCallback_chainedSwapsPreserveAllCallbacks() {
        var cb1Called = false
        var cb2Called = false
        var cb3Called = false

        service.setTokenCallback { cb1Called = true }
        val old1 = service.swapTokenCallback { cb2Called = true }
        assertNotNull(old1)

        val old2 = service.swapTokenCallback { cb3Called = true }
        assertNotNull(old2)

        old1?.invoke("")
        assertTrue(cb1Called)

        old2?.invoke("")
        assertTrue(cb2Called)

        getBridge().onTokenGenerated("")
        assertTrue(cb3Called)
    }

    private fun getBridge(): LlamaBridge {
        val field = LlmService::class.java.getDeclaredField("llamaBridge")
        field.isAccessible = true
        return field.get(service) as LlamaBridge
    }
}
