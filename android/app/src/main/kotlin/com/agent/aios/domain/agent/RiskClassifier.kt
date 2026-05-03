package com.agent.aios.domain.agent

import com.agent.aios.domain.model.ToolRisk
import org.json.JSONObject

class RiskClassifier {
    fun classify(
        toolName: String,
        args: String,
    ): ToolRisk {
        val json =
            try {
                JSONObject(args)
            } catch (_: Exception) {
                JSONObject()
            }
        val action = json.optString("action", "").lowercase()
        return when (toolName) {
            "calculator", "timer", "device_info", "notepad" -> ToolRisk.SAFE
            "screen_reader", "screen_find" -> ToolRisk.SAFE
            "notification_reader" -> ToolRisk.SAFE
            "contact_search" -> ToolRisk.SAFE
            "app_launcher" ->
                when (action) {
                    "open_settings", "list_apps" -> ToolRisk.LOW
                    "open_app", "open_url" -> ToolRisk.HIGH
                    else -> ToolRisk.LOW
                }
            "screen_action" ->
                when (action) {
                    "global" -> ToolRisk.LOW
                    "type" -> {
                        val content = json.optString("content", "").lowercase()
                        val sensitive = listOf("password", "pin", "passcode", "ssn", "social security", "credit card", "cvv", "otp")
                        if (sensitive.any { content.contains(it) }) ToolRisk.CRITICAL else ToolRisk.HIGH
                    }
                    "tap", "long_click", "scroll", "swipe" -> ToolRisk.HIGH
                    else -> ToolRisk.HIGH
                }
            "sms_sender" ->
                when (action) {
                    "send" -> ToolRisk.CRITICAL
                    "read" -> ToolRisk.HIGH
                    else -> ToolRisk.HIGH
                }
            "phone_caller" ->
                when (action) {
                    "call" -> ToolRisk.CRITICAL
                    "dial" -> ToolRisk.HIGH
                    else -> ToolRisk.HIGH
                }
            else -> ToolRisk.HIGH
        }
    }
}
