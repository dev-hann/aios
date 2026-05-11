package gyo.plugins.device_info

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import gyo.plugins.bridge.BridgeHandler
import org.json.JSONObject

class DeviceInfoBridge(private val context: Context) : BridgeHandler {

    companion object {
        private const val TAG = "AIOS-DeviceInfo"
    }

    override fun handle(method: String, data: JSONObject): Any? {
        return when (method) {
            "get_info" -> getInfo()
            else -> {
                Log.w(TAG, "Unknown method: $method")
                null
            }
        }
    }

    private fun getInfo(): JSONObject {
        val displayMetrics = getDisplayMetrics()
        val batteryInfo = getBatteryInfo()

        val info = JSONObject().apply {
            put("manufacturer", Build.MANUFACTURER ?: "Unknown")
            put("model", Build.MODEL ?: "Unknown")
            put("brand", Build.BRAND ?: "Unknown")
            put("device", Build.DEVICE ?: "Unknown")
            put("androidVersion", Build.VERSION.RELEASE ?: "Unknown")
            put("sdkVersion", Build.VERSION.SDK_INT)
            put("securityPatch", getSecurityPatch())
            put("screenDensity", displayMetrics.densityDpi)
            put("screenWidth", displayMetrics.widthPixels)
            put("screenHeight", displayMetrics.heightPixels)
            put("batteryLevel", batteryInfo.first)
            put("isCharging", batteryInfo.second)
        }

        return JSONObject().apply {
            put("info", info)
        }
    }

    private fun getSecurityPatch(): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Build.VERSION.SECURITY_PATCH ?: "Unknown"
        } else {
            "Unknown"
        }
    }

    private fun getDisplayMetrics(): DisplayMetrics {
        val metrics = DisplayMetrics()
        val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        windowManager.defaultDisplay.getRealMetrics(metrics)
        return metrics
    }

    private fun getBatteryInfo(): Pair<Int, Boolean> {
        val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)

        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        val batteryStatus = context.registerReceiver(null, filter)

        val isCharging = batteryStatus?.let { status ->
            val chargeStatus = status.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
            chargeStatus == BatteryManager.BATTERY_STATUS_CHARGING ||
                chargeStatus == BatteryManager.BATTERY_STATUS_FULL
        } ?: false

        return Pair(level, isCharging)
    }
}
