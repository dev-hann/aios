package com.agent.aios.domain.agent

interface Tool {
    val name: String
    val description: String
    val parameters: String

    fun execute(args: String, context: ToolContext): String
}

interface ToolContext {
    val appContext: android.content.Context

    fun getAccessibilityService(): com.agent.aios.service.AIOSAccessibilityService?

    fun getNotificationService(): com.agent.aios.service.NotificationListener?
}
