package com.agent.aios

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class AIOSAccessibilityService : AccessibilityService() {
    companion object {
        private const val TAG = "AIOS-A11y"
        private var instance: AIOSAccessibilityService? = null
        fun getInstance(): AIOSAccessibilityService? = instance
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(TAG, "Accessibility service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {
        Log.w(TAG, "Accessibility service interrupted")
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    fun getScreenText(): String {
        val root = rootInActiveWindow ?: return "Error: No active window"
        val sb = StringBuilder()
        dumpNodeText(root, 0, sb)
        return sb.toString()
    }

    private fun dumpNodeText(
        node: AccessibilityNodeInfo,
        depth: Int,
        sb: StringBuilder,
    ) {
        if (depth > 30 || sb.length > 8000) return
        val text = node.text
        val contentDesc = node.contentDescription
        if (text != null && text.isNotBlank()) {
            sb.append("[${node.className}] $text")
            if (node.isClickable) sb.append(" (clickable)")
            if (node.isEditable) sb.append(" (editable)")
            val bounds = Rect()
            node.getBoundsInScreen(bounds)
            sb.append(" @(${bounds.left},${bounds.top},${bounds.right},${bounds.bottom})")
            sb.append("\n")
        }
        if (contentDesc != null && contentDesc.isNotBlank() && contentDesc != text?.toString()) {
            sb.append("[${node.className}] desc: $contentDesc\n")
        }
        for (i in 0 until node.childCount) {
            if (sb.length > 8000) return
            node.getChild(i)?.let { dumpNodeText(it, depth + 1, sb) }
        }
    }

    fun findNodesByText(text: String): List<AccessibilityNodeInfo> {
        val root = rootInActiveWindow ?: return emptyList()
        val results = mutableListOf<AccessibilityNodeInfo>()
        findNodesByTextRecursive(root, text, results)
        return results
    }

    private fun findNodesByTextRecursive(
        node: AccessibilityNodeInfo,
        text: String,
        results: MutableList<AccessibilityNodeInfo>,
    ) {
        val nodeText = node.text?.toString() ?: ""
        val contentDesc = node.contentDescription?.toString() ?: ""
        if (nodeText.contains(text, ignoreCase = true) ||
            contentDesc.contains(text, ignoreCase = true)
        ) {
            results.add(node)
        }
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { findNodesByTextRecursive(it, text, results) }
        }
    }

    fun clickNode(node: AccessibilityNodeInfo): Boolean =
        node.performAction(AccessibilityNodeInfo.ACTION_CLICK)

    fun longClickNode(node: AccessibilityNodeInfo): Boolean =
        node.performAction(AccessibilityNodeInfo.ACTION_LONG_CLICK)

    fun typeText(node: AccessibilityNodeInfo, text: String): Boolean {
        val args = android.os.Bundle()
        args.putCharSequence(
            AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
            text,
        )
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    fun scrollNode(node: AccessibilityNodeInfo, direction: String): Boolean {
        val action = when (direction.lowercase()) {
            "forward" -> AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
            "backward" -> AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
            else -> return false
        }
        return node.performAction(action)
    }

    fun performTap(x: Float, y: Float): Boolean {
        val path = Path()
        path.moveTo(x, y)
        val stroke = GestureDescription.StrokeDescription(path, 0, 100)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        return dispatchGesture(gesture, null, null)
    }

    fun performSwipe(
        startX: Float,
        startY: Float,
        endX: Float,
        endY: Float,
        duration: Long = 300,
    ): Boolean {
        val path = Path()
        path.moveTo(startX, startY)
        path.lineTo(endX, endY)
        val stroke = GestureDescription.StrokeDescription(path, 0, duration)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        return dispatchGesture(gesture, null, null)
    }

    fun performGlobalAction(action: String): Boolean {
        val globalAction = when (action.lowercase()) {
            "back" -> GLOBAL_ACTION_BACK
            "home" -> GLOBAL_ACTION_HOME
            "recents" -> GLOBAL_ACTION_RECENTS
            "notifications" -> GLOBAL_ACTION_NOTIFICATIONS
            "quick_settings" -> GLOBAL_ACTION_QUICK_SETTINGS
            "power_dialog" -> GLOBAL_ACTION_POWER_DIALOG
            "lock_screen" -> GLOBAL_ACTION_LOCK_SCREEN
            else -> return false
        }
        return performGlobalAction(globalAction)
    }

    fun pressEnter(): Boolean {
        return try {
            Runtime.getRuntime().exec(arrayOf("input", "keyevent", "KEYCODE_ENTER"))
            true
        } catch (e: Exception) {
            Log.e(TAG, "pressEnter failed: $e")
            false
        }
    }

    fun getNodeInfo(node: AccessibilityNodeInfo): String {
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        return buildString {
            append("class: ${node.className}")
            append(", text: ${node.text}")
            append(", desc: ${node.contentDescription}")
            append(", clickable: ${node.isClickable}")
            append(", editable: ${node.isEditable}")
            append(", enabled: ${node.isEnabled}")
            append(", bounds: [${bounds.left},${bounds.top},${bounds.right},${bounds.bottom}]")
        }
    }
}
