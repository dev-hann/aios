package gyo.plugins.phone_caller

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.CallLog
import android.util.Log
import gyo.plugins.bridge.BridgeHandler
import org.json.JSONArray
import org.json.JSONObject

class PhoneCallerBridge(private val context: Context) : BridgeHandler {

    companion object {
        private const val TAG = "AIOS-PhoneCaller"
    }

    override fun handle(method: String, data: JSONObject): Any? {
        return when (method) {
            "call" -> call(data)
            "get_call_log" -> getCallLog(data)
            else -> {
                Log.w(TAG, "Unknown method: $method")
                null
            }
        }
    }

    private fun call(data: JSONObject): Boolean {
        val phoneNumber = data.optString("phoneNumber", "")
        if (phoneNumber.isEmpty()) {
            Log.w(TAG, "call: phoneNumber is empty")
            return false
        }

        val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$phoneNumber")).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        return try {
            context.startActivity(intent)
            Log.d(TAG, "Calling: $phoneNumber")
            true
        } catch (e: SecurityException) {
            Log.e(TAG, "call: no CALL_PHONE permission for $phoneNumber", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "call: failed to call $phoneNumber", e)
            false
        }
    }

    private fun getCallLog(data: JSONObject): JSONObject {
        val limit = data.optInt("limit", 20)
        val entries = JSONArray()

        try {
            val cursor = context.contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(
                    CallLog.Calls.NUMBER,
                    CallLog.Calls.CACHED_NAME,
                    CallLog.Calls.DATE,
                    CallLog.Calls.DURATION,
                    CallLog.Calls.TYPE
                ),
                null,
                null,
                "${CallLog.Calls.DATE} DESC"
            )

            cursor?.use {
                var count = 0
                while (it.moveToNext() && count < limit) {
                    val number = it.getString(0) ?: ""
                    val name = it.getString(1) ?: ""
                    val date = it.getLong(2)
                    val duration = it.getLong(3)
                    val typeInt = it.getInt(4)
                    val type = when (typeInt) {
                        CallLog.Calls.INCOMING_TYPE -> "INCOMING"
                        CallLog.Calls.OUTGOING_TYPE -> "OUTGOING"
                        CallLog.Calls.MISSED_TYPE -> "MISSED"
                        CallLog.Calls.REJECTED_TYPE -> "REJECTED"
                        CallLog.Calls.BLOCKED_TYPE -> "BLOCKED"
                        else -> "UNKNOWN"
                    }

                    val entry = JSONObject().apply {
                        put("number", number)
                        put("name", name)
                        put("date", date)
                        put("duration", duration)
                        put("type", type)
                    }
                    entries.put(entry)
                    count++
                }
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "get_call_log: no READ_CALL_LOG permission", e)
        } catch (e: Exception) {
            Log.e(TAG, "get_call_log: failed to query call log", e)
        }

        return JSONObject().apply {
            put("entries", entries)
            put("count", entries.length())
        }
    }
}
