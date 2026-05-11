package gyo.plugins.screen_find

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.Rect
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import gyo.plugins.bridge.BridgeHandler
import org.json.JSONArray
import org.json.JSONObject

class ScreenFindBridge(private val context: Context) : BridgeHandler {

    companion object {
        private const val TAG = "AIOS-ScreenFind"

        @Volatile
        var accessibilityService: AccessibilityService? = null
    }

    override fun handle(method: String, data: JSONObject): Any? {
        return when (method) {
            "find_by_text" -> findByText(data)
            "find_by_id" -> findById(data)
            else -> {
                Log.w(TAG, "Unknown method: $method")
                null
            }
        }
    }

    private fun findByText(data: JSONObject): JSONObject {
        val service = accessibilityService
        if (service == null) {
            Log.w(TAG, "findByText: AccessibilityService not available")
            return emptyResult()
        }

        val text = data.optString("text", "")
        val exact = data.optBoolean("exact", false)

        if (text.isEmpty()) {
            Log.w(TAG, "findByText: text is empty")
            return emptyResult()
        }

        val root = service.rootInActiveWindow
        if (root == null) {
            Log.w(TAG, "findByText: rootInActiveWindow is null")
            return emptyResult()
        }

        val nodes = root.findAccessibilityNodeInfosByText(text)
        val resultArray = JSONArray()

        for (node in nodes) {
            if (exact && node.text?.toString() != text) {
                node.recycle()
                continue
            }
            resultArray.put(nodeToElementInfo(node))
            node.recycle()
        }

        root.recycle()

        return JSONObject().apply {
            put("elements", resultArray)
            put("count", resultArray.length())
        }
    }

    private fun findById(data: JSONObject): JSONObject {
        val service = accessibilityService
        if (service == null) {
            Log.w(TAG, "findById: AccessibilityService not available")
            return emptyResult()
        }

        val id = data.optString("id", "")
        if (id.isEmpty()) {
            Log.w(TAG, "findById: id is empty")
            return emptyResult()
        }

        val root = service.rootInActiveWindow
        if (root == null) {
            Log.w(TAG, "findById: rootInActiveWindow is null")
            return emptyResult()
        }

        val nodes = root.findAccessibilityNodeInfosByViewId(id)
        val resultArray = JSONArray()

        for (node in nodes) {
            resultArray.put(nodeToElementInfo(node))
            node.recycle()
        }

        root.recycle()

        return JSONObject().apply {
            put("elements", resultArray)
            put("count", resultArray.length())
        }
    }

    private fun nodeToElementInfo(node: AccessibilityNodeInfo): JSONObject {
        val bounds = Rect()
        node.getBoundsInScreen(bounds)

        return JSONObject().apply {
            put("text", node.text?.toString() ?: "")
            put("contentDescription", node.contentDescription?.toString() ?: "")
            put("className", node.className?.toString() ?: "")
            put("bounds", bounds.toShortString())
            put("isClickable", node.isClickable)
            put("isFocusable", node.isFocusable)
            put("isEditable", node.isEditable)
            put("centerX", bounds.centerX())
            put("centerY", bounds.centerY())
        }
    }

    private fun emptyResult(): JSONObject {
        return JSONObject().apply {
            put("elements", JSONArray())
            put("count", 0)
        }
    }
}
