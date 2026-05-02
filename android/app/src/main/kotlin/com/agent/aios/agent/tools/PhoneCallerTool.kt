package com.agent.aios.agent.tools

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import com.agent.aios.AgentEngine
import com.agent.aios.domain.ToolContext
import org.json.JSONObject

class PhoneCallerTool : AgentEngine.ExtendedTool {
    override val name = "phone_caller"
    override val description = "Call or dial a number. Args: {action: call|dial, number}"
    override val parameters = """{"action": "call|dial", "number": "string, phone number to call or dial"}"""

    override fun execute(args: String, toolContext: ToolContext): String {
        return try {
            val json = JSONObject(args)
            val action = json.optString("action", "dial").lowercase()
            val number = json.optString("number", "").trim()

            if (number.isBlank()) return "Error: 'number' parameter required"

            when (action) {
                "call" -> makeCall(number, toolContext)
                "dial" -> openDialer(number, toolContext)
                else -> "Error: Unknown action '$action'. Use 'call' or 'dial'."
            }
        } catch (e: Exception) {
            "Error: ${e.message}"
        }
    }

    private fun makeCall(number: String, toolContext: ToolContext): String {
        val context = toolContext.appContext
        if (context.checkSelfPermission(Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED) {
            return "Error: CALL_PHONE permission not granted. Grant it in Phone Control settings, or use 'dial' action instead."
        }

        val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$number")).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
        return "Calling $number..."
    }

    private fun openDialer(number: String, toolContext: ToolContext): String {
        val context = toolContext.appContext
        val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$number")).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
        return "Opened dialer with $number"
    }
}
