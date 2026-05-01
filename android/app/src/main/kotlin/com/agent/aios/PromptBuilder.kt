package com.agent.aios

import android.util.Log

class PromptBuilder(private val service: LlmService) {

    private val TAG = "AIOS-Prompt"

    private val history: MutableList<Pair<String, String>> = mutableListOf()

    fun buildSystemPrompt(toolManifest: String): String {
        return """You are AIOS, a helpful AI assistant that can think and use tools to help the user. You can control the user's Android phone when needed.

AVAILABLE TOOLS:
$toolManifest

INSTRUCTIONS:
- Think step by step about what to do
- If you need to use a tool, respond with EXACTLY this format:
  Action: tool_name
  Args: {"param": "value"}
- If you know the answer directly, respond with EXACTLY this format:
  Answer: your response here
- You can use multiple tools in sequence
- After receiving an Observation, either use another tool or give your final Answer
- Be concise and accurate
- For math calculations, always use the calculator tool
- To interact with the phone, first use screen_reader to see what's on screen, then use screen_action to tap/type/scroll
- To open an app, use app_launcher with open_app action
- To read notifications, use notification_reader
- When searching for UI elements, use screen_find first, then screen_action to interact with them
- To search contacts by name or phone number, use contact_search
- To send an SMS, use sms_sender with action "send", providing "to" (phone number) and "body" (message text)
- To read recent SMS messages, use sms_sender with action "read"
- To make a phone call, use phone_caller with action "call" (requires permission) or "dial" (opens dialer)
- Common app package names: com.google.android.apps.messaging (Messages), com.google.android.dialer (Phone), com.google.android.apps.photos (Photos), com.android.settings (Settings), com.android.chrome (Chrome)"""
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

    fun trimIfNeeded() {
        val usage = service.getContextUsage()
        val parts = usage.split("/")
        if (parts.size != 2) return
        val used = parts[0].toIntOrNull() ?: return
        val total = parts[1].toIntOrNull() ?: return
        if (total == 0) return

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
        }
    }
}
