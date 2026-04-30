package com.agent.aios

import org.junit.Assert.*
import org.junit.Test

class AgentEngineParseTest {

    @Test
    fun parseActionWithArgs() {
        val parsed = parseResponse("Action: calculator\nArgs: {\"expression\": \"2+3\"}")
        assertEquals("calculator", parsed["action"])
        assertEquals("{\"expression\": \"2+3\"}", parsed["args"])
    }

    @Test
    fun parseAnswer() {
        val parsed = parseResponse("Answer: The result is 42")
        assertEquals("The result is 42", parsed["answer"])
    }

    @Test
    fun parseNoMatchReturnsEmpty() {
        val parsed = parseResponse("Just some random text without action or answer")
        assertTrue(parsed.isEmpty())
    }

    @Test
    fun parseCaseInsensitiveAction() {
        val parsed = parseResponse("ACTION: timer\nARGS: {\"seconds\": 5}")
        assertEquals("timer", parsed["action"])
    }

    @Test
    fun parseAnswerCaseInsensitive() {
        val parsed = parseResponse("ANSWER: yes it works")
        assertEquals("yes it works", parsed["answer"])
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
