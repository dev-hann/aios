package com.agent.aios

import android.util.Log
import com.agent.aios.domain.LlmProvider

class PromptBuilder(private val llmProvider: LlmProvider) {
    private val TAG = "AIOS-Prompt"

    private val history: MutableList<Pair<String, String>> = mutableListOf()

    fun buildSystemPrompt(toolManifest: String): String {
        return """You are AIOS, an AI assistant on an Android phone. You can use tools or answer directly.

AVAILABLE TOOLS:
$toolManifest

OUTPUT FORMAT:
- To use a tool, output exactly:
  Action: tool_name
  Args: {"param": "value"}
- To give your final answer, output exactly:
  Answer: your response here
- For simple questions you can answer without tools, just use Answer: directly.

IMPORTANT RULES:
1. You have at most 3 tool uses per request. After receiving tool results, you MUST give a final Answer.
2. Only use tools when you need information from the device or need to perform an action.
3. For questions you can answer from your own knowledge (math, general knowledge, conversation), use Answer: directly without tools.
4. After you receive a tool result (Observation), decide: do I have enough information to answer? If yes, output Answer:. If no, use one more tool.
5. Be concise. Answer in the same language the user writes in."""
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
        llmProvider.resetContext()
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
