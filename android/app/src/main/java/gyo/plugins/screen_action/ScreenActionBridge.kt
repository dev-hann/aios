package gyo.plugins.screen_action

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_BACK
import android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_HOME
import android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_NOTIFICATIONS
import android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_QUICK_SETTINGS
import android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_RECENTS
import android.accessibilityservice.GestureDescription
import android.content.Context
import android.graphics.Path
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import gyo.plugins.bridge.BridgeHandler
import org.json.JSONObject

class ScreenActionBridge(private val context: Context) : BridgeHandler {

    companion object {
        private const val TAG = "AIOS-ScreenAction"

        @Volatile
        private var _service: AccessibilityService? = null

        val service: AccessibilityService? get() = _service

        fun setService(accessibilityService: AccessibilityService) {
            _service = accessibilityService
            Log.d(TAG, "AccessibilityService registered")
        }

        fun clearService() {
            _service = null
            Log.d(TAG, "AccessibilityService cleared")
        }
    }

    override fun handle(method: String, data: JSONObject): Any? {
        return when (method) {
            "tap" -> tap(data)
            "type" -> type(data)
            "swipe" -> swipe(data)
            "global" -> globalAction(data)
            else -> {
                Log.w(TAG, "Unknown method: $method")
                null
            }
        }
    }

    private fun tap(data: JSONObject): Boolean {
        val currentService = service
        if (currentService == null) {
            Log.w(TAG, "tap: AccessibilityService not available")
            return false
        }

        val x = data.optDouble("x", -1.0).toFloat()
        val y = data.optDouble("y", -1.0).toFloat()
        if (x < 0 || y < 0) {
            Log.w(TAG, "tap: invalid coordinates ($x, $y)")
            return false
        }

        val path = Path().apply {
            moveTo(x, y)
        }

        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0L, 50L))
            .build()

        return try {
            val result = BooleanArray(1)
            val callback = object : AccessibilityService.GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    result[0] = true
                }

                override fun onCancelled(gestureDescription: GestureDescription?) {
                    result[0] = false
                }
            }
            currentService.dispatchGesture(gesture, callback, null)
            Log.d(TAG, "tap dispatched at ($x, $y)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "tap: failed", e)
            false
        }
    }

    private fun type(data: JSONObject): Boolean {
        val currentService = service
        if (currentService == null) {
            Log.w(TAG, "type: AccessibilityService not available")
            return false
        }

        val text = data.optString("text", "")
        if (text.isEmpty()) {
            Log.w(TAG, "type: text is empty")
            return false
        }

        val rootNode = currentService.rootInActiveWindow
        if (rootNode == null) {
            Log.w(TAG, "type: no active window")
            return false
        }

        val focusNode = findFocusNode(rootNode)
        if (focusNode != null) {
            val arguments = android.os.Bundle()
            arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
            val result = focusNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
            focusNode.recycle()
            rootNode.recycle()
            Log.d(TAG, "type: ACTION_SET_TEXT result=$result")
            return result
        }

        rootNode.recycle()
        Log.w(TAG, "type: no focused node found")
        return false
    }

    private fun findFocusNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        val focus = node.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        return focus
    }

    private fun swipe(data: JSONObject): Boolean {
        val currentService = service
        if (currentService == null) {
            Log.w(TAG, "swipe: AccessibilityService not available")
            return false
        }

        val startX = data.optDouble("startX", -1.0).toFloat()
        val startY = data.optDouble("startY", -1.0).toFloat()
        val endX = data.optDouble("endX", -1.0).toFloat()
        val endY = data.optDouble("endY", -1.0).toFloat()
        val duration = data.optLong("duration", 300L)

        if (startX < 0 || startY < 0 || endX < 0 || endY < 0) {
            Log.w(TAG, "swipe: invalid coordinates")
            return false
        }

        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(endX, endY)
        }

        val gesture = GestureDescription.Builder()
            .addStroke(
                GestureDescription.StrokeDescription(
                    path, 0L, duration
                )
            )
            .build()

        return try {
            val callback = object : AccessibilityService.GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    Log.d(TAG, "swipe completed")
                }

                override fun onCancelled(gestureDescription: GestureDescription?) {
                    Log.w(TAG, "swipe cancelled")
                }
            }
            currentService.dispatchGesture(gesture, callback, null)
            Log.d(TAG, "swipe dispatched from ($startX,$startY) to ($endX,$endY)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "swipe: failed", e)
            false
        }
    }

    private fun globalAction(data: JSONObject): Boolean {
        val currentService = service
        if (currentService == null) {
            Log.w(TAG, "global: AccessibilityService not available")
            return false
        }

        val action = data.optString("action", "").lowercase()
        val globalActionId = when (action) {
            "back" -> GLOBAL_ACTION_BACK
            "home" -> GLOBAL_ACTION_HOME
            "recents" -> GLOBAL_ACTION_RECENTS
            "notifications" -> GLOBAL_ACTION_NOTIFICATIONS
            "quick_settings" -> GLOBAL_ACTION_QUICK_SETTINGS
            "power_dialog" -> if (Build.VERSION.SDK_INT >= 33) AccessibilityService.GLOBAL_ACTION_POWER_DIALOG else null
            else -> {
                Log.w(TAG, "global: unknown action '$action'")
                return false
            }
        }

        if (globalActionId == null) {
            Log.w(TAG, "global: '$action' not supported on API ${Build.VERSION.SDK_INT}")
            return false
        }

        val result = currentService.performGlobalAction(globalActionId)
        Log.d(TAG, "global: action='$action' result=$result")
        return result
    }
}
