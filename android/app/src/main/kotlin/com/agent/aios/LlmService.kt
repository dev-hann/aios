package com.agent.aios

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import android.util.Log

class LlmService : Service() {

    private val TAG = "AIOS-Service"
    private val CHANNEL_ID = "aios_llm_channel"
    private val NOTIFICATION_ID = 1001

    private val binder = LlmBinder()
    private val llamaBridge = LlamaBridge()
    private var agentEngine: AgentEngine? = null

    inner class LlmBinder : Binder() {
        fun getService(): LlmService = this@LlmService
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.i(TAG, "LlmService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification("AIOS ready")
        startForeground(NOTIFICATION_ID, notification)
        Log.i(TAG, "LlmService started as foreground")
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder {
        Log.i(TAG, "LlmService bound")
        return binder
    }

    override fun onDestroy() {
        llamaBridge.nativeReleaseModel()
        agentEngine = null
        Log.i(TAG, "LlmService destroyed")
        super.onDestroy()
    }

    fun loadModel(path: String, contextSize: Int): Boolean {
        val result = llamaBridge.nativeLoadModel(path, contextSize)
        if (result) {
            agentEngine = AgentEngine(this)
        }
        return result
    }

    fun generate(prompt: String, maxTokens: Int): String {
        return llamaBridge.nativeGenerate(prompt, maxTokens)
    }

    fun generateStream(prompt: String, maxTokens: Int): Int {
        return llamaBridge.nativeGenerateStream(prompt, maxTokens)
    }

    fun generateStreamStandalone(prompt: String, maxTokens: Int): Int {
        return llamaBridge.nativeGenerateStreamStandalone(prompt, maxTokens)
    }

    fun resetContext() {
        llamaBridge.nativeResetContext()
    }

    fun isModelLoaded(): Boolean {
        return llamaBridge.nativeIsModelLoaded()
    }

    fun getModelInfo(): String {
        return llamaBridge.nativeGetModelInfo()
    }

    fun releaseModel() {
        llamaBridge.nativeReleaseModel()
        agentEngine = null
    }

    fun setTokenCallback(cb: ((String) -> Unit)?) {
        llamaBridge.onTokenCallback = cb
    }

    fun swapTokenCallback(cb: ((String) -> Unit)?): ((String) -> Unit)? {
        val prev = llamaBridge.onTokenCallback
        llamaBridge.onTokenCallback = cb
        return prev
    }

    fun getAgentEngine(): AgentEngine? = agentEngine

    fun updateNotification(text: String) {
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(NOTIFICATION_ID, buildNotification(text))
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "AIOS LLM Service",
            NotificationManager.IMPORTANCE_LOW
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
