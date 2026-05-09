package com.agent.aios.overlay

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView

class FloatingButtonView(
    context: Context,
    private val onClick: () -> Unit,
) : FrameLayout(context) {
    companion object {
        private const val TAG = "AIOS-FloatingBtn"
        private const val BUTTON_SIZE_DP = 48
    }

    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val layoutParams = WindowManager.LayoutParams().apply {
        type = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        format = PixelFormat.TRANSLUCENT
        width = BUTTON_SIZE_DP
        height = BUTTON_SIZE_DP
        gravity = Gravity.TOP or Gravity.START
        x = 0
        y = 300
    }

    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var isDragging = false

    private val icon: ImageView = ImageView(context).apply {
        setImageResource(android.R.drawable.ic_menu_compass)
        setColorFilter(Color.WHITE)
        val bg = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(0xFF4A90D9.toInt())
        }
        background = bg
        elevation = 8f
        setPadding(8, 8, 8, 8)
    }

    init {
        addView(icon, LayoutParams(
            LayoutParams.MATCH_PARENT,
            LayoutParams.MATCH_PARENT,
        ))
        setOnTouchListener(::handleTouch)
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun handleTouch(v: View, event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                initialX = layoutParams.x
                initialY = layoutParams.y
                initialTouchX = event.rawX
                initialTouchY = event.rawY
                isDragging = false
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - initialTouchX
                val dy = event.rawY - initialTouchY
                if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
                    isDragging = true
                }
                layoutParams.x = initialX + dx.toInt()
                layoutParams.y = initialY + dy.toInt()
                windowManager.updateViewLayout(this, layoutParams)
                return true
            }
            MotionEvent.ACTION_UP -> {
                if (!isDragging) {
                    onClick()
                }
                snapToEdge()
                return true
            }
        }
        return false
    }

    private fun snapToEdge() {
        val displayMetrics = context.resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val midX = screenWidth / 2
        layoutParams.x = if (layoutParams.x < midX) 0 else screenWidth - BUTTON_SIZE_DP
        layoutParams.y = layoutParams.y.coerceIn(0, displayMetrics.heightPixels - BUTTON_SIZE_DP)
        try {
            windowManager.updateViewLayout(this, layoutParams)
        } catch (e: Exception) {
            Log.e(TAG, "snapToEdge error: ${e.message}")
        }
    }

    fun addToWindow() {
        try {
            windowManager.addView(this, layoutParams)
            Log.d(TAG, "Floating button added")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add floating button: ${e.message}")
        }
    }

    fun removeFromWindow() {
        try {
            windowManager.removeView(this)
            Log.d(TAG, "Floating button removed")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to remove floating button: ${e.message}")
        }
    }
}
