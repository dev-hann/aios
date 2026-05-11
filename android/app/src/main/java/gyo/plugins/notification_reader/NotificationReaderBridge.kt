package gyo.plugins.notification_reader

import android.content.Context
import android.service.notification.StatusBarNotification
import android.util.Log
import gyo.plugins.bridge.BridgeHandler
import org.json.JSONArray
import org.json.JSONObject

class NotificationReaderBridge(private val context: Context) : BridgeHandler {

    companion object {
        private const val TAG = "AIOS-NotificationReader"
    }

    override fun handle(method: String, data: JSONObject): Any? {
        return when (method) {
            "list" -> listNotifications()
            else -> {
                Log.w(TAG, "Unknown method: $method")
                null
            }
        }
    }

    private fun listNotifications(): JSONObject {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as android.app.NotificationManager

        val notifArray = JSONArray()

        try {
            val activeNotifications: Array<StatusBarNotification> = nm.activeNotifications

            for (sbn in activeNotifications) {
                val notification = sbn.notification
                val extras = notification.extras

                val title = extras.getCharSequence(
                    android.app.Notification.EXTRA_TITLE, ""
                )?.toString() ?: ""

                val text = extras.getCharSequence(
                    android.app.Notification.EXTRA_TEXT, ""
                )?.toString() ?: ""

                val notifInfo = JSONObject().apply {
                    put("packageName", sbn.packageName)
                    put("title", title)
                    put("text", text)
                    put("postTime", sbn.postTime)
                    put("category", notification.category ?: "")
                }
                notifArray.put(notifInfo)
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Notification listener access not granted", e)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read notifications", e)
        }

        return JSONObject().apply {
            put("notifications", notifArray)
            put("count", notifArray.length())
        }
    }
}
