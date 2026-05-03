package com.agent.aios.domain.agent

import com.agent.aios.domain.model.AgentStep
import com.agent.aios.domain.model.ToolRisk
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class ConfirmationGate {
    private var latch: CountDownLatch? = null

    @Volatile
    private var approved = false

    fun requestConfirmation(
        risk: ToolRisk,
        toolName: String,
        args: String,
        onStep: (AgentStep) -> Unit,
    ): Boolean {
        latch = CountDownLatch(1)
        approved = false

        onStep(
            AgentStep(
                type = "confirmation_required",
                content = "Requires confirmation: $toolName",
                toolName = toolName,
                toolArgs = args,
                riskLevel = risk.name,
            ),
        )

        return try {
            latch?.await(60, TimeUnit.SECONDS) ?: false
            approved
        } catch (_: Exception) {
            false
        } finally {
            latch = null
        }
    }

    fun resolve(approved: Boolean) {
        this.approved = approved
        latch?.countDown()
    }

    fun cancel() {
        approved = false
        latch?.countDown()
    }
}
