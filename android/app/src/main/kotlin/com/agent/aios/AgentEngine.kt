package com.agent.aios

import android.util.Log
import com.agent.aios.agent.tools.AppLauncherTool
import com.agent.aios.agent.tools.ContactSearchTool
import com.agent.aios.agent.tools.NotificationTool
import com.agent.aios.agent.tools.PhoneCallerTool
import com.agent.aios.agent.tools.ScreenActionTool
import com.agent.aios.agent.tools.ScreenFindTool
import com.agent.aios.agent.tools.ScreenReaderTool
import com.agent.aios.agent.tools.SmsSenderTool
import org.json.JSONObject
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

enum class ToolRisk { SAFE, LOW, HIGH, CRITICAL }

data class ToolAuditEntry(
    val timestamp: Long,
    val tool: String,
    val args: String,
    val risk: ToolRisk,
    val approved: Boolean,
    val result: String
)

data class AgentStep(
    val type: String,
    val content: String,
    val toolName: String = "",
    val toolArgs: String = "",
    val toolResult: String = "",
    val riskLevel: String = ""
)

class AgentEngine(private val service: LlmService) {

    private val TAG = "AIOS-Agent"
    private var onStep: ((AgentStep) -> Unit)? = null
    private var onCancelled = false

    @Volatile
    private var agentThread: Thread? = null

    private val notes = mutableMapOf<String, String>()

    private val auditLog = mutableListOf<ToolAuditEntry>()

    @Volatile
    private var confirmationLatch: CountDownLatch? = null

    @Volatile
    private var confirmationApproved = false

