package com.agent.aios.domain.agent

import android.util.Log
import com.agent.aios.AgentTool
import com.agent.aios.CalculatorTool
import com.agent.aios.DeviceInfoTool
import com.agent.aios.NotePadTool
import com.agent.aios.PromptBuilder
import com.agent.aios.TimerTool
import com.agent.aios.agent.tools.AppLauncherTool
import com.agent.aios.agent.tools.ContactSearchTool
import com.agent.aios.agent.tools.ExtendedTool
import com.agent.aios.agent.tools.NotificationTool
import com.agent.aios.agent.tools.PhoneCallerTool
import com.agent.aios.agent.tools.ScreenActionTool
import com.agent.aios.agent.tools.ScreenFindTool
import com.agent.aios.agent.tools.ScreenReaderTool
import com.agent.aios.agent.tools.SmsSenderTool
import com.agent.aios.domain.LlmProvider
import com.agent.aios.domain.ToolContext
import com.agent.aios.domain.agent.LoopDetector.LoopCheckResult
import com.agent.aios.domain.agent.ResponseParser.ParseResult
import com.agent.aios.domain.model.AgentResult
import com.agent.aios.domain.model.AgentStep
import com.agent.aios.domain.model.ToolRisk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class ReactStrategy(private val llmProvider: LlmProvider) : AgentStrategy {
    private val TAG = "AIOS-React"

    @Volatile
    private var onCancelled = false

    @Volatile
    private var agentThread: Thread? = null

    private val notes = mutableMapOf<String, String>()
    private val riskClassifier = RiskClassifier()
    private val loopDetector = LoopDetector()
    private val confirmationGate = ConfirmationGate()
    private val auditLog = AuditLog()
    private val promptBuilder = PromptBuilder(llmProvider)

    private var toolContext: ToolContext? = null

    private val basicTools: Map<String, AgentTool> =
        listOf(
            CalculatorTool(),
            TimerTool(),
            DeviceInfoTool(),
            NotePadTool(notes),
        ).associateBy { it.name }

    private val extendedTools: Map<String, ExtendedTool> =
        listOf<ExtendedTool>(
            ScreenReaderTool(),
            ScreenFindTool(),
            ScreenActionTool(),
            AppLauncherTool(),
            NotificationTool(),
            ContactSearchTool(),
            SmsSenderTool(),
            PhoneCallerTool(),
        ).associateBy { it.name }

    private val allToolNames: Set<String>
        get() = basicTools.keys + extendedTools.keys

    private val responseParser: ResponseParser
        get() = ResponseParser(allToolNames)

    fun setToolContext(ctx: ToolContext) {
        toolContext = ctx
    }

    override suspend fun execute(
        prompt: String,
        maxIterations: Int,
        maxTokens: Int,
        onStep: (AgentStep) -> Unit,
    ): AgentResult =
        withContext(Dispatchers.IO) {
            runInternal(prompt, maxIterations, maxTokens, onStep)
        }

    private fun runInternal(
        userPrompt: String,
        maxIterations: Int,
        maxTokens: Int,
        onStep: (AgentStep) -> Unit,
    ): AgentResult {
        onCancelled = false
        agentThread = Thread.currentThread()
        loopDetector.reset()
        val steps = mutableListOf<AgentStep>()
        val systemPrompt = promptBuilder.buildSystemPrompt(getToolManifest())
        Log.i(TAG, "Agent run: prompt='${userPrompt.take(50)}', maxIter=$maxIterations")

        val maxRunDurationMs = 120_000L
        val runStartTime = System.currentTimeMillis()

        try {
            steps.add(AgentStep("thought", "Processing: $userPrompt"))
            onStep(steps.last())

            promptBuilder.addUserMessage(userPrompt)

            for (i in 0 until maxIterations) {
                if (onCancelled) break

                val elapsed = System.currentTimeMillis() - runStartTime
                if (elapsed > maxRunDurationMs) {
                    Log.w(TAG, "Agent timed out after ${elapsed}ms")
                    steps.add(AgentStep("thought", "Time limit reached (${elapsed / 1000}s)."))
                    onStep(steps.last())
                    break
                }

                val didTrim = promptBuilder.trimIfNeeded()

                steps.add(AgentStep("thought", "Thinking (step ${i + 1})..."))
                onStep(steps.last())

                onStep(AgentStep("thinking_start", ""))

                val formattedPrompt = promptBuilder.buildPromptForInfer(systemPrompt)
                val promptResult = llmProvider.processPromptIncremental(formattedPrompt)
                if (promptResult != 0) {
                    Log.e(TAG, "processPromptIncremental failed ($promptResult)")
                    onStep(AgentStep("thinking_end", ""))
                    break
                }

                if (i == 0 || didTrim) {
                    llmProvider.setSystemPromptPosition()
                }

                val response = generateTokens(maxTokens)
                Log.i(TAG, "Iteration $i LLM: ${response.take(200)}")

                onStep(AgentStep("thinking_end", ""))

                promptBuilder.addAssistantMessage(response)

                val parsed = responseParser.parse(response)
                when (parsed) {
                    is ParseResult.Action -> {
                        steps.add(
                            AgentStep(
                                "action",
                                "Using tool: ${parsed.toolName}",
                                toolName = parsed.toolName,
                                toolArgs = parsed.args,
                            ),
                        )
                        onStep(steps.last())

                        val observation = executeTool(parsed.toolName, parsed.args, onStep)

                        steps.add(
                            AgentStep(
                                "observation",
                                observation,
                                toolName = parsed.toolName,
                                toolResult = observation,
                            ),
                        )
                        onStep(steps.last())

                        promptBuilder.addObservation("Observation from ${parsed.toolName}: $observation")

                        val loopResult = loopDetector.record(parsed.toolName, parsed.args, observation)
                        when (loopResult) {
                            is LoopCheckResult.Warning -> {
                                val nudge =
                                    "WARNING: You have called '${parsed.toolName}' ${loopResult.count} times with similar arguments. " +
                                        "Provide your final Answer now, or try a completely different approach."
                                promptBuilder.addObservation(nudge)
                                Log.w(TAG, "Loop warning: tool=${parsed.toolName}, dup=${loopResult.count}")
                            }
                            is LoopCheckResult.ForceBreak -> {
                                Log.w(TAG, "Force-breaking agent: loop detected (tool=${parsed.toolName})")
                                promptBuilder.addObservation("SYSTEM: Loop detected. Provide your Answer now.")
                                break
                            }
                            LoopCheckResult.Ok -> {
                                if (loopDetector.shouldNudge(i + 1, steps.none { it.type == "answer" })) {
                                    promptBuilder.addObservation(
                                        "Reminder: ${i + 1} steps completed. If you have enough information, provide your final Answer now.",
                                    )
                                }
                            }
                        }
                    }
                    is ParseResult.Answer -> {
                        steps.add(AgentStep("answer", parsed.text))
                        onStep(steps.last())
                        break
                    }
                    ParseResult.Empty -> {
                        val directAnswer = response.trim()
                        if (directAnswer.isNotBlank()) {
                            steps.add(AgentStep("answer", directAnswer))
                            onStep(steps.last())
                        } else {
                            Log.w(TAG, "Empty LLM response at iteration $i")
                            if (i >= maxIterations - 1) {
                                steps.add(AgentStep("answer", "모델이 빈 응답을 생성했습니다. 다시 시도해주세요."))
                                onStep(steps.last())
                            }
                        }
                        break
                    }
                }
            }

            if (steps.none { it.type == "answer" }) {
                val lastObs = steps.lastOrNull { it.type == "observation" }?.toolResult?.take(200)
                val summary =
                    if (lastObs != null) {
                        "작업을 완료하지 못했습니다. 마지막 관찰 결과: $lastObs"
                    } else {
                        "작업을 완료하지 못했습니다. 다시 시도해주세요."
                    }
                steps.add(AgentStep("answer", summary))
                onStep(steps.last())
            }
        } catch (e: InterruptedException) {
            Log.i(TAG, "Agent run cancelled by user")
            if (steps.none { it.type == "answer" }) {
                steps.add(AgentStep("answer", "Task cancelled."))
                onStep(steps.last())
            }
        } catch (e: Exception) {
            Log.e(TAG, "Agent run crashed: ${e.message}", e)
            if (steps.none { it.type == "answer" }) {
                steps.add(AgentStep("answer", "An error occurred during execution: ${e.message}"))
                onStep(steps.last())
            }
        } finally {
            agentThread = null
        }

        val success = steps.any { it.type == "answer" }
        return AgentResult(steps, success)
    }

    private fun generateTokens(maxTokens: Int): String {
        val buffer = StringBuffer()
        var generated = 0
        while (generated < maxTokens) {
            if (onCancelled) break
            val token = llmProvider.generateOneToken() ?: break
            if (token.isNotEmpty()) {
                buffer.append(token)
            }
            generated++
        }
        Log.i(TAG, "generateTokens: ${buffer.length} chars, $generated tokens")
        return buffer.toString()
    }

    private fun executeTool(
        name: String,
        args: String,
        onStep: (AgentStep) -> Unit,
    ): String {
        val risk = riskClassifier.classify(name, args)

        if (risk == ToolRisk.HIGH || risk == ToolRisk.CRITICAL) {
            val approved = confirmationGate.requestConfirmation(risk, name, args, onStep)
            if (!approved) {
                auditLog.add(name, args, risk, false, "Cancelled by user")
                return "Action cancelled by user"
            }
        }

        val basicTool = basicTools[name]
        if (basicTool != null) {
            val result = basicTool.execute(args)
            auditLog.add(name, args, risk, true, result)
            return result
        }

        val extendedTool = extendedTools[name]
        if (extendedTool != null) {
            val ctx = toolContext ?: return "Error: ToolContext not initialized"
            val result = extendedTool.execute(args, ctx)
            auditLog.add(name, args, risk, true, result)
            return result
        }

        return "Error: Unknown tool '$name'. Available: ${allToolNames.joinToString(", ")}"
    }

    override fun cancel() {
        onCancelled = true
        confirmationGate.cancel()
        agentThread?.interrupt()
    }

    override fun resolveConfirmation(approved: Boolean) {
        confirmationGate.resolve(approved)
    }

    override fun initSystemPrompt() {
        val systemPrompt = promptBuilder.buildSystemPrompt(getToolManifest())
        val formatted =
            llmProvider.formatChat(
                arrayOf("system", "user"),
                arrayOf(systemPrompt, "Ready."),
            )
        val result = llmProvider.processSystemPrompt(formatted)
        if (result != 0) {
            Log.e(TAG, "initSystemPrompt failed ($result)")
        } else {
            Log.i(TAG, "initSystemPrompt: cached (${formatted.length} chars)")
        }
    }

    override fun getToolManifest(): String {
        val basicLines = basicTools.values.map { "- ${it.name}: ${it.description}" }
        val extendedLines = extendedTools.values.map { "- ${it.name}: ${it.description}" }
        return (basicLines + extendedLines).joinToString("\n")
    }

    override fun getConversationHistory(): List<Pair<String, String>> = promptBuilder.getHistory()

    override fun clearHistory() {
        promptBuilder.clearHistory()
    }

    fun getAuditLog(): List<com.agent.aios.domain.model.ToolAuditEntry> = auditLog.getAll()
}
