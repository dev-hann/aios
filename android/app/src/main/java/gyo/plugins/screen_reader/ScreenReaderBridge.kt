package gyo.plugins.screen_reader

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.Rect
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import gyo.plugins.bridge.BridgeHandler
import org.json.JSONArray
import org.json.JSONObject

class ScreenReaderBridge(private val context: Context) : BridgeHandler {

    companion object {
        private const val TAG = "AIOS-ScreenReader"

        @Volatile
        var service: AccessibilityService? = null
    }

    override fun handle(method: String, data: JSONObject): Any? {
        return when (method) {
            "read" -> read()
            "find" -> find(data)
            else -> {
                Log.w(TAG, "Unknown method: $method")
                null
            }
        }
    }

    private fun read(): JSONObject {
        val svc = service
        if (svc == null) {
            Log.w(TAG, "read: AccessibilityService not connected")
            return JSONObject().apply {
                put("root", JSONObject.NULL)
                put("windowName", "")
                put("packageName", "")
            }
        }

        val rootNode = svc.rootInActiveWindow
        if (rootNode == null) {
            Log.w(TAG, "read: rootInActiveWindow is null")
            return JSONObject().apply {
                put("root", JSONObject.NULL)
                put("windowName", "")
                put("packageName", "")
            }
        }

        val packageName = rootNode.packageName?.toString() ?: ""
        val windowName = rootNode.window?.let { window ->
            window.title?.toString() ?: ""
        } ?: ""

        return JSONObject().apply {
            put("root", nodeToJson(rootNode))
            put("windowName", windowName)
            put("packageName", packageName)
        }
    }

    private fun find(data: JSONObject): JSONObject {
        val svc = service
        if (svc == null) {
            Log.w(TAG, "find: AccessibilityService not connected")
            return JSONObject().apply {
                put("nodes", JSONArray())
                put("count", 0)
            }
        }

        val query = data.optString("text", "")
        if (query.isEmpty()) {
            Log.w(TAG, "find: text is empty")
            return JSONObject().apply {
                put("nodes", JSONArray())
                put("count", 0)
            }
        }

        val rootNode = svc.rootInActiveWindow
        if (rootNode == null) {
            Log.w(TAG, "find: rootInActiveWindow is null")
            return JSONObject().apply {
                put("nodes", JSONArray())
                put("count", 0)
            }
        }

        val foundNodes = rootNode.findAccessibilityNodeInfosByText(query)
        val resultArray = JSONArray()

        for (node in foundNodes) {
            resultArray.put(nodeToJson(node))
        }

        return JSONObject().apply {
            put("nodes", resultArray)
            put("count", resultArray.length())
        }
    }

    private fun nodeToJson(node: AccessibilityNodeInfo): JSONObject {
        val bounds = Rect()
        node.getBoundsInScreen(bounds)

        val childrenArray = JSONArray()
        val childCount = node.childCount
        for (i in 0 until childCount) {
            val child = node.getChild(i)
            if (child != null) {
                childrenArray.put(nodeToJson(child))
            }
        }

        return JSONObject().apply {
            put("text", node.text?.toString() ?: "")
            put("contentDescription", node.contentDescription?.toString() ?: "")
            put("className", node.className?.toString() ?: "")
            put("bounds", bounds.toShortString())
            put("isClickable", node.isClickable)
            put("isEditable", node.isEditable)
            put("children", childrenArray)
        }
    }
}
