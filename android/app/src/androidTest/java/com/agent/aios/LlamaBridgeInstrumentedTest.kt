package com.agent.aios

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.File
import java.io.FileOutputStream

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
    fun testGenerate_noModel() {
        val result = bridge.nativeGenerate("Hello", 32)
        assertTrue("Should return error message", result.contains("Error"))
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
    fun testLoadModel_validModel() {
        val modelsDir = File(context.filesDir, "models")
        modelsDir.mkdirs()
        val modelFile = File(modelsDir, "test.gguf")

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

            val response = bridge.nativeGenerate("Hello", 16)
            assertFalse("Response should not be an error", response.startsWith("Error"))
            assertFalse("Response should not be empty", response.isEmpty())

            bridge.nativeReleaseModel()
            assertFalse(bridge.nativeIsModelLoaded())
        }
    }
}
