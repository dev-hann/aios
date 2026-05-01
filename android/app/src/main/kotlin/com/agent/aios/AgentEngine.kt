package com.agent.aios

import android.util.Log
import com.agent.aios.agent.tools.AppLauncherTool
import com.agent.aios.agent.tools.NotificationTool
import com.agent.aios.agent.tools.ScreenActionTool
import com.agent.aios.agent.tools.ScreenFindTool
import com.agent.aios.agent.tools.ScreenReaderTool
import org.json.JSONObject

data class AgentStep(
    val type: String,
    val content: String,
    val toolName: String = "",
    val toolArgs: String = "",
    val toolResult: String = ""
)

class AgentEngine(private val service: LlmService) {

    private val TAG = "AIOS-Agent"
    private var onStep: ((AgentStep) -> Unit)? = null
    private var onCancelled = false

    private val notes = mutableMapOf<String, String>()

    private val conversationHistory: MutableList<Pair<String, String>> = mutableListOf()

    interface ExtendedTool {
        val name: String
        val description: String
        val parameters: String
        fun execute(args: String): String
    }

    private val basicTools: Map<String, AgentTool> = listOf(
        CalculatorTool(),
        TimerTool(),
        DeviceInfoTool(),
        NotePadTool(notes)
    ).associateBy { it.name }

    private val extendedTools: Map<String, ExtendedTool> = listOf<ExtendedTool>(
        ScreenReaderTool(),
        ScreenFindTool(),
        ScreenActionTool(),
        AppLauncherTool(),
        NotificationTool()
    ).associateBy { it.name }

    private val allToolNames: Set<String>
        get() = basicTools.keys + extendedTools.keys

    fun setStepCallback(cb: ((AgentStep) -> Unit)?) {
        onStep = cb
    }

    fun cancel() {
        onCancelled = true
    }

    fun getToolManifest(): String {
        val basicManifest = basicTools.values.joinToString("\n") { tool ->
            "${tool.name}: ${tool.description}\n  Args: ${tool.parameters}"
        }
        val extendedManifest = extendedTools.values.joinToString("\n") { tool ->
            "${tool.name}: ${tool.description}\n  Args: ${tool.parameters}"
        }
        return "--- Basic Tools ---\n$basicManifest\n\n--- Phone Control Tools ---\n$extendedManifest"
    }

    fun getConversationHistory(): List<Pair<String, String>> = conversationHistory.toList()

    fun clearHistory() {
        conversationHistory.clear()
        service.resetContext()
    }

    private fun trimHistory() {
        val usage = service.getContextUsage()
        val parts = usage.split("/")
        if (parts.size != 2) return
        val used = parts[0].toIntOrNull() ?: return
        val total = parts[1].toIntOrNull() ?: return
        if (total == 0) return

        val usageRatio = used.toFloat() / total.toFloat()
        if (usageRatio > 0.8f && conversationHistory.size > 4) {
            val toRemove = conversationHistory.size / 4
            repeat(toRemove) {
                if (conversationHistory.size > 2) {
                    conversationHistory.removeAt(0)
                }
            }
            service.resetContext()
            Log.i(TAG, "Trimmed history: removed $toRemove entries, ratio was $usageRatio")
        }
    }

