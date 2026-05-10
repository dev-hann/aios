package com.agent.aios.overlay

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

class StatusOverlayView(context: Context) : FrameLayout(context) {
    companion object {
        private const val TAG = "AIOS-StatusOverlay"
    }

    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private val layoutParams = WindowManager.LayoutParams().apply {
        type = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        format = PixelFormat.TRANSLUCENT
        width = WindowManager.LayoutParams.WRAP_CONTENT
        height = WindowManager.LayoutParams.WRAP_CONTENT
        gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        y = 60
    }

    private val pillBackground = GradientDrawable().apply {
        setColor(0xE6333333.toInt())
        cornerRadius = 20f
    }

    private val textView: TextView

    init {
        background = pillBackground
        elevation = 12f

        textView = TextView(context).apply {
            setTextColor(Color.WHITE)
            textSize = 13f
            setPadding(24, 10, 24, 10)
            maxLines = 2
        }

        val container = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(textView)
        }

        addView(container)
    }

    fun updateText(text: String) {
        mainHandler.post {
            if (isAttachedToWindow) {
                textView.text = text
            }
        }
    }

    fun addToWindow() {
        try {
            windowManager.addView(this, layoutParams)
            Log.d(TAG, "Status overlay added")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add status overlay: ${e.message}")
        }
    }

    fun removeFromWindow() {
        try {
            if (isAttachedToWindow) {
                windowManager.removeView(this)
            }
            Log.d(TAG, "Status overlay removed")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to remove status overlay: ${e.message}")
        }
    }
}
