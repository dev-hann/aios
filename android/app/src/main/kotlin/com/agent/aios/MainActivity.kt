package com.agent.aios

import android.Manifest
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Environment
import android.os.StatFs
import android.provider.ContactsContract
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityManager
import com.agent.aios.overlay.OverlayManager
import com.agent.aios.service.AiosForegroundService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "AIOS-Channel"
        private const val CHANNEL = "com.agent.aios/tools"
        private const val SERVICE_CHANNEL = "com.agent.aios/service"
    }

    private var overlayManager: OverlayManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            handleMethodCall(call.method, call.arguments, result)
        }

        overlayManager = OverlayManager(this, flutterEngine.dartExecutor.binaryMessenger)
        overlayManager?.setup()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SERVICE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    val intent = Intent(this, AiosForegroundService::class.java)
                    startForegroundService(intent)
                    result.success(true)
                }
                "stopForegroundService" -> {
                    val intent = Intent(this, AiosForegroundService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                "isForegroundServiceRunning" -> {
                    result.success(AiosForegroundService.isRunning)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        overlayManager?.dispose()
        overlayManager = null
        super.onDestroy()
    }

    @Suppress("UNCHECKED_CAST")
    private fun handleMethodCall(
        method: String,
        arguments: Any?,
        result: MethodChannel.Result,
    ) {
        try {
            val args = if (arguments is Map<*, *>) {
                arguments as Map<String, Any?>
            } else {
                emptyMap<String, Any?>()
            }

            when (method) {
                "isAccessibilityEnabled" -> {
                    val am = getSystemService(Context.ACCESSIBILITY_SERVICE)
                        as AccessibilityManager
                    val enabled = am.getEnabledAccessibilityServiceList(
                        AccessibilityServiceInfo.FEEDBACK_ALL_MASK,
                    ).any { it.id.contains("com.agent.aios") }
                    result.success(enabled)
                }

                "openAccessibilitySettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        },
                    )
                    result.success(true)
                }

                "getScreenText" -> {
                    val svc = AIOSAccessibilityService.getInstance()
                    if (svc == null) {
                        result.success("Error: Accessibility service not enabled")
                    } else {
                        result.success(svc.getScreenText())
                    }
                }

                "findNodesByText" -> {
                    val text = args["text"] as? String ?: ""
                    if (text.isBlank()) {
                        result.success("Error: 'text' required")
                        return
                    }
                    val svc = AIOSAccessibilityService.getInstance()
                    if (svc == null) {
                        result.success("Error: Accessibility service not enabled")
                        return
                    }
                    val nodes = svc.findNodesByText(text)
                    if (nodes.isEmpty()) {
                        result.success("No elements found matching '$text'")
                    } else {
                        val info = nodes.take(10).mapIndexed { i, node ->
                            "${i + 1}. ${svc.getNodeInfo(node)}"
                        }.joinToString("\n")
                        result.success(info)
                    }
                }

                "performTap" -> {
                    val x = (args["x"] as? Number)?.toFloat() ?: -1f
                    val y = (args["y"] as? Number)?.toFloat() ?: -1f
                    val svc = AIOSAccessibilityService.getInstance()
                    if (svc == null) {
                        result.success("Error: Accessibility service not enabled")
                    } else {
                        val success = svc.performTap(x, y)
                        result.success(if (success) "Tapped at ($x, $y)" else "Failed to tap")
                    }
                }

                "tapByText" -> {
                    val text = args["text"] as? String ?: ""
                    val svc = AIOSAccessibilityService.getInstance()
                    if (svc == null) {
                        result.success("Error: Accessibility service not enabled")
                    } else if (text.isBlank()) {
                        result.success("Error: 'text' required")
                    } else {
                        val nodes = svc.findNodesByText(text)
                        val clickable = nodes.firstOrNull { it.isClickable } ?: nodes.firstOrNull()
                        if (clickable == null) {
                            result.success("Element '$text' not found on screen")
                        } else {
                            val success = svc.clickNode(clickable)
                            result.success(if (success) "Tapped on '$text'" else "Failed to tap '$text'")
                        }
                    }
                }

                "longClickByText" -> {
                    val text = args["text"] as? String ?: ""
                    val svc = AIOSAccessibilityService.getInstance()
                    if (svc == null) {
                        result.success("Error: Accessibility service not enabled")
                    } else if (text.isBlank()) {
                        result.success("Error: 'text' required")
                    } else {
                        val nodes = svc.findNodesByText(text)
                        val node = nodes.firstOrNull { it.isLongClickable } ?: nodes.firstOrNull()
                        if (node == null) {
                            result.success("Element '$text' not found")
                        } else {
                            val success = svc.longClickNode(node)
                            result.success(if (success) "Long clicked on '$text'" else "Failed")
                        }
                    }
                }

                "typeText" -> {
                    val content = args["content"] as? String ?: ""
                    val target = args["target"] as? String ?: ""
                    val svc = AIOSAccessibilityService.getInstance()
                    if (svc == null) {
                        result.success("Error: Accessibility service not enabled")
                    } else if (content.isBlank()) {
                        result.success("Error: 'content' required")
                    } else {
                        val node = if (target.isNotBlank()) {
                            svc.findNodesByText(target).firstOrNull { it.isEditable }
                        } else {
                            findFocusedEditable(svc)
                        }
                        if (node == null) {
                            result.success("Error: No editable field found")
                        } else {
                            val success = svc.typeText(node, content)
                            result.success(if (success) "Typed '$content'" else "Failed to type")
                        }
                    }
                }

                "scroll" -> {
                    val direction = args["direction"] as? String ?: "forward"
                    val svc = AIOSAccessibilityService.getInstance()
                    if (svc == null) {
                        result.success("Error: Accessibility service not enabled")
                    } else {
                        val root = svc.rootInActiveWindow
                        if (root == null) {
                            result.success("Error: No active window")
                        } else {
                            val scrollable = findScrollableNode(root)
                            if (scrollable != null) {
                                val success = svc.scrollNode(scrollable, direction)
                                result.success(if (success) "Scrolled $direction" else "Failed to scroll")
                            } else {
                                result.success("No scrollable container found")
                            }
                        }
                    }
                }

                "swipe" -> {
                    val direction = args["direction"] as? String ?: "up"
                    val startX = (args["start_x"] as? Number)?.toFloat() ?: 540f
                    val startY = (args["start_y"] as? Number)?.toFloat() ?: 1500f
                    val distance = (args["distance"] as? Number)?.toFloat() ?: 500f
                    val svc = AIOSAccessibilityService.getInstance()
                    if (svc == null) {
                        result.success("Error: Accessibility service not enabled")
                    } else {
                        val (endX, endY) = when (direction) {
                            "up" -> Pair(startX, startY - distance)
                            "down" -> Pair(startX, startY + distance)
                            "left" -> Pair(startX - distance, startY)
                            "right" -> Pair(startX + distance, startY)
                            else -> {
                                result.success("Error: direction must be up/down/left/right")
                                return
                            }
                        }
                        val success = svc.performSwipe(startX, startY, endX, endY)
                        result.success(if (success) "Swiped $direction" else "Failed to swipe")
                    }
                }

                "performGlobalAction" -> {
                    val action = args["action"] as? String ?: ""
                    if (action.equals("enter", ignoreCase = true)) {
                        val svc = AIOSAccessibilityService.getInstance()
                        if (svc == null) {
                            result.success("Error: Accessibility service not enabled")
                        } else {
                            val success = svc.pressEnter()
                            result.success(if (success) "Pressed Enter" else "Failed to press Enter")
                        }
                    } else {
                        val svc = AIOSAccessibilityService.getInstance()
                        if (svc == null) {
                            result.success("Error: Accessibility service not enabled")
                        } else if (action.isBlank()) {
                            result.success("Error: 'action' required")
                        } else {
                            val success = svc.performGlobalAction(action)
                            result.success(if (success) "Performed: $action" else "Failed: $action")
                        }
                    }
                }

                "openApp" -> {
                    val packageName = args["package_name"] as? String ?: ""
                    if (packageName.isBlank()) {
                        result.success("Error: 'package_name' required")
                    } else {
                        Log.d("AIOS-OpenApp", "Attempting to open: $packageName")
                        result.success(launchApp(packageName))
                    }
                }

                "openUrl" -> {
                    val url = args["url"] as? String ?: ""
                    if (url.isBlank()) {
                        result.success("Error: 'url' required")
                    } else {
                        startActivity(
                            Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            },
                        )
                        result.success("Opened URL: $url")
                    }
                }

                "openSettings" -> {
                    val setting = (args["setting"] as? String ?: "").lowercase()
                    val intent = when (setting) {
                        "wifi" -> Settings.ACTION_WIFI_SETTINGS
                        "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
                        "display" -> Settings.ACTION_DISPLAY_SETTINGS
                        "sound" -> Settings.ACTION_SOUND_SETTINGS
                        "battery" -> Intent.ACTION_POWER_USAGE_SUMMARY
                        "storage" -> Settings.ACTION_INTERNAL_STORAGE_SETTINGS
                        "about" -> Settings.ACTION_DEVICE_INFO_SETTINGS
                        else -> {
                            result.success("Error: Unknown setting '$setting'")
                            return
                        }
                    }
                    startActivity(Intent(intent).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) })
                    result.success("Opened $setting settings")
                }

                "listApps" -> {
                    val query = (args["query"] as? String ?: "").lowercase()
                    val pm = packageManager
                    val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
                        .filter { pm.getLaunchIntentForPackage(it.packageName) != null }
                        .filter {
                            query.isBlank() ||
                                it.packageName.contains(query) ||
                                it.loadLabel(pm).toString().lowercase().contains(query)
                        }
                        .sortedBy { it.loadLabel(pm).toString().lowercase() }
                        .take(30)

                    if (apps.isEmpty()) {
                        result.success("No apps found matching '$query'")
                    } else {
                        val list = apps.mapIndexed { i, app ->
                            "${i + 1}. ${app.loadLabel(pm)} (${app.packageName})"
                        }.joinToString("\n")
                        result.success(list)
                    }
                }

                "getNotifications" -> {
                    val maxCount = (args["max_count"] as? Number)?.toInt() ?: 20
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE)
                        as android.app.NotificationManager
                    val notifications = nm.activeNotifications
                    if (notifications.isNullOrEmpty()) {
                        result.success("No active notifications")
                    } else {
                        val arr = JSONArray()
                        for (sbn in notifications.take(maxCount)) {
                            val obj = JSONObject().apply {
                                put("package", sbn.packageName)
                                put("postTime", sbn.postTime)
                                val extras = sbn.notification?.extras
                                if (extras != null) {
                                    put("title", extras.getCharSequence("android.title")?.toString() ?: "")
                                    put("text", extras.getCharSequence("android.text")?.toString() ?: "")
                                }
                            }
                            arr.put(obj)
                        }
                        result.success(arr.toString(2))
                    }
                }

                "searchContacts" -> {
                    val query = (args["query"] as? String ?: "").trim()
                    val limit = (args["limit"] as? Number)?.toInt() ?: 10
                    if (query.isBlank()) {
                        result.success("Error: 'query' required")
                    } else if (checkSelfPermission(Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
                        result.success("Error: READ_CONTACTS permission not granted")
                    } else {
                        val results = JSONArray()
                        contentResolver.query(
                            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                            arrayOf(
                                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                                ContactsContract.CommonDataKinds.Phone.NUMBER,
                            ),
                            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?",
                            arrayOf("%$query%"),
                            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC",
                        )?.use { cursor ->
                            while (cursor.moveToNext() && results.length() < limit) {
                                val name = cursor.getString(0) ?: continue
                                val phone = cursor.getString(1) ?: continue
                                results.put(JSONObject().apply {
                                    put("name", name)
                                    put("phone", phone)
                                })
                            }
                        }
                        result.success(
                            if (results.length() == 0) "No contacts found"
                            else results.toString(2),
                        )
                    }
                }

                "sendSms" -> {
                    val to = (args["to"] as? String ?: "").trim()
                    val body = (args["body"] as? String ?: "").trim()
                    if (to.isBlank() || body.isBlank()) {
                        result.success("Error: 'to' and 'body' required")
                    } else if (checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                        result.success("Error: SEND_SMS permission not granted")
                    } else {
                        val smsManager = if (android.os.Build.VERSION.SDK_INT >= 31) {
                            getSystemService(android.telephony.SmsManager::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            android.telephony.SmsManager.getDefault()
                        }
                        smsManager.sendTextMessage(to, null, body, null, null)
                        result.success("SMS sent to $to")
                    }
                }

                "readSms" -> {
                    val limit = (args["limit"] as? Number)?.toInt() ?: 10
                    if (checkSelfPermission(Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
                        result.success("Error: READ_SMS permission not granted")
                    } else {
                        val results = JSONArray()
                        contentResolver.query(
                            Uri.parse("content://sms/inbox"),
                            arrayOf("address", "body", "date"),
                            null, null, "date DESC",
                        )?.use { cursor ->
                            var count = 0
                            while (cursor.moveToNext() && count < limit) {
                                results.put(JSONObject().apply {
                                    put("from", cursor.getString(0) ?: "")
                                    put("body", cursor.getString(1) ?: "")
                                    put("date", cursor.getLong(2))
                                })
                                count++
                            }
                        }
                        result.success(
                            if (results.length() == 0) "No SMS messages found"
                            else results.toString(2),
                        )
                    }
                }

                "makeCall" -> {
                    val number = (args["number"] as? String ?: "").trim()
                    val action = (args["action"] as? String ?: "dial").lowercase()
                    if (number.isBlank()) {
                        result.success("Error: 'number' required")
                    } else if (action == "call" &&
                        checkSelfPermission(Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success("Error: CALL_PHONE permission not granted. Use 'dial' instead.")
                    } else {
                        val intentAction = if (action == "call") Intent.ACTION_CALL else Intent.ACTION_DIAL
                        startActivity(
                            Intent(intentAction, Uri.parse("tel:$number")).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            },
                        )
                        result.success(if (action == "call") "Calling $number" else "Dialing $number")
                    }
                }

                "getDeviceInfo" -> {
                    val info = JSONObject().apply {
                        put("device", android.os.Build.MODEL)
                        put("manufacturer", android.os.Build.MANUFACTURER)
                        put("android_version", android.os.Build.VERSION.RELEASE)
                        put("sdk_int", android.os.Build.VERSION.SDK_INT)
                        val runtime = Runtime.getRuntime()
                        put("jvm_max_mb", runtime.maxMemory() / 1048576)
                        put("jvm_total_mb", runtime.totalMemory() / 1048576)
                        put("jvm_free_mb", runtime.freeMemory() / 1048576)
                    }
                    result.success(info.toString(2))
                }

                "getBatteryInfo" -> {
                    val bm = getSystemService(Context.BATTERY_SERVICE)
                        as android.os.BatteryManager
                    val level = bm.getIntProperty(
                        android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY
                    )
                    val charging = bm.isCharging
                    val info = JSONObject().apply {
                        put("level", level)
                        put("charging", charging)
                    }
                    result.success(info.toString(2))
                }

                "getStorageInfo" -> {
                    val statFs = android.os.StatFs(
                        Environment.getDataDirectory().path
                    )
                    val totalBytes = statFs.totalBytes
                    val availableBytes = statFs.availableBytes
                    val usedBytes = totalBytes - availableBytes
                    val info = JSONObject().apply {
                        put("total_gb",
                            String.format("%.1f", totalBytes / 1e9))
                        put("used_gb",
                            String.format("%.1f", usedBytes / 1e9))
                        put("available_gb",
                            String.format("%.1f", availableBytes / 1e9))
                        put("usage_percent",
                            if (totalBytes > 0)
                                ((usedBytes * 100) / totalBytes).toInt()
                            else 0)
                    }
                    result.success(info.toString(2))
                }

                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Method call error: ${e.message}", e)
            result.success("Error: ${e.message}")
        }
    }

    private fun findFocusedEditable(svc: AIOSAccessibilityService): android.view.accessibility.AccessibilityNodeInfo? {
        val root = svc.rootInActiveWindow ?: return null
        return findFocusedEditableRecursive(root)
    }

    private fun findFocusedEditableRecursive(
        node: android.view.accessibility.AccessibilityNodeInfo,
    ): android.view.accessibility.AccessibilityNodeInfo? {
        if (node.isEditable && node.isFocused) return node
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { child ->
                findFocusedEditableRecursive(child)?.let { return it }
            }
        }
        return null
    }

    private fun findScrollableNode(
        node: android.view.accessibility.AccessibilityNodeInfo,
    ): android.view.accessibility.AccessibilityNodeInfo? {
        if (node.isScrollable) return node
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { child ->
                findScrollableNode(child)?.let { return it }
            }
        }
        return null
    }

    private fun launchApp(packageName: String): String {
        val pm = packageManager

        // Tier 1: Standard approach
        val launchIntent = pm.getLaunchIntentForPackage(packageName)
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(launchIntent)
            Log.d("AIOS-OpenApp", "Tier 1 success: $packageName")
            return "Opened $packageName"
        }
        Log.w("AIOS-OpenApp", "Tier 1 failed (getLaunchIntentForPackage=null) for: $packageName")

        // Tier 2: Query MAIN/LAUNCHER activities manually
        val queryIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
            setPackage(packageName)
        }
        val resolveInfos = pm.queryIntentActivities(queryIntent, 0)
        if (resolveInfos.isNotEmpty()) {
            val info = resolveInfos[0].activityInfo
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
                setComponent(ComponentName(info.packageName, info.name))
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            Log.d("AIOS-OpenApp", "Tier 2 success: $packageName -> ${info.name}")
            return "Opened $packageName"
        }
        Log.w("AIOS-OpenApp", "Tier 2 failed (queryIntentActivities=empty) for: $packageName")

        // Tier 3: Get ANY exported activity from the package
        try {
            val packageInfo = pm.getPackageInfo(packageName, PackageManager.GET_ACTIVITIES)
            val activity = packageInfo.activities?.firstOrNull { it.exported }
            if (activity != null) {
                val intent = Intent(Intent.ACTION_MAIN).apply {
                    setComponent(ComponentName(activity.packageName, activity.name))
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                Log.d("AIOS-OpenApp", "Tier 3 success: $packageName -> ${activity.name}")
                return "Opened $packageName"
            }
            Log.w("AIOS-OpenApp", "Tier 3 failed (no exported activities) for: $packageName")
            val activityCount = packageInfo.activities?.size ?: 0
            Log.w("AIOS-OpenApp", "Package has $activityCount activities, none exported")
        } catch (e: Exception) {
            Log.e("AIOS-OpenApp", "Tier 3 exception for $packageName: ${e.message}")
        }

        Log.e("AIOS-OpenApp", "All tiers failed for: $packageName")
        return "Error: Cannot launch '$packageName' - no launchable activity found"
    }
}
