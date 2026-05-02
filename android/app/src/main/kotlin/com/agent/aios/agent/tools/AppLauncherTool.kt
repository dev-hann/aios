package com.agent.aios.agent.tools

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import com.agent.aios.AIOSApp
import com.agent.aios.AgentEngine
import org.json.JSONObject

class AppLauncherTool : AgentEngine.ExtendedTool {
    override val name = "app_launcher"
    override val description = "Open app/URL/settings or list apps. Args: {action: open_app|open_url|open_settings|list_apps, package_name, url, setting, query}"
    override val parameters = """{"action": "open_app|open_url|open_settings|list_apps", "package_name": "string (for open_app)", "url": "string (for open_url)", "setting": "wifi|bluetooth|display|sound|battery|storage|about (for open_settings)", "query": "string, search term (for list_apps)"}"""

    override fun execute(args: String): String {
        return try {
            val json = JSONObject(args)
            val action = json.optString("action", "").lowercase()

            when (action) {
                "open_app" -> openApp(json)
                "open_url" -> openUrl(json)
                "open_settings" -> openSettings(json)
                "list_apps" -> listApps(json)
                else -> "Error: Unknown action '$action'. Use open_app, open_url, open_settings, or list_apps."
            }
        } catch (e: Exception) {
            "Error: ${e.message}"
        }
    }

    private fun openApp(json: JSONObject): String {
        val packageName = json.optString("package_name", "")
        if (packageName.isBlank()) return "Error: 'package_name' required"

        val context = AIOSApp.instance
        val pm = context.packageManager
        val intent = pm.getLaunchIntentForPackage(packageName)
        if (intent != null) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            return "Opened $packageName"
        }
        return "Error: App '$packageName' not found or has no launch intent"
    }

    private fun openUrl(json: JSONObject): String {
        val url = json.optString("url", "")
        if (url.isBlank()) return "Error: 'url' required"

        val context = AIOSApp.instance
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
        return "Opened URL: $url"
    }

    private fun openSettings(json: JSONObject): String {
        val setting = json.optString("setting", "").lowercase()
        val context = AIOSApp.instance

        val intent = when (setting) {
            "wifi" -> Intent(Settings.ACTION_WIFI_SETTINGS)
            "bluetooth" -> Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
            "display" -> Intent(Settings.ACTION_DISPLAY_SETTINGS)
            "sound" -> Intent(Settings.ACTION_SOUND_SETTINGS)
            "battery" -> Intent(Intent.ACTION_POWER_USAGE_SUMMARY)
            "storage" -> Intent(Settings.ACTION_INTERNAL_STORAGE_SETTINGS)
            "about" -> Intent(Settings.ACTION_DEVICE_INFO_SETTINGS)
            "app_settings" -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", context.packageName, null))
            else -> return "Error: Unknown setting '$setting'"
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        return "Opened $setting settings"
    }

    private fun listApps(json: JSONObject): String {
        val context = AIOSApp.instance
        val pm = context.packageManager
        val query = json.optString("query", "").lowercase()

        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
            .filter { pm.getLaunchIntentForPackage(it.packageName) != null }
            .filter { query.isBlank() || it.packageName.contains(query) || (it.loadLabel(pm).toString().lowercase().contains(query)) }
            .sortedBy { it.loadLabel(pm).toString().lowercase() }
            .take(30)

        if (apps.isEmpty()) return "No apps found matching '$query'"

        return apps.mapIndexed { i, app ->
            "${i + 1}. ${app.loadLabel(pm)} (${app.packageName})"
        }.joinToString("\n")
    }
}
