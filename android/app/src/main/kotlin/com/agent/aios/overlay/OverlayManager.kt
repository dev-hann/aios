package com.agent.aios.overlay

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class OverlayManager(
    private val context: Context,
    private val messenger: io.flutter.plugin.common.BinaryMessenger,
) {
    companion object {
        private const val TAG = "AIOS-OverlayManager"
        private const val OVERLAY_CHANNEL = "com.agent.aios/overlay"
    }

    private var floatingButton: FloatingButtonView? = null
    private var chatOverlay: ChatOverlayView? = null
    private var overlayChannel: MethodChannel? = null
    private var isOverlayVisible = false

    fun setup() {
        overlayChannel = MethodChannel(messenger, OVERLAY_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "startOverlay" -> {
                        startOverlay()
                        result.success(true)
                    }
                    "stopOverlay" -> {
                        stopOverlay()
                        result.success(true)
                    }
                    "updateResult" -> {
                        val text = call.arguments as? String ?: ""
                        showResult(text)
                        result.success(true)
                    }
                    "isOverlayPermissionGranted" -> {
                        val granted = Settings.canDrawOverlays(context)
                        result.success(granted)
                    }
                    "requestOverlayPermission" -> {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:${context.packageName}"),
                        ).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        Log.d(TAG, "Overlay manager setup complete")
    }

    private fun startOverlay() {
        if (isOverlayVisible) return
        if (!Settings.canDrawOverlays(context)) {
            Log.e(TAG, "Overlay permission not granted")
            return
        }

        floatingButton = FloatingButtonView(context) {
            showChatOverlay()
        }.also { it.addToWindow() }

        isOverlayVisible = true
        Log.d(TAG, "Overlay started")
    }

    private fun stopOverlay() {
        chatOverlay?.removeFromWindow()
        chatOverlay = null
        floatingButton?.removeFromWindow()
        floatingButton = null
        isOverlayVisible = false
        Log.d(TAG, "Overlay stopped")
    }

    private fun showChatOverlay() {
        if (chatOverlay != null) return

        chatOverlay = ChatOverlayView(
            context,
            onSendMessage = { text ->
                sendToFlutter(text)
            },
            onClose = {
                chatOverlay?.removeFromWindow()
                chatOverlay = null
            },
        ).also { it.addToWindow() }

        chatOverlay?.post { chatOverlay?.focusInput() }
    }

    private fun showResult(text: String) {
        chatOverlay?.let {
            it.showResult(text)
            it.hideLoading()
        }
    }

    private fun sendToFlutter(text: String) {
        overlayChannel?.invokeMethod("onUserMessage", text)
    }

    fun dispose() {
        stopOverlay()
        overlayChannel?.setMethodCallHandler(null)
        overlayChannel = null
        Log.d(TAG, "Overlay manager disposed")
    }
}
