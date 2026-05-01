package com.agent.aios.data

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

data class ConversationMessage(
    val role: String,
    val content: String,
)

class ConversationStore(private val context: Context) {

    private val TAG = "AIOS-ConvStore"
    private val convDir = File(context.filesDir, "conversations")

    private val activeFile: File
        get() = File(convDir, "active.json")

    fun save(messages: List<ConversationMessage>) {
        try {
            convDir.mkdirs()
            val arr = JSONArray()
            for (msg in messages) {
                val obj = JSONObject()
                obj.put("role", msg.role)
                obj.put("content", msg.content)
                arr.put(obj)
            }
            activeFile.writeText(arr.toString(2))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save conversation: ${e.message}")
        }
    }

    fun load(): List<ConversationMessage> {
        try {
            if (!activeFile.exists()) return emptyList()
            val text = activeFile.readText()
            val arr = JSONArray(text)
            val messages = mutableListOf<ConversationMessage>()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                messages.add(ConversationMessage(
                    role = obj.getString("role"),
                    content = obj.getString("content"),
                ))
            }
            return messages
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load conversation: ${e.message}")
            return emptyList()
        }
    }

    fun clear() {
        try {
            if (activeFile.exists()) activeFile.delete()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to clear conversation: ${e.message}")
        }
    }

    fun appendMessage(role: String, content: String) {
        val existing = load().toMutableList()
        existing.add(ConversationMessage(role, content))
        save(existing)
    }
}
