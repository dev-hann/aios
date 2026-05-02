package com.agent.aios.agent.tools

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import android.telephony.SmsManager
import com.agent.aios.AIOSApp
import com.agent.aios.AgentEngine
import org.json.JSONArray
import org.json.JSONObject

class SmsSenderTool : AgentEngine.ExtendedTool {
    override val name = "sms_sender"
    override val description = "Send/read SMS. Args: {action: send|read, to, body, limit}"
    override val parameters = """{"action": "send|read", "to": "string, phone number (for send)", "body": "string, message text (for send)", "limit": "integer, max messages to return (for read, default 10)"}"""

    override fun execute(args: String): String {
        return try {
            val json = JSONObject(args)
            val action = json.optString("action", "").lowercase()

            when (action) {
                "send" -> sendSms(json)
                "read" -> readSms(json)
                else -> "Error: Unknown action '$action'. Use 'send' or 'read'."
            }
        } catch (e: Exception) {
            "Error: ${e.message}"
        }
    }

    private fun sendSms(json: JSONObject): String {
        val context = AIOSApp.instance
        if (context.checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            return "Error: SEND_SMS permission not granted. Grant it in Phone Control settings."
        }

        val to = json.optString("to", "").trim()
        val body = json.optString("body", "").trim()

        if (to.isBlank()) return "Error: 'to' parameter required (phone number)"
        if (body.isBlank()) return "Error: 'body' parameter required (message text)"

        val smsManager = if (android.os.Build.VERSION.SDK_INT >= 31) {
            context.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
        smsManager.sendTextMessage(to, null, body, null, null)
        return "SMS sent to $to"
    }

    private fun readSms(json: JSONObject): String {
        val context = AIOSApp.instance
        if (context.checkSelfPermission(Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            return "Error: READ_SMS permission not granted. Grant it in Phone Control settings."
        }

        val limit = json.optInt("limit", 10)
        val results = JSONArray()

        val uri = Uri.parse("content://sms/inbox")
        context.contentResolver.query(
            uri,
            arrayOf("address", "body", "date"),
            null,
            null,
            "date DESC"
        )?.use { cursor ->
            var count = 0
            while (cursor.moveToNext() && count < limit) {
                val address = cursor.getString(0) ?: ""
                val body = cursor.getString(1) ?: ""
                val date = cursor.getLong(2)

                val msg = JSONObject()
                msg.put("from", address)
                msg.put("body", body)
                msg.put("date", date)
                results.put(msg)
                count++
            }
        }

        return if (results.length() == 0) {
            "No SMS messages found"
        } else {
            results.toString(2)
        }
    }
}
