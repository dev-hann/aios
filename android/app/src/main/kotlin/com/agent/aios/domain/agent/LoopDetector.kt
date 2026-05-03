package com.agent.aios.domain.agent

import org.json.JSONObject

class LoopDetector {
    private data class ActionSignature(val tool: String, val argsCanonical: String)

    private val loopOverrides =
        mapOf(
            "screen_action" to setOf("scroll", "swipe", "global"),
        )

    private val actionHistory = mutableListOf<ActionSignature>()
    private val observationHistory = mutableListOf<String>()
    private var warningGiven = false

    fun reset() {
        actionHistory.clear()
        observationHistory.clear()
        warningGiven = false
    }

    fun record(
        toolName: String,
        args: String,
        observation: String,
    ): LoopCheckResult {
        val canonical = canonicalizeArgs(args)
        actionHistory.add(ActionSignature(toolName, canonical))
        observationHistory.add(observation)

        val consecutiveDuplicates = actionHistory.takeLast(3).count { it == ActionSignature(toolName, canonical) }
        val isRepeatedAction = consecutiveDuplicates >= 3 && !isActionAllowedRepeated(toolName, canonical)

        val consecutiveIdenticalObs =
            observationHistory.size >= 2 &&
                observationHistory.takeLast(2).distinct().size < 2

        return when {
            isRepeatedAction || consecutiveIdenticalObs -> {
                if (warningGiven) {
                    LoopCheckResult.FORCE_BREAK
                } else {
                    warningGiven = true
                    LoopCheckResult.WARNING(consecutiveDuplicates, toolName)
                }
            }
            else -> LoopCheckResult.OK
        }
    }

    fun shouldNudge(iteration: Int, hasAnswer: Boolean): Boolean {
        return iteration >= 3 && !hasAnswer && !warningGiven
    }

    private fun canonicalizeArgs(args: String): String {
        return try {
            val json = JSONObject(args)
            json.keys().asSequence().toList().sorted()
                .joinToString(",") { k -> "$k=${json.opt(k)}" }
        } catch (_: Exception) {
            args
        }
    }

    private fun isActionAllowedRepeated(
        tool: String,
        argsCanonical: String,
    ): Boolean {
        val overrides = loopOverrides[tool] ?: return false
        return overrides.any { argsCanonical.contains(it) }
    }

    sealed class LoopCheckResult {
        data object OK : LoopCheckResult()
        data class WARNING(val count: Int, val toolName: String) : LoopCheckResult()
        data object FORCE_BREAK : LoopCheckResult()
    }
}
