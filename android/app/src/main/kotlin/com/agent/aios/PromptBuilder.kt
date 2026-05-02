package com.agent.aios

import android.util.Log

class PromptBuilder(private val service: LlmService) {

    private val TAG = "AIOS-Prompt"

    private val history: MutableList<Pair<String, String>> = mutableListOf()

    fun buildSystemPrompt(toolManifest: String): String {
        return """You are AIOS, an AI assistant that can use tools to help the user, including controlling their Android phone.

TOOLS:
$toolManifest

RULES:
- Think step by step
- To use a tool: Action: tool_name\nArgs: {"param": "value"}
- To answer directly: Answer: your response
- After an Observation, use another tool or give your final Answer
- Be concise"""
    }

    fun formatChat(messages: List<Pair<String, String>>): String {
        val roles = messages.map { it.first }.toTypedArray()
        val contents = messages.map { it.second }.toTypedArray()
        return service.formatChat(roles, contents)
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
        service.resetContext()
    }

    fun trimIfNeeded(): Boolean {
        val usage = service.getContextUsage()
        val parts = usage.split("/")
        if (parts.size != 2) return false
        val used = parts[0].toIntOrNull() ?: return false
        val total = parts[1].toIntOrNull() ?: return false
        if (total == 0) return false

        val usageRatio = used.toFloat() / total.toFloat()
        if (usageRatio > 0.8f && history.size > 4) {
            val toRemove = history.size / 4
            repeat(toRemove) {
                if (history.size > 2) {
                    history.removeAt(0)
                }
            }
            service.resetContext()
            Log.i(TAG, "Trimmed history: removed $toRemove entries, ratio was $usageRatio")
            return true
        }
        return false
    }
}
