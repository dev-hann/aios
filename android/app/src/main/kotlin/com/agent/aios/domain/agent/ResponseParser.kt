package com.agent.aios.domain.agent

import android.util.Log

class ResponseParser(private val validToolNames: Set<String>) {
    private val TAG = "AIOS-Parser"

    companion object {
        private val LINE_START_ACTION_REGEX = Regex("""(?im)^Action\s*:\s*(\w+)""")
        private val ARGS_REGEX = Regex("""(?im)^Args\s*:\s*(.+)""", RegexOption.MULTILINE)
        private val ANSWER_REGEX = Regex("""(?im)^Answer\s*:\s*(.+)""", RegexOption.DOT_MATCHES_ALL)
    }

    fun parse(response: String): ParseResult {
        val trimmed = response.trim()
        if (trimmed.isBlank()) return ParseResult.Empty

        try {
            val actionMatch = LINE_START_ACTION_REGEX.find(trimmed)
            if (actionMatch != null) {
                val toolName = actionMatch.groupValues[1].lowercase()
                if (toolName in validToolNames) {
                    val afterAction = trimmed.substring(actionMatch.range.last + 1)
                    val argsStart = afterAction.indexOf('{')
                    val args =
                        if (argsStart >= 0) {
                            extractJsonArgs(afterAction, argsStart)
                        } else {
                            ARGS_REGEX.find(trimmed)?.groupValues?.get(1)?.trim() ?: "{}"
                        }
                    return ParseResult.Action(toolName, args)
                }
            }

            ANSWER_REGEX.find(trimmed)?.let { match ->
                return ParseResult.Answer(match.groupValues[1].trim())
            }
        } catch (e: Exception) {
            Log.e(TAG, "parseResponse error: ${e.message}", e)
        }

        return ParseResult.Empty
    }

    private fun extractJsonArgs(
        text: String,
        startIndex: Int,
    ): String {
        var depth = 0
        var inString = false
        var escape = false
        for (i in startIndex until text.length) {
            val c = text[i]
            if (escape) {
                escape = false
                continue
            }
            if (c == '\\') {
                escape = true
                continue
            }
            if (c == '"') {
                inString = !inString
                continue
            }
            if (!inString) {
                if (c == '{') depth++
                if (c == '}') {
                    depth--
                    if (depth == 0) return text.substring(startIndex, i + 1)
                }
            }
        }
        return text.substring(startIndex)
    }

    sealed class ParseResult {
        data class Action(val toolName: String, val args: String) : ParseResult()

        data class Answer(val text: String) : ParseResult()

        data object Empty : ParseResult()
    }
}
