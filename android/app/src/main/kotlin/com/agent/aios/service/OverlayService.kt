package com.agent.aios.service

import android.annotation.SuppressLint
import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import com.agent.aios.AIOSApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

class OverlayService : Service() {

    companion object {
        var isRunning = false
            private set
    }

    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    private var params: WindowManager.LayoutParams? = null
    private var stateJob: Job? = null

    override fun onBind(intent: Intent?): IBinder? = null

    @SuppressLint("ClickableViewAccessibility")
    override fun onCreate() {
        super.onCreate()
        isRunning = true
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 200
        }

        val icon = ImageView(this)
        icon.setImageResource(android.R.drawable.ic_dialog_info)
        icon.setPadding(16, 16, 16, 16)
        updateIconColor(icon, AIOSApp.instance.serviceState.replayCache.firstOrNull())

        stateJob = CoroutineScope(Dispatchers.Main).launch {
            AIOSApp.instance.serviceState.collect { state ->
                updateIconColor(icon, state)
            }
        }

        icon.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f
            private var isMoved = false

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                val p = params ?: return false
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = p.x
                        initialY = p.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        isMoved = false
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()
                        if (dx * dx + dy * dy > 100) isMoved = true
                        p.x = initialX + dx
                        p.y = initialY + dy
                        windowManager?.updateViewLayout(overlayView, p)
                    }
                    MotionEvent.ACTION_UP -> {
                        if (!isMoved) {
                            openAIOS()
                        }
                    }
                }
                return true
            }
        })

        overlayView = icon
        windowManager?.addView(overlayView, params)
    }

    private fun updateIconColor(icon: ImageView, state: AIOSApp.ServiceState?) {
        val color = when (state) {
            AIOSApp.ServiceState.GENERATING, AIOSApp.ServiceState.AGENT_RUNNING -> 0x80FFB74D.toInt()
            AIOSApp.ServiceState.MODEL_LOADED -> 0x8000D4AA.toInt()
            AIOSApp.ServiceState.READY -> 0x807C5CFC.toInt()
            else -> 0x803F51B5.toInt()
        }
        icon.setBackgroundColor(color)
    }

    private fun openAIOS() {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        if (intent != null) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            startActivity(intent)
        }
    }

    override fun onDestroy() {
        isRunning = false
        stateJob?.cancel()
        super.onDestroy()
        overlayView?.let {
            windowManager?.removeView(it)
        }
        overlayView = null
    }
}
