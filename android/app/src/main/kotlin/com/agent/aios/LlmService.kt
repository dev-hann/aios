package com.agent.aios

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import android.util.Log
import com.agent.aios.domain.LlmProvider

class LlmService : Service(), LlmProvider {
    private val TAG = "AIOS-Service"
    private val CHANNEL_ID = "aios_llm_channel"
    private val NOTIFICATION_ID = 1001

    private val binder = LlmBinder()
    private val llamaBridge: LlamaBridge? =
        if (LlamaBridge.libraryLoaded) LlamaBridge() else null
    private val callbackLock = Any()

    @Volatile
    private var tokenCallback: ((String) -> Unit)? = null

    inner class LlmBinder : Binder() {
        fun getService(): LlmService = this@LlmService
    }

    override fun onCreate() {
        super.onCreate()
        if (llamaBridge != null) {
            val initResult = llamaBridge.nativeInit(applicationInfo.nativeLibraryDir)
            if (initResult) {
                Log.i(TAG, "LlmService created")
            } else {
                Log.e(TAG, "LlmService created but nativeInit failed")
            }
        } else {
            Log.e(TAG, "LlmService created but native library not available")
        }
        createNotificationChannel()
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        val notification =
            buildNotification(
                if (llamaBridge != null) "AIOS ready" else "AIOS ready (native unavailable)",
            )
        startForeground(NOTIFICATION_ID, notification)
        Log.i(TAG, "LlmService started as foreground")
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder {
        Log.i(TAG, "LlmService bound")
        return binder
    }

    override fun onDestroy() {
        llamaBridge?.nativeReleaseModel()
        Log.i(TAG, "LlmService destroyed")
        super.onDestroy()
    }

    @Synchronized
    fun loadModel(
        path: String,
        contextSize: Int,
    ): Boolean {
        return llamaBridge?.nativeLoadModel(path, contextSize) ?: false
    }

    override fun formatChat(
        roles: Array<String>,
        contents: Array<String>,
    ): String {
        return llamaBridge?.nativeFormatChat(roles, contents) ?: ""
    }

    override fun processPrompt(prompt: String): Int {
        return llamaBridge?.nativeProcessPrompt(prompt) ?: -1
    }

    override fun processPromptIncremental(prompt: String): Int {
        return llamaBridge?.nativeProcessPromptIncremental(prompt) ?: -1
    }

    override fun setSystemPromptPosition() {
        llamaBridge?.nativeSetSystemPromptPosition()
    }

    override fun processSystemPrompt(prompt: String): Int {
        return llamaBridge?.nativeProcessSystemPrompt(prompt) ?: -1
    }

    override fun generateOneToken(): String? {
        val bridge = llamaBridge ?: return null
        val token = bridge.nativeGenerateOneToken()
        if (token != null && token.isNotEmpty()) {
            synchronized(callbackLock) {
                try {
                    tokenCallback?.invoke(token)
                } catch (e: Exception) {
                    Log.e(TAG, "tokenCallback error: ${e.message}", e)
                }
            }
        }
        return token
    }

    override fun generateTokensBatch(maxTokens: Int): String? {
        val bridge = llamaBridge ?: return null
        val result = bridge.nativeGenerateTokensBatch(maxTokens)
        if (result != null && result.isNotEmpty()) {
            synchronized(callbackLock) {
                try {
                    tokenCallback?.invoke(result)
                } catch (e: Exception) {
                    Log.e(TAG, "tokenCallback error: ${e.message}", e)
                }
            }
        }
        return result
    }

    override fun cancelGeneration() {
        llamaBridge?.nativeCancelGeneration()
    }

    override fun resetContext() {
        llamaBridge?.nativeResetContext()
    }

    override fun isModelLoaded(): Boolean {
        return llamaBridge?.nativeIsModelLoaded() ?: false
    }

    override fun getModelInfo(): String {
        return llamaBridge?.nativeGetModelInfo() ?: "Native library not loaded"
    }

    override fun releaseModel() {
        llamaBridge?.nativeReleaseModel()
    }

    override fun setTokenCallback(cb: ((String) -> Unit)?) {
        synchronized(callbackLock) {
            tokenCallback = cb
            llamaBridge?.onTokenCallback = cb
        }
    }

    override fun swapTokenCallback(cb: ((String) -> Unit)?): ((String) -> Unit)? {
        synchronized(callbackLock) {
            val prev = tokenCallback
            tokenCallback = cb
            llamaBridge?.onTokenCallback = cb
            return prev
        }
    }

    override fun getContextUsage(): String {
        return llamaBridge?.nativeGetContextUsage() ?: ""
    }

    fun getLoadProgress(): Float = llamaBridge?.nativeGetLoadProgress() ?: 0f

    fun getLoadStage(): Int = llamaBridge?.nativeGetLoadStage() ?: 0

    override fun setSamplingParams(
        temperature: Float,
        topK: Int,
        topP: Float,
        repeatPenalty: Float,
    ) {
        llamaBridge?.nativeSetSamplingParams(temperature, topK, topP, repeatPenalty)
    }

    override fun updateNotification(text: String) {
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(NOTIFICATION_ID, buildNotification(text))
    }

    private fun createNotificationChannel() {
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                "AIOS LLM Service",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps LLM running in background"
                setShowBadge(false)
            }
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(channel)
    }

    private fun buildNotification(text: String): Notification {
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("AIOS")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build()
    }
}
