package com.agent.aios.overlay

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.util.Log
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView

class ChatOverlayView(
    context: Context,
    private val onSendMessage: (String) -> Unit,
    private val onClose: () -> Unit,
) : FrameLayout(context) {
    companion object {
        private const val TAG = "AIOS-ChatOverlay"
        private const val OVERLAY_WIDTH = 340
        private const val OVERLAY_HEIGHT = 420
    }

    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val layoutParams = WindowManager.LayoutParams().apply {
        type = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
        format = PixelFormat.TRANSLUCENT
        width = OVERLAY_WIDTH
        height = OVERLAY_HEIGHT
        gravity = Gravity.CENTER
    }

    private val resultTextView: TextView
    private val scrollView: ScrollView
    private val progressBar: ProgressBar
    private val inputEditText: EditText
    private val sendButton: Button

    private val cardBackground = GradientDrawable().apply {
        setColor(0xFFF5F5F5.toInt())
        cornerRadius = 16f
        setStroke(1, 0xFFDDDDDD.toInt())
    }

    init {
        background = cardBackground
        elevation = 16f
        setPadding(16, 16, 16, 16)

        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LayoutParams(
                LayoutParams.MATCH_PARENT,
                LayoutParams.MATCH_PARENT,
            )
        }

        val titleBar = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LayoutParams.MATCH_PARENT,
                LayoutParams.WRAP_CONTENT,
            )
        }

        val title = TextView(context).apply {
            text = "AIOS"
            setTextColor(Color.BLACK)
            textSize = 16f
            layoutParams = LinearLayout.LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f)
        }

        val closeBtn = TextView(context).apply {
            text = "✕"
            setTextColor(Color.GRAY)
            textSize = 20f
            setPadding(8, 0, 0, 0)
            setOnClickListener {
                hideKeyboard()
                onClose()
            }
        }

        titleBar.addView(title)
        titleBar.addView(closeBtn)

        scrollView = ScrollView(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                LayoutParams.MATCH_PARENT,
                0,
                1f,
            )
        }

        resultTextView = TextView(context).apply {
            text = "명령을 입력하세요."
            setTextColor(Color.DKGRAY)
            textSize = 14f
            setPadding(0, 8, 0, 8)
            layoutParams = LayoutParams(
                LayoutParams.MATCH_PARENT,
                LayoutParams.WRAP_CONTENT,
            )
        }
        scrollView.addView(resultTextView)

        progressBar = ProgressBar(context).apply {
            visibility = GONE
            layoutParams = LinearLayout.LayoutParams(
                LayoutParams.WRAP_CONTENT,
                LayoutParams.WRAP_CONTENT,
            ).apply {
                gravity = Gravity.CENTER
            }
        }

        val inputContainer = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LayoutParams.MATCH_PARENT,
                LayoutParams.WRAP_CONTENT,
            )
            setPadding(0, 8, 0, 0)
        }

        val inputBg = GradientDrawable().apply {
            setColor(Color.WHITE)
            cornerRadius = 8f
            setStroke(1, 0xFFCCCCCC.toInt())
        }

        inputEditText = EditText(context).apply {
            hint = "명령 입력..."
            setTextColor(Color.BLACK)
            setHintTextColor(Color.GRAY)
            textSize = 14f
            background = inputBg
            setPadding(12, 8, 12, 8)
            isSingleLine = true
            imeOptions = EditorInfo.IME_ACTION_SEND
            layoutParams = LinearLayout.LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f).apply {
                setMargins(0, 0, 8, 0)
            }
            setOnEditorActionListener { _, actionId, event ->
                if (actionId == EditorInfo.IME_ACTION_SEND ||
                    (event?.action == KeyEvent.ACTION_DOWN && event.keyCode == KeyEvent.KEYCODE_ENTER)
                ) {
                    sendInput()
                    true
                } else {
                    false
                }
            }
        }

        sendButton = Button(context).apply {
            text = "전송"
            textSize = 13f
            setTextColor(Color.WHITE)
            val btnBg = GradientDrawable().apply {
                setColor(0xFF4A90D9.toInt())
                cornerRadius = 8f
            }
            background = btnBg
            setPadding(16, 8, 16, 8)
            layoutParams = LinearLayout.LayoutParams(
                LayoutParams.WRAP_CONTENT,
                LayoutParams.WRAP_CONTENT,
            )
            setOnClickListener { sendInput() }
        }

        inputContainer.addView(inputEditText)
        inputContainer.addView(sendButton)

        container.addView(titleBar)
        container.addView(scrollView)
        container.addView(progressBar)
        container.addView(inputContainer)
        addView(container)
    }

    private fun sendInput() {
        val text = inputEditText.text.toString().trim()
        if (text.isEmpty()) return
        inputEditText.text.clear()
        hideKeyboard()
        showLoading()
        resultTextView.text = "처리 중..."
        onSendMessage(text)
    }

    fun showResult(text: String) {
        progressBar.visibility = GONE
        resultTextView.text = text
        scrollView.post { scrollView.fullScroll(View.FOCUS_DOWN) }
    }

    fun showLoading() {
        progressBar.visibility = VISIBLE
        sendButton.isEnabled = false
    }

    fun hideLoading() {
        progressBar.visibility = GONE
        sendButton.isEnabled = true
    }

    fun focusInput() {
        inputEditText.requestFocus()
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.showSoftInput(inputEditText, InputMethodManager.SHOW_IMPLICIT)
    }

    private fun hideKeyboard() {
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.hideSoftInputFromWindow(windowToken, 0)
    }

    fun addToWindow() {
        try {
            windowManager.addView(this, layoutParams)
            Log.d(TAG, "Chat overlay added")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add chat overlay: ${e.message}")
        }
    }

    fun removeFromWindow() {
        hideKeyboard()
        try {
            windowManager.removeView(this)
            Log.d(TAG, "Chat overlay removed")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to remove chat overlay: ${e.message}")
        }
    }
}
