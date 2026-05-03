package com.agent.aios.data.tool

import android.content.Context
import com.agent.aios.domain.agent.ToolContext
import com.agent.aios.service.AIOSAccessibilityService
import com.agent.aios.service.NotificationListener
import com.agent.aios.service.ServiceRegistry
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ToolContextImpl @Inject constructor(
    @ApplicationContext override val appContext: Context,
    private val serviceRegistry: ServiceRegistry,
) : ToolContext {
    override fun getAccessibilityService(): AIOSAccessibilityService? {
        return serviceRegistry.accessibilityService.value
    }

    override fun getNotificationService(): NotificationListener? {
        return serviceRegistry.notificationService.value
    }
}
