package com.agent.aios

import org.json.JSONObject

interface AgentTool {
    val name: String
    val description: String
    val parameters: String

    fun execute(args: String): String
}

class CalculatorTool : AgentTool {
    override val name = "calculator"
    override val description = "Evaluate a mathematical expression"
    override val parameters = """{"expression": "string, math expression like 2+3*4"}"""

    override fun execute(args: String): String {
        return try {
            val expr = JSONObject(args).optString("expression", "") ?: ""
            val sanitized = expr.replace(Regex("[^0-9+\\-*/.()% ]"), "")
            if (sanitized.isEmpty()) return "Error: empty expression"
            val result = evalExpr(sanitized)
            "%.4f".format(result)
        } catch (e: Exception) {
            "Error: ${e.message}"
        }
    }

    private fun evalExpr(expr: String): Double {
        val tokens = expr.replace(" ", "").toCharArray()
        val values = java.util.ArrayDeque<Double>()
        val ops = java.util.ArrayDeque<Char>()
        var i = 0
        while (i < tokens.size) {
            when {
                tokens[i] == '(' -> ops.push(tokens[i])
                tokens[i] == ')' -> {
                    while (ops.peek() != '(') applyOp(values, ops.pop())
                    ops.pop()
                }
                tokens[i].isDigit() || tokens[i] == '.' -> {
                    val sb = StringBuilder()
                    while (i < tokens.size && (tokens[i].isDigit() || tokens[i] == '.')) {
                        sb.append(tokens[i]); i++
                    }
                    values.push(sb.toString().toDouble()); continue
                }
                tokens[i] in listOf('+', '-', '*', '/') -> {
                    while (ops.isNotEmpty() && prec(ops.peek() ?: '\u0000') >= prec(tokens[i]))
                        applyOp(values, ops.pop())
                    ops.push(tokens[i])
                }
            }
            i++
        }
        while (ops.isNotEmpty()) applyOp(values, ops.pop())
        return values.pop()
    }

    private fun prec(c: Char) = when (c) { '+', '-' -> 1; '*', '/' -> 2; else -> 0 }
    private fun applyOp(vals: java.util.ArrayDeque<Double>, op: Char) {
        val b = vals.pop(); val a = vals.pop()
        vals.push(when (op) { '+' -> a + b; '-' -> a - b; '*' -> a * b; '/' -> a / b; else -> a })
    }
}

class TimerTool : AgentTool {
    override val name = "timer"
    override val description = "Set a countdown timer in seconds"
    override val parameters = """{"seconds": "integer, number of seconds to wait"}"""

    override fun execute(args: String): String {
        return try {
            val secs = JSONObject(args).optInt("seconds", 0)
            if (secs <= 0 || secs > 300) return "Error: seconds must be 1-300"
            Thread.sleep(secs * 1000L)
            "Timer completed: ${secs}s elapsed"
        } catch (e: Exception) {
            "Error: ${e.message}"
        }
    }
}

class DeviceInfoTool : AgentTool {
    override val name = "device_info"
    override val description = "Get device information (model, OS, battery, memory)"
    override val parameters = "{}"

    override fun execute(args: String): String {
        val runtime = Runtime.getRuntime()
        val maxMem = runtime.maxMemory() / 1048576
        val totalMem = runtime.totalMemory() / 1048576
        val freeMem = runtime.freeMemory() / 1048576
        return JSONObject().apply {
            put("device", android.os.Build.MODEL)
            put("manufacturer", android.os.Build.MANUFACTURER)
            put("android_version", android.os.Build.VERSION.RELEASE)
            put("sdk_int", android.os.Build.VERSION.SDK_INT)
            put("jvm_max_mb", maxMem)
            put("jvm_total_mb", totalMem)
            put("jvm_free_mb", freeMem)
        }.toString(2)
    }
}

class NotePadTool(private val notes: MutableMap<String, String>) : AgentTool {
    override val name = "notepad"
    override val description = "Save or retrieve notes. Actions: save, get, list, delete"
    override val parameters = """{"action": "save|get|list|delete", "key": "string", "value": "string (for save)"}"""

    override fun execute(args: String): String {
        return try {
            val json = JSONObject(args)
            val action = json.optString("action", "")
            when (action) {
                "save" -> {
                    val key = json.optString("key", "")
                    val value = json.optString("value", "")
                    if (key.isBlank()) return "Error: key required"
                    notes[key] = value
                    "Saved note '$key'"
                }
                "get" -> {
                    val key = json.optString("key", "")
                    notes[key] ?: "Note '$key' not found"
                }
                "list" -> {
                    if (notes.isEmpty()) "No notes saved"
                    else notes.entries.joinToString("\n") { "- ${it.key}: ${it.value}" }
                }
                "delete" -> {
                    val key = json.optString("key", "")
                    if (notes.remove(key) != null) "Deleted note '$key'" else "Note '$key' not found"
                }
                else -> "Error: unknown action '$action'. Use save, get, list, or delete."
            }
        } catch (e: Exception) {
            "Error: ${e.message}"
        }
    }
}
