package com.agent.aios

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AgentToolsInstrumentedTest {

    @Test
    fun calculatorAddition() {
        val tool = CalculatorTool()
        val result = tool.execute("""{"expression": "2+3"}""")
        val value = result.replace(",", ".").toDouble()
        assertEquals(5.0, value, 0.01)
    }

    @Test
    fun calculatorMultiplication() {
        val tool = CalculatorTool()
        val result = tool.execute("""{"expression": "25*37"}""")
        val value = result.replace(",", ".").toDouble()
        assertEquals(925.0, value, 0.01)
    }

    @Test
    fun calculatorComplex() {
        val tool = CalculatorTool()
        val result = tool.execute("""{"expression": "123*456+789"}""")
        val value = result.replace(",", ".").toDouble()
        assertEquals(56877.0, value, 0.01)
    }

    @Test
    fun calculatorRejectsInvalid() {
        val tool = CalculatorTool()
        val result = tool.execute("""{"expression": "abc"}""")
        assertTrue(result.contains("Error"))
    }

    @Test
    fun deviceInfoReturnsDeviceModel() {
        val tool = DeviceInfoTool()
        val result = tool.execute("{}")
        val json = JSONObject(result)
        assertEquals("SM-F741N", json.getString("device"))
        assertTrue(json.has("android_version"))
    }

    @Test
    fun notepadSaveGetDelete() {
        val notes = mutableMapOf<String, String>()
        val tool = NotePadTool(notes)
        assertEquals("Saved note 'x'", tool.execute("""{"action":"save","key":"x","value":"hello"}"""))
        assertEquals("hello", tool.execute("""{"action":"get","key":"x"}"""))
        assertEquals("Deleted note 'x'", tool.execute("""{"action":"delete","key":"x"}"""))
        assertEquals("Note 'x' not found", tool.execute("""{"action":"get","key":"x"}"""))
    }

    @Test
    fun notepadList() {
        val notes = mutableMapOf<String, String>()
        val tool = NotePadTool(notes)
        assertEquals("No notes saved", tool.execute("""{"action":"list"}"""))
        tool.execute("""{"action":"save","key":"a","value":"1"}""")
        val result = tool.execute("""{"action":"list"}""")
        assertTrue(result.contains("a"))
    }

    @Test
    fun timerRejectsInvalid() {
        val tool = TimerTool()
        val result = tool.execute("""{"seconds": 0}""")
        assertTrue(result.contains("Error"))
        val result2 = tool.execute("""{"seconds": -5}""")
        assertTrue(result2.contains("Error"))
    }
}
