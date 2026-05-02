package com.agent.aios.domain

import android.content.Context
import com.agent.aios.service.AIOSAccessibilityService

data class ToolContext(
    val appContext: Context,
    val accessibilityService: () -> AIOSAccessibilityService?,
)
