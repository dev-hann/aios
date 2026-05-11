package gyo.plugins.sms_sender

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.database.Cursor
import android.telephony.SmsManager
import android.util.Log
import androidx.core.content.ContextCompat
import gyo.plugins.bridge.BridgeHandler
import org.json.JSONArray
import org.json.JSONObject

class SmsSenderBridge(private val context: Context) : BridgeHandler {

    companion object {
        private const val TAG = "AIOS-SmsSender"
        private const val SMS_INBOX_URI = "content://sms/inbox"
    }

    override fun handle(method: String, data: JSONObject): Any? {
        return when (method) {
            "send" -> send(data)
            "read" -> read(data)
            else -> {
                Log.w(TAG, "Unknown method: $method")
                null
            }
        }
    }

    private fun send(data: JSONObject): Boolean {
        val phoneNumber = data.optString("phoneNumber", "")
        val message = data.optString("message", "")

        if (phoneNumber.isEmpty() || message.isEmpty()) {
            Log.w(TAG, "send: phoneNumber or message is empty")
            return false
        }

        if (!hasSendPermission()) {
            Log.e(TAG, "send: SEND_SMS permission not granted")
            return false
        }

        return try {
            val smsManager = getSmsManager()
            smsManager.sendTextMessage(phoneNumber, null, message, null, null)
            Log.d(TAG, "SMS sent to $phoneNumber")
            true
        } catch (e: Exception) {
            Log.e(TAG, "send: failed to send SMS to $phoneNumber", e)
            false
        }
    }

    @Suppress("TooGenericExceptionCaught")
    private fun read(data: JSONObject): JSONObject {
        val limit = data.optInt("limit", 10).coerceIn(1, 100)

        if (!hasReadPermission()) {
            Log.e(TAG, "read: READ_SMS permission not granted")
            return JSONObject().apply {
                put("messages", JSONArray())
                put("count", 0)
            }
        }

        val messages = JSONArray()

        try {
            val uri = android.net.Uri.parse(SMS_INBOX_URI)
            val cursor: Cursor? = context.contentResolver.query(
                uri,
                arrayOf("_id", "address", "body", "date", "type"),
                null,
                null,
                "date DESC"
            )

            cursor?.use {
                var count = 0
                while (it.moveToNext() && count < limit) {
                    val smsMessage = JSONObject().apply {
                        put("id", it.getString(it.getColumnIndexOrThrow("_id")))
                        put("address", it.getString(it.getColumnIndexOrThrow("address")))
                        put("body", it.getString(it.getColumnIndexOrThrow("body")))
                        put("date", it.getLong(it.getColumnIndexOrThrow("date")))
                        put("type", mapSmsType(it.getInt(it.getColumnIndexOrThrow("type"))))
                    }
                    messages.put(smsMessage)
                    count++
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "read: failed to read SMS", e)
        }

        return JSONObject().apply {
            put("messages", messages)
            put("count", messages.length())
        }
    }

    private fun mapSmsType(type: Int): String {
        return when (type) {
            1 -> "inbox"
            2 -> "sent"
            3 -> "draft"
            4 -> "outbox"
            5 -> "failed"
            6 -> "queued"
            else -> "unknown"
        }
    }

    private fun hasSendPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.SEND_SMS
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasReadPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_SMS
        ) == PackageManager.PERMISSION_GRANTED
    }

    @Suppress("DEPRECATION")
    private fun getSmsManager(): SmsManager {
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java)
        } else {
            SmsManager.getDefault()
        }
    }
}