    private val promptBuilder = PromptBuilder(service)

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
        NotificationTool(),
        ContactSearchTool(),
        SmsSenderTool(),
        PhoneCallerTool()
    ).associateBy { it.name }

    private val allToolNames: Set<String>
        get() = basicTools.keys + extendedTools.keys

    fun setStepCallback(cb: ((AgentStep) -> Unit)?) {
        onStep = cb
    }

    private fun emitStep(step: AgentStep) {
        try {
            onStep?.invoke(step)
        } catch (e: Exception) {
            Log.e(TAG, "onStep callback error: ${e.message}", e)
        }
    }

    fun cancel() {
        onCancelled = true
        confirmationApproved = false
        confirmationLatch?.countDown()
        agentThread?.interrupt()
    }

    fun classifyRisk(toolName: String, args: String): ToolRisk {
        val json = try { JSONObject(args) } catch (_: Exception) { JSONObject() }
        val action = json.optString("action", "").lowercase()
        return when (toolName) {
            "calculator", "timer", "device_info", "notepad" -> ToolRisk.SAFE
            "screen_reader", "screen_find" -> ToolRisk.SAFE
            "notification_reader" -> ToolRisk.SAFE
            "contact_search" -> ToolRisk.SAFE
            "app_launcher" -> when (action) {
                "open_settings", "list_apps" -> ToolRisk.LOW
                "open_app", "open_url" -> ToolRisk.HIGH
                else -> ToolRisk.LOW
            }
            "screen_action" -> when (action) {
                "global" -> ToolRisk.LOW
                "type" -> {
                    val content = json.optString("content", "").lowercase()
                    val sensitive = listOf("password", "pin", "passcode", "ssn", "social security", "credit card", "cvv", "otp")
                    if (sensitive.any { content.contains(it) }) ToolRisk.CRITICAL else ToolRisk.HIGH
                }
                "tap", "long_click", "scroll", "swipe" -> ToolRisk.HIGH
                else -> ToolRisk.HIGH
            }
            "sms_sender" -> when (action) {
                "send" -> ToolRisk.CRITICAL
                "read" -> ToolRisk.HIGH
                else -> ToolRisk.HIGH
            }
            "phone_caller" -> when (action) {
                "call" -> ToolRisk.CRITICAL
                "dial" -> ToolRisk.HIGH
                else -> ToolRisk.HIGH
            }
            else -> ToolRisk.HIGH
        }
    }

    fun resolveConfirmation(approved: Boolean) {
        confirmationApproved = approved
        confirmationLatch?.countDown()
    }

    fun getAuditLog(): List<ToolAuditEntry> = synchronized(auditLog) { auditLog.toList() }

    private fun addAuditEntry(tool: String, args: String, risk: ToolRisk, approved: Boolean, result: String) {
        synchronized(auditLog) {
            auditLog.add(ToolAuditEntry(System.currentTimeMillis(), tool, args, risk, approved, result))
            if (auditLog.size > 100) {
                repeat(auditLog.size - 100) { auditLog.removeAt(0) }
            }
        }
    }

    fun getToolManifest(): String {
        val basicLines = basicTools.values.map { "- ${it.name}: ${it.description}" }
        val extendedLines = extendedTools.values.map { "- ${it.name}: ${it.description}" }
        return (basicLines + extendedLines).joinToString("\n")
    }

    fun getConversationHistory(): List<Pair<String, String>> = promptBuilder.getHistory()

    fun clearHistory() {
        promptBuilder.clearHistory()
    }

    fun initSystemPrompt() {
        val systemPrompt = promptBuilder.buildSystemPrompt(getToolManifest())
        val formatted = service.formatChat(arrayOf("system"), arrayOf(systemPrompt))
        val result = service.processSystemPrompt(formatted)
        if (result != 0) {
            Log.e(TAG, "initSystemPrompt failed ($result)")
        } else {
            Log.i(TAG, "initSystemPrompt: cached (${formatted.length} chars)")
        }
    }

    fun run(userPrompt: String, maxIterations: Int = 8): List<AgentStep> {
        onCancelled = false
        agentThread = Thread.currentThread()
        val steps = mutableListOf<AgentStep>()
        val systemPrompt = promptBuilder.buildSystemPrompt(getToolManifest())
        Log.i(TAG, "Agent run: prompt='${userPrompt.take(50)}', maxIter=$maxIterations")

        try {
            steps.add(AgentStep("thought", "Processing: $userPrompt"))
            emitStep(steps.last())

            promptBuilder.addUserMessage(userPrompt)

            for (i in 0 until maxIterations) {
                if (cancelled) break

                val didTrim = promptBuilder.trimIfNeeded()

                steps.add(AgentStep("thought", "Thinking (step ${i + 1})..."))
                emitStep(steps.last())

                emitStep(AgentStep("thinking_start", ""))

                val formattedPrompt = promptBuilder.buildPromptForInfer(systemPrompt)
                val promptResult = service.processPromptIncremental(formattedPrompt)
                if (promptResult != 0) {
                    Log.e(TAG, "processPromptIncremental failed ($promptResult)")
                    emitStep(AgentStep("thinking_end", ""))
                    break
                }

                if (i == 0 || didTrim) {
                    service.setSystemPromptPosition()
                }

                val response = generateTokens(512)
                Log.i(TAG, "Iteration $i LLM: ${response.take(200)}")

                emitStep(AgentStep("thinking_end", ""))

                promptBuilder.addAssistantMessage(response)

                val parsed = parseResponse(response)
                when {
                    parsed.containsKey("action") -> {
                        val actionName = parsed["action"]!!
                        val actionArgs = parsed["args"] ?: "{}"

                        steps.add(AgentStep(
                            "action", "Using tool: $actionName",
                            toolName = actionName, toolArgs = actionArgs
                        ))
                        emitStep(steps.last())

                        val observation = executeTool(actionName, actionArgs)

                        steps.add(AgentStep("observation", observation,
                            toolName = actionName, toolResult = observation))
                        emitStep(steps.last())

                        promptBuilder.addObservation("Action: $actionName($actionArgs)\nResult: $observation")
                    }
                    parsed.containsKey("answer") -> {
                        val answer = parsed["answer"]!!
                        steps.add(AgentStep("answer", answer))
                        emitStep(steps.last())
                        break
                    }
                    else -> {
                        val directAnswer = response.trim()
                        if (directAnswer.isNotBlank()) {
                            steps.add(AgentStep("answer", directAnswer))
                            emitStep(steps.last())
                        }
                        break
                    }
                }
            }

            if (steps.none { it.type == "answer" }) {
                steps.add(AgentStep("answer", "I couldn't complete this task within the iteration limit."))
                emitStep(steps.last())
            }
        } catch (e: InterruptedException) {
            Log.i(TAG, "Agent run cancelled by user")
            if (steps.none { it.type == "answer" }) {
                steps.add(AgentStep("answer", "Task cancelled."))
                emitStep(steps.last())
            }
        } catch (e: Exception) {
            Log.e(TAG, "Agent run crashed: ${e.message}", e)
            if (steps.none { it.type == "answer" }) {
                steps.add(AgentStep("answer", "An error occurred during execution: ${e.message}"))
                emitStep(steps.last())
            }
        } finally {
            agentThread = null
        }

        return steps
    }

    private fun collectStream(prompt: String, maxTokens: Int): String {
        val result = service.processPrompt(prompt)
        if (result != 0) {
            Log.e(TAG, "collectStream: processPrompt failed ($result)")
            return ""
        }
        return generateTokens(maxTokens)
    }

    private fun generateTokens(maxTokens: Int): String {
        val buffer = StringBuffer()
        var generated = 0
        while (generated < maxTokens) {
            if (cancelled) break
            val token = service.generateOneToken() ?: break
            if (token.isNotEmpty()) {
                buffer.append(token)
            }
            generated++
        }
        Log.i(TAG, "generateTokens: ${buffer.length} chars, $generated tokens")
        return buffer.toString()
    }

    private fun executeTool(name: String, args: String): String {
        val risk = classifyRisk(name, args)

        if (risk == ToolRisk.HIGH || risk == ToolRisk.CRITICAL) {
            confirmationLatch = CountDownLatch(1)
            confirmationApproved = false

            emitStep(AgentStep(
                "confirmation_required",
                "Requires confirmation: $name",
                toolName = name,
                toolArgs = args,
                riskLevel = risk.name
            ))

            val approved = try {
                confirmationLatch?.await(60, TimeUnit.SECONDS) ?: false
                confirmationApproved
            } catch (_: Exception) {
                false
            } finally {
                confirmationLatch = null
            }

            if (!approved) {
                addAuditEntry(name, args, risk, false, "Cancelled by user")
                return "Action cancelled by user"
            }
        }

        val basicTool = basicTools[name]
        if (basicTool != null) {
            val result = basicTool.execute(args)
            addAuditEntry(name, args, risk, true, result)
            return result
        }

        val extendedTool = extendedTools[name]
        if (extendedTool != null) {
            val result = extendedTool.execute(args)
            addAuditEntry(name, args, risk, true, result)
            return result
        }

        return "Error: Unknown tool '$name'. Available: ${allToolNames.joinToString(", ")}"
    }

    private val cancelled: Boolean get() = onCancelled

    companion object {
        private val ACTION_ARGS_REGEX = Regex(
            """(?i)action\s*:\s*(\w+)\s*args\s*:\s*(\{[^}]*\})""",
            RegexOption.DOT_MATCHES_ALL
        )
        private val ACTION_SIMPLE_REGEX = Regex("""(?i)action\s*:\s*(\w+)""")
        private val ARGS_REGEX = Regex("""(?i)args\s*:\s*(.+?)$""", RegexOption.MULTILINE)
        private val ANSWER_REGEX = Regex("""(?i)answer\s*:\s*(.+)""", RegexOption.DOT_MATCHES_ALL)
    }

    private fun parseResponse(response: String): Map<String, String> {
        val trimmed = response.trim()

        try {
            ACTION_ARGS_REGEX.find(trimmed)?.let { match ->
                return mapOf("action" to match.groupValues[1].lowercase(), "args" to match.groupValues[2])
            }

            ACTION_SIMPLE_REGEX.find(trimmed)?.let { match ->
                val toolName = match.groupValues[1].lowercase()
                val args = ARGS_REGEX.find(trimmed)?.groupValues?.get(1)?.trim() ?: "{}"
                return mapOf("action" to toolName, "args" to args)
            }

            ANSWER_REGEX.find(trimmed)?.let { match ->
                return mapOf("answer" to match.groupValues[1].trim())
            }
        } catch (e: Exception) {
            Log.e(TAG, "parseResponse regex error: ${e.message}", e)
        }

        return emptyMap()
    }
}
