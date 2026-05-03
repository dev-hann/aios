package com.agent.aios.service

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import dagger.hilt.android.AndroidEntryPoint
import org.json.JSONArray
import org.json.JSONObject
import javax.inject.Inject

@AndroidEntryPoint
class NotificationListener : NotificationListenerService() {
    private val TAG = "AIOS-Notif"

    @Inject
    lateinit var serviceRegistry: ServiceRegistry

    companion object {
        private var instance: NotificationListener? = null

        fun getInstance(): NotificationListener? = instance

        fun getRecentNotifications(maxCount: Int = 20): String {
            val svc = instance ?: return "Error: Notification listener not active"
            val notifications = svc.activeNotifications?.take(maxCount) ?: return "No notifications"
            val arr = JSONArray()
            for (sbn in notifications) {
                val obj =
                    JSONObject().apply {
                        put("package", sbn.packageName)
                        put("postTime", sbn.postTime)
                        val extras = sbn.notification?.extras
                        if (extras != null) {
                            put("title", extras.getCharSequence("android.title")?.toString() ?: "")
                            put("text", extras.getCharSequence("android.text")?.toString() ?: "")
                            put("bigText", extras.getCharSequence("android.bigText")?.toString() ?: "")
                        }
                    }
                arr.put(obj)
            }
            return arr.toString(2)
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        serviceRegistry.setNotificationService(this)
        Log.i(TAG, "Notification listener connected")
    }

    override fun onListenerDisconnected() {
        instance = null
        serviceRegistry.setNotificationService(null)
        super.onListenerDisconnected()
        Log.i(TAG, "Notification listener disconnected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val extras = sbn?.notification?.extras ?: return
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        Log.d(TAG, "Notification: [${sbn.packageName}] $title: $text")
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // no-op
    }
}
