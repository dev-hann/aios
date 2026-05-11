package gyo.plugins.bridge

import android.util.Log
import android.webkit.JavascriptInterface
import android.webkit.WebView
import org.json.JSONObject

class AndroidBridgeInterface(private val webView: WebView) {
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())

    @JavascriptInterface
    fun postMessage(message: String) {
        try {
            val request = JSONObject(message)
            val bridgeName = request.getString("bridgeName")
            val methodName = request.getString("methodName")
            val callbackId = request.getString("callbackId")
            val data = request.optJSONObject("data") ?: JSONObject()

            Log.d("AIOS-Bridge", "Received: bridge=$bridgeName, method=$methodName")

            val bridgeHandler = BridgeRegistry.get(bridgeName)
            if (bridgeHandler == null) {
                rejectCallback(callbackId, "Bridge '$bridgeName' not found")
                return
            }

            Thread {
                try {
                    val result = bridgeHandler.handle(methodName, data)
                    resolveCallback(callbackId, result)
                } catch (e: Exception) {
                    Log.e("AIOS-Bridge", "Error handling $bridgeName.$methodName", e)
                    rejectCallback(callbackId, e.message ?: "Unknown error")
                }
            }.start()
        } catch (e: Exception) {
            Log.e("AIOS-Bridge", "Error parsing bridge message", e)
        }
    }

    private fun resolveCallback(callbackId: String, result: Any?) {
        val resultJson = when (result) {
            is Map<*, *> -> JSONObject(result as Map<String, Any?>).toString()
            is JSONObject -> result.toString()
            is String -> JSONObject.quote(result)
            is Number, is Boolean -> result.toString()
            null -> "null"
            else -> JSONObject.quote(result.toString())
        }

        handler.post {
            webView.evaluateJavascript("window.gyoBridge.resolve('$callbackId', $resultJson);", null)
        }
    }

    private fun rejectCallback(callbackId: String, error: String) {
        val escapedError = error.replace("'", "\\'")
        handler.post {
            webView.evaluateJavascript("window.gyoBridge.reject('$callbackId', '$escapedError');", null)
        }
    }

    fun publish(bridgeName: String, data: Any?) {
        val dataJson = when (data) {
            is Map<*, *> -> JSONObject(data as Map<String, Any?>).toString()
            is JSONObject -> data.toString()
            is String -> JSONObject.quote(data)
            is Number, is Boolean -> data.toString()
            null -> "null"
            else -> JSONObject.quote(data.toString())
        }

        handler.post {
            webView.evaluateJavascript("window.gyoBridge.publish('$bridgeName', $dataJson);", null)
        }
    }
}
