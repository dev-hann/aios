package gyo.plugins.app_launcher

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import gyo.plugins.bridge.BridgeHandler
import org.json.JSONArray
import org.json.JSONObject

class AppLauncherBridge(private val context: Context) : BridgeHandler {

    companion object {
        private const val TAG = "AIOS-AppLauncher"
    }

    override fun handle(method: String, data: JSONObject): Any? {
        return when (method) {
            "list_apps" -> listApps()
            "open_app" -> openApp(data)
            "open_url" -> openUrl(data)
            "search_apps" -> searchApps(data)
            else -> {
                Log.w(TAG, "Unknown method: $method")
                null
            }
        }
    }

    private fun listApps(): JSONObject {
        val pm = context.packageManager
        val apps = pm.getInstalledApplications(0)
        val appArray = JSONArray()

        for (app in apps) {
            val launchIntent = pm.getLaunchIntentForPackage(app.packageName)
            if (launchIntent != null) {
                val appInfo = JSONObject().apply {
                    put("packageName", app.packageName)
                    put("name", app.loadLabel(pm).toString())
                }
                appArray.put(appInfo)
            }
        }

        return JSONObject().apply {
            put("apps", appArray)
            put("count", appArray.length())
        }
    }

    private fun openApp(data: JSONObject): Boolean {
        val packageName = data.optString("packageName", "")
        if (packageName.isEmpty()) {
            Log.w(TAG, "open_app: packageName is empty")
            return false
        }

        val intent = context.packageManager.getLaunchIntentForPackage(packageName)
        if (intent == null) {
            Log.w(TAG, "open_app: app not found - $packageName")
            return false
        }

        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        Log.d(TAG, "Opened app: $packageName")
        return true
    }

    private fun openUrl(data: JSONObject): Boolean {
        val url = data.optString("url", "")
        if (url.isEmpty()) {
            Log.w(TAG, "open_url: url is empty")
            return false
        }

        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            context.startActivity(intent)
            Log.d(TAG, "Opened URL: $url")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "open_url: failed to open $url", e)
            return false
        }
    }

    private fun searchApps(data: JSONObject): JSONObject {
        val query = data.optString("query", "").lowercase()
        val pm = context.packageManager
        val apps = pm.getInstalledApplications(0)
        val resultArray = JSONArray()

        for (app in apps) {
            val launchIntent = pm.getLaunchIntentForPackage(app.packageName)
            if (launchIntent != null) {
                val appName = app.loadLabel(pm).toString()
                val pkgName = app.packageName
                if (appName.lowercase().contains(query) || pkgName.lowercase().contains(query)) {
                    val appInfo = JSONObject().apply {
                        put("packageName", pkgName)
                        put("name", appName)
                    }
                    resultArray.put(appInfo)
                }
            }
        }

        return JSONObject().apply {
            put("apps", resultArray)
            put("count", resultArray.length())
        }
    }
}
