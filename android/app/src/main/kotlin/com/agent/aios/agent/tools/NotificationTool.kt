package com.agent.aios.agent.tools

import com.agent.aios.AgentEngine
import org.json.JSONObject

class NotificationTool : AgentEngine.ExtendedTool {
    override val name = "notification_reader"
    override val description = "Read recent notifications. Args: {max_count}"
    override val parameters = """{"max_count": "integer, max notifications to return (default 20)"}"""

    override fun execute(args: String): String {
        return try {
            val json = JSONObject(args)
            val maxCount = json.optInt("max_count", 20)
            com.agent.aios.service.NotificationListener.getRecentNotifications(maxCount)
        } catch (e: Exception) {
            "Error: ${e.message}"
        }
    }
}
