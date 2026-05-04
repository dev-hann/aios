package com.agent.aios.agent.tools

import android.util.Log
import com.agent.aios.domain.ToolContext
import org.json.JSONObject

class ScreenReaderTool : ExtendedTool {
    private val TAG = "AIOS-ScreenReader"

    override val name = "screen_reader"
    override val description = "Read all visible text on screen. Args: {}"
    override val parameters = """{}"""

    override fun execute(
        args: String,
        toolContext: ToolContext,
    ): String {
        return try {
            val service = toolContext.accessibilityService()
            if (service == null) {
                "Error: Accessibility service not enabled. Please enable it in Settings > Accessibility."
            } else {
                val text = service.getScreenText()
                if (text.isBlank()) "Screen appears to be empty or no readable content found." else text
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error: ${e.message}", e)
            "Error: ${e.message}"
        }
    }
}

class ScreenFindTool : ExtendedTool {
    override val name = "screen_find"
    override val description = "Find UI elements by text. Args: {text}"
    override val parameters = """{"text": "string, text to search for on screen"}"""

    override fun execute(
        args: String,
        toolContext: ToolContext,
    ): String {
        return try {
            val json = JSONObject(args)
            val searchText = json.optString("text", "")
            if (searchText.isBlank()) return "Error: 'text' parameter required"

            val service =
                toolContext.accessibilityService()
                    ?: return "Error: Accessibility service not enabled"

            val nodes = service.findNodesByText(searchText)
            if (nodes.isEmpty()) {
                "No elements found matching '$searchText'"
            } else {
                nodes.take(10).mapIndexed { i, node ->
                    "${i + 1}. ${service.getNodeInfo(node)}"
                }.joinToString("\n")
            }
        } catch (e: Exception) {
            "Error: ${e.message}"
        }
    }
}
