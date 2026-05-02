package com.agent.aios.agent.tools

import android.util.Log
import com.agent.aios.AgentEngine
import com.agent.aios.service.AIOSAccessibilityService
import org.json.JSONObject

class ScreenActionTool : AgentEngine.ExtendedTool {
    override val name = "screen_action"
    override val description = "Screen action: tap|long_click|type|scroll|swipe|global. Args: {action, text, content, x, y, direction, global_action}"
    override val parameters = """{"action": "tap|long_click|type|scroll|swipe|global", "text": "string, text of element to click (for tap/long_click)", "content": "string, text to type (for type)", "x": "float, x coordinate (for tap)", "y": "float, y coordinate (for tap)", "direction": "up|down|left|right (for scroll)", "global_action": "back|home|recents|notifications|quick_settings (for global)"}"""

    override fun execute(args: String): String {
        return try {
            val json = JSONObject(args)
            val action = json.optString("action", "").lowercase()

            val service = AIOSAccessibilityService.getInstance()
                ?: return "Error: Accessibility service not enabled"

            when (action) {
                "tap" -> handleTap(service, json)
                "long_click" -> handleLongClick(service, json)
                "type" -> handleType(service, json)
                "scroll" -> handleScroll(service, json)
                "swipe" -> handleSwipe(json)
                "global" -> handleGlobal(service, json)
                else -> "Error: Unknown action '$action'. Use tap, long_click, type, scroll, swipe, or global."
            }
        } catch (e: Exception) {
            Log.e("ScreenAction", "Error: ${e.message}", e)
            "Error: ${e.message}"
        }
    }

    private fun handleTap(service: AIOSAccessibilityService, json: JSONObject): String {
        val text = json.optString("text", "")
        if (text.isNotBlank()) {
            val nodes = service.findNodesByText(text)
            val clickable = nodes.firstOrNull { it.isClickable }
                ?: nodes.firstOrNull()
                ?: return "Element '$text' not found on screen"
            val success = service.clickNode(clickable)
            return if (success) "Tapped on '$text'" else "Failed to tap '$text'"
        }

        val x = json.optDouble("x", -1.0).toFloat()
        val y = json.optDouble("y", -1.0).toFloat()
        if (x >= 0 && y >= 0) {
            val success = service.performTap(x, y)
            return if (success) "Tapped at ($x, $y)" else "Failed to tap at ($x, $y)"
        }

        return "Error: Provide 'text' or 'x'/'y' for tap action"
    }

    private fun handleLongClick(service: AIOSAccessibilityService, json: JSONObject): String {
        val text = json.optString("text", "")
        if (text.isBlank()) return "Error: 'text' required for long_click"
        val nodes = service.findNodesByText(text)
        val node = nodes.firstOrNull { it.isLongClickable } ?: nodes.firstOrNull()
            ?: return "Element '$text' not found"
        val success = service.longClickNode(node)
        return if (success) "Long clicked on '$text'" else "Failed to long click '$text'"
    }

    private fun handleType(service: AIOSAccessibilityService, json: JSONObject): String {
        val content = json.optString("content", "")
        if (content.isBlank()) return "Error: 'content' required for type action"

        val targetText = json.optString("target", "")
        if (targetText.isNotBlank()) {
            val nodes = service.findNodesByText(targetText)
            val editable = nodes.firstOrNull { it.isEditable }
                ?: return "No editable field found near '$targetText'"
            val focus = editable.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_FOCUS)
            val success = service.typeText(editable, content)
            return if (success) "Typed '$content' into '$targetText'" else "Failed to type"
        }

        val root = service.getRootNode()
        if (root != null) {
            val editable = findFocusedEditable(root)
            if (editable != null) {
                val success = service.typeText(editable, content)
                return if (success) "Typed '$content'" else "Failed to type"
            }
        }
        return "Error: No focused editable field found. Use 'target' to specify a field."
    }

    private fun findFocusedEditable(node: android.view.accessibility.AccessibilityNodeInfo): android.view.accessibility.AccessibilityNodeInfo? {
        if (node.isEditable && node.isFocused) return node
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { child ->
                findFocusedEditable(child)?.let { return it }
            }
        }
        return null
    }

    private fun handleScroll(service: AIOSAccessibilityService, json: JSONObject): String {
        val direction = json.optString("direction", "forward")
        val root = service.getRootNode() ?: return "Error: No active window"

        val scrollable = findScrollableNode(root)
        if (scrollable != null) {
            val success = service.scrollNode(scrollable, direction)
            return if (success) "Scrolled $direction" else "Failed to scroll $direction"
        }
        return "No scrollable container found"
    }

    private fun findScrollableNode(node: android.view.accessibility.AccessibilityNodeInfo): android.view.accessibility.AccessibilityNodeInfo? {
        if (node.isScrollable) return node
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { child ->
                findScrollableNode(child)?.let { return it }
            }
        }
        return null
    }

    private fun handleSwipe(json: JSONObject): String {
        val service = AIOSAccessibilityService.getInstance()
            ?: return "Error: Accessibility service not enabled"
        val direction = json.optString("direction", "up")
        val startX = json.optDouble("start_x", 540.0).toFloat()
        val startY = json.optDouble("start_y", 1500.0).toFloat()
        val distance = json.optDouble("distance", 500.0).toFloat()

        val (endX, endY) = when (direction) {
            "up" -> Pair(startX, startY - distance)
            "down" -> Pair(startX, startY + distance)
            "left" -> Pair(startX - distance, startY)
            "right" -> Pair(startX + distance, startY)
            else -> return "Error: direction must be up/down/left/right"
        }
        val success = service.performSwipe(startX, startY, endX, endY)
        return if (success) "Swiped $direction" else "Failed to swipe"
    }

    private fun handleGlobal(service: AIOSAccessibilityService, json: JSONObject): String {
        val action = json.optString("global_action", "")
        if (action.isBlank()) return "Error: 'global_action' required (back, home, recents, notifications, quick_settings)"
        val success = service.performGlobalAction(action)
        return if (success) "Performed global action: $action" else "Failed to perform: $action"
    }
}
