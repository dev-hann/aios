package com.agent.aios.agent.tools

import com.agent.aios.domain.ToolContext

interface ExtendedTool {
    val name: String
    val description: String
    val parameters: String

    fun execute(
        args: String,
        toolContext: ToolContext,
    ): String
}