    fun run(userPrompt: String, maxIterations: Int = 8): List<AgentStep> {
        onCancelled = false
        val steps = mutableListOf<AgentStep>()

        steps.add(AgentStep("thought", "Processing: $userPrompt"))
        onStep?.invoke(steps.last())

        val systemPrompt = buildSystemPrompt()
        conversationHistory.add("system" to systemPrompt)
        conversationHistory.add("user" to userPrompt)

        for (i in 0 until maxIterations) {
            if (cancelled) break

            trimHistory()

            steps.add(AgentStep("thought", "Thinking (step ${i + 1})..."))
            onStep?.invoke(steps.last())

            val llmInput = buildPromptFromHistory()
            val response = collectStream(llmInput, 512)
            Log.i(TAG, "Iteration $i LLM: ${response.take(200)}")

            conversationHistory.add("assistant" to response)

            val parsed = parseResponse(response)
            when {
                parsed.containsKey("action") -> {
                    val actionName = parsed["action"]!!
                    val actionArgs = parsed["args"] ?: "{}"

                    steps.add(AgentStep(
                        "action", "Using tool: $actionName",
                        toolName = actionName, toolArgs = actionArgs
                    ))
                    onStep?.invoke(steps.last())

                    val observation = executeTool(actionName, actionArgs)

                    steps.add(AgentStep("observation", observation,
                        toolName = actionName, toolResult = observation))
                    onStep?.invoke(steps.last())

                    conversationHistory.add("observation" to "Action: $actionName($actionArgs)\nResult: $observation")
                }
                parsed.containsKey("answer") -> {
                    val answer = parsed["answer"]!!
                    steps.add(AgentStep("answer", answer))
                    onStep?.invoke(steps.last())
                    break
                }
                else -> {
                    val directAnswer = response.trim()
                    if (directAnswer.isNotBlank()) {
                        steps.add(AgentStep("answer", directAnswer))
                        onStep?.invoke(steps.last())
                    }
                    break
                }
            }
        }

        if (steps.none { it.type == "answer" }) {
            steps.add(AgentStep("answer", "I couldn't complete this task within the iteration limit."))
            onStep?.invoke(steps.last())
        }

        return steps
    }

    private fun buildPromptFromHistory(): String {
        val sb = StringBuilder()
        for ((role, content) in conversationHistory) {
            when (role) {
                "system" -> sb.append("System: $content\n\n")
                "user" -> sb.append("User: $content\n")
                "assistant" -> sb.append("Assistant: $content\n")
                "observation" -> sb.append("$content\n")
                else -> sb.append("$role: $content\n")
            }
        }
        sb.append("Thought:")
        return sb.toString()
    }

    private fun collectStream(prompt: String, maxTokens: Int): String {
        val buffer = StringBuffer()
        val originalCb = service.swapTokenCallback { token ->
            buffer.append(token)
        }

        service.generateStream(prompt, maxTokens)

        service.swapTokenCallback { originalCb?.invoke(it) }

        return buffer.toString()
    }

    private fun executeTool(name: String, args: String): String {
        val basicTool = basicTools[name]
        if (basicTool != null) return basicTool.execute(args)

        val extendedTool = extendedTools[name]
        if (extendedTool != null) return extendedTool.execute(args)

        return "Error: Unknown tool '$name'. Available: ${allToolNames.joinToString(", ")}"
    }

    private val cancelled: Boolean get() = onCancelled

    private fun buildSystemPrompt(): String {
        val toolList = getToolManifest()
        return """You are an AI agent that can think and use tools to help the user. You can control the user's Android phone.

AVAILABLE TOOLS:
$toolList

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
- Common app package names: com.google.android.apps.messaging (Messages), com.google.android.dialer (Phone), com.google.android.apps.photos (Photos), com.android.settings (Settings), com.android.chrome (Chrome)"""
    }

    private fun parseResponse(response: String): Map<String, String> {
        val trimmed = response.trim()

        val actionRegex = Regex("(?i)action\\s*:\\s*(\\w+)[\\s\\n]*args\\s*:\\s*(\\{[^}]*})", RegexOption.DOT_MATCHES_ALL)
        actionRegex.find(trimmed)?.let { match ->
            return mapOf("action" to match.groupValues[1].lowercase(), "args" to match.groupValues[2])
        }

        val simpleActionRegex = Regex("(?i)action\\s*:\\s*(\\w+)")
        simpleActionRegex.find(trimmed)?.let { match ->
            val toolName = match.groupValues[1].lowercase()
            val argsRegex = Regex("(?i)args\\s*:\\s*(.+?)(?:\\n|$)")
            val args = argsRegex.find(trimmed)?.groupValues?.get(1)?.trim() ?: "{}"
            return mapOf("action" to toolName, "args" to args)
        }

        val answerRegex = Regex("(?i)answer\\s*:\\s*(.+)", RegexOption.DOT_MATCHES_ALL)
        answerRegex.find(trimmed)?.let { match ->
            return mapOf("answer" to match.groupValues[1].trim())
        }

        return emptyMap()
    }
}
