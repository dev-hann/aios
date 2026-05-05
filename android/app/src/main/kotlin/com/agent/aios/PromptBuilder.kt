package com.agent.aios

import android.util.Log
import com.agent.aios.domain.LlmProvider

class PromptBuilder(private val llmProvider: LlmProvider) {
    private val TAG = "AIOS-Prompt"

    private val history: MutableList<Pair<String, String>> = mutableListOf()
    private var processedHistoryIndex: Int = 0

    fun buildSystemPrompt(toolManifest: String): String {
        return """You are AIOS, an AI assistant on an Android phone. You can use tools or answer directly.

TOOLS:
$toolManifest

FORMAT:
- Tool: Action: tool_name\nArgs: {"param": "value"}
- Answer: Answer: your response

RULES:
1. Max 3 tool calls per request, then Answer.
2. Use tools only for device actions/info. Answer directly from knowledge otherwise.
3. Be concise. Match user's language."""
    }

    fun formatChat(messages: List<Pair<String, String>>): String {
        val roles = messages.map { it.first }.toTypedArray()
        val contents = messages.map { it.second }.toTypedArray()
        return llmProvider.formatChat(roles, contents)
    }

    fun buildPromptForInfer(systemPrompt: String): String {
        val allMessages = mutableListOf<Pair<String, String>>()
        allMessages.add("system" to systemPrompt)
        allMessages.addAll(history)
        return formatChat(allMessages)
    }

    fun addUserMessage(content: String) {
        history.add("user" to content)
    }

    fun addAssistantMessage(content: String) {
        history.add("assistant" to content)
    }

    fun addObservation(content: String) {
        history.add("user" to content)
    }

    fun getHistory(): List<Pair<String, String>> = history.toList()

    fun clearHistory() {
        history.clear()
        processedHistoryIndex = 0
        llmProvider.resetContext()
    }

    fun buildDeltaPrompt(): String? {
        val unprocessed = history.drop(processedHistoryIndex)
        if (unprocessed.isEmpty()) return null
        return formatChat(unprocessed)
    }

    fun markAllProcessed() {
        processedHistoryIndex = history.size
    }

    fun resetProcessedIndex() {
        processedHistoryIndex = 0
    }

    fun trimIfNeeded(): Boolean {
        val usage = llmProvider.getContextUsage()
        val parts = usage.split("/")
        if (parts.size != 2) return false
        val used = parts[0].toIntOrNull() ?: return false
        val total = parts[1].toIntOrNull() ?: return false
        if (total == 0) return false

        val usageRatio = used.toFloat() / total.toFloat()
        if (usageRatio > 0.8f && history.size > 4) {
            val toRemove = history.size / 4
            var removed = 0
            var idx = 0
            while (removed < toRemove && idx < history.size) {
                if (history.size <= 2) break
                if (idx == 0 && history[0].first == "user") {
                    idx++
                    continue
                }
                history.removeAt(idx)
                removed++
            }
            llmProvider.resetContext()
            Log.i(TAG, "Trimmed history: removed $removed entries, ratio was $usageRatio")
            return true
        }
        return false
    }
}
