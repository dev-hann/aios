package com.agent.aios

import android.content.Context
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Test
import java.io.File

class LlamaBridgeInstrumentedTest {
    private lateinit var context: Context
    private lateinit var bridge: LlamaBridge

    @Before
    fun setup() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        bridge = LlamaBridge()
    }

    @Test
    fun testLibraryLoaded() {
        assertNotNull("LlamaBridge should be instantiated (library loaded)", bridge)
    }

    @Test
    fun testIsModelLoaded_initiallyFalse() {
        assertFalse("Model should not be loaded initially", bridge.nativeIsModelLoaded())
    }

    @Test
    fun testGetModelInfo_noModel() {
        val info = bridge.nativeGetModelInfo()
        assertEquals("No model loaded", info)
    }

    @Test
    fun testInfer_noModel() {
        val result = bridge.nativeInfer("Hello", 32)
        assertEquals("Should return -1 for no model", -1, result)
    }

    @Test
    fun testReleaseModel_noModel() {
        bridge.nativeReleaseModel()
        assertFalse(bridge.nativeIsModelLoaded())
    }

    @Test
    fun testLoadModel_invalidPath() {
        val result = bridge.nativeLoadModel("/nonexistent/model.gguf", 512)
        assertFalse("Should fail for nonexistent file", result)
    }

    @Test
    fun testFormatChat_noModel() {
        val result = bridge.nativeFormatChat(arrayOf("user"), arrayOf("Hello"))
        assertEquals("Should return empty string for no model", "", result)
    }

    @Test
    fun testLoadModel_validModel() {
        val modelsDir = File(context.filesDir, "models")
        modelsDir.mkdirs()

        val assets = InstrumentationRegistry.getInstrumentation().context.assets
        val assetFiles = assets.list("") ?: emptyArray()
        val modelAsset = assetFiles.find { it.endsWith(".gguf") }

        if (modelAsset == null) {
            println("[SKIP] No GGUF model in assets, using first available model")
            val existing = modelsDir.listFiles()?.filter { it.extension == "gguf" && it.length() > 1_000_000 }
            if (existing.isNullOrEmpty()) {
                println("[SKIP] No model file available for test")
                return
            }
            val loaded = bridge.nativeLoadModel(existing.first().absolutePath, 512)
            assertTrue("Model should load successfully", loaded)
            assertTrue("Model should be loaded", bridge.nativeIsModelLoaded())

            val info = bridge.nativeGetModelInfo()
            assertFalse("Model info should not be empty", info.isEmpty())
            assertFalse("Model info should not say 'No model'", info.startsWith("No"))

            val formatted =
                bridge.nativeFormatChat(
                    arrayOf("user"),
                    arrayOf("Hello"),
                )
            assertFalse("Formatted chat should not be empty", formatted.isEmpty())

            bridge.nativeResetContext()
            val tokenCount = bridge.nativeInfer("Hello, how are you?", 16)
            assertTrue("Should generate some tokens", tokenCount > 0)

            bridge.nativeReleaseModel()
            assertFalse(bridge.nativeIsModelLoaded())
        }
    }
}
