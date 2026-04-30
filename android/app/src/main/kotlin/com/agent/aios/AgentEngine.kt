package com.agent.aios

import android.util.Log
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
    private val tools: Map<String, AgentTool> = listOf(
        CalculatorTool(),
        TimerTool(),
        DeviceInfoTool(),
        NotePadTool(notes)
    ).associateBy { it.name }

    fun setStepCallback(cb: ((AgentStep) -> Unit)?) {
        onStep = cb
    }

    fun cancel() {
        onCancelled = true
    }

    fun getToolManifest(): String {
        return tools.values.joinToString("\n") { tool ->
            "${tool.name}: ${tool.description}\n  Args: ${tool.parameters}"
        }
    }

    fun run(userPrompt: String, maxIterations: Int = 5): List<AgentStep> {
        onCancelled = false
        val steps = mutableListOf<AgentStep>()

        val systemPrompt = buildSystemPrompt()
        val conversation = StringBuilder()

        steps.add(AgentStep("thought", "Processing: $userPrompt"))
        onStep?.invoke(steps.last())

        conversation.append("User: $userPrompt\n")

        for (i in 0 until maxIterations) {
            if (cancelled) break

            val llmInput = "$systemPrompt\n\n$conversation\nThought:"
            val response = service.generate(llmInput, 256)
            Log.i(TAG, "Iteration $i LLM: ${response.take(200)}")

            conversation.append("Thought: $response\n")

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

                    val tool = tools[actionName]
                    val observation = if (tool != null) {
                        tool.execute(actionArgs)
                    } else {
                        "Error: Unknown tool '$actionName'. Available: ${tools.keys.joinToString(", ")}"
                    }

                    steps.add(AgentStep("observation", observation,
                        toolName = actionName, toolResult = observation))
                    onStep?.invoke(steps.last())

                    conversation.append("Action: $actionName($actionArgs)\n")
                    conversation.append("Observation: $observation\n")
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

    private val cancelled: Boolean get() = onCancelled

    private fun buildSystemPrompt(): String {
        val toolList = getToolManifest()
        return """You are an AI agent that can think and use tools to help the user.

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
- For math calculations, always use the calculator tool"""
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
