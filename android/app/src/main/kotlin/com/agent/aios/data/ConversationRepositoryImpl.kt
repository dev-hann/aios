package com.agent.aios.data

import android.content.Context
import android.util.Log
import com.agent.aios.domain.model.ConversationMessage
import com.agent.aios.domain.repository.ConversationRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ConversationRepositoryImpl @Inject constructor(
    @ApplicationContext private val context: Context,
) : ConversationRepository {
    private val TAG = "AIOS-ConvStore"
    private val convDir = File(context.filesDir, "conversations")

    private val activeFile: File
        get() = File(convDir, "active.json")

    override fun save(messages: List<ConversationMessage>) {
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

    override fun load(): List<ConversationMessage> {
        try {
            if (!activeFile.exists()) return emptyList()
            val text = activeFile.readText()
            val arr = JSONArray(text)
            val messages = mutableListOf<ConversationMessage>()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                messages.add(
                    ConversationMessage(
                        role = obj.getString("role"),
                        content = obj.getString("content"),
                    ),
                )
            }
            return messages
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load conversation: ${e.message}")
            return emptyList()
        }
    }

    override fun clear() {
        try {
            if (activeFile.exists()) activeFile.delete()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to clear conversation: ${e.message}")
        }
    }

    override fun appendMessage(
        role: String,
        content: String,
    ) {
        val existing = load().toMutableList()
        existing.add(ConversationMessage(role, content))
        save(existing)
    }
}
