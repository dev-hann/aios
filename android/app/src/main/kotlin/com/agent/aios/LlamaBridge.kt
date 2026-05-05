package com.agent.aios

import android.util.Log

class LlamaBridge {
    private val TAG = "AIOS-Bridge"

    var onTokenCallback: ((String) -> Unit)? = null

    companion object {
        var libraryLoaded: Boolean = false
            private set

        init {
            libraryLoaded =
                try {
                    System.loadLibrary("aios-native")
                    Log.i("AIOS-Bridge", "aios-native library loaded successfully")
                    true
                } catch (e: UnsatisfiedLinkError) {
                    Log.e("AIOS-Bridge", "Failed to load aios-native library", e)
                    false
                } catch (e: Exception) {
                    Log.e("AIOS-Bridge", "Failed to load aios-native library", e)
                    false
                }
        }
    }

    external fun nativeInit(nativeLibDir: String): Boolean

    external fun nativeLoadModel(
        modelPath: String,
        contextSize: Int,
    ): Boolean

    external fun nativeFormatChat(
        roles: Array<String>,
        contents: Array<String>,
    ): String

    external fun nativeProcessPrompt(prompt: String): Int

    external fun nativeProcessPromptIncremental(prompt: String): Int

    external fun nativeGenerateOneToken(): String?

    external fun nativeGenerateTokensBatch(maxTokens: Int): String?

    external fun nativeCancelGeneration()

    external fun nativeReleaseModel()

    external fun nativeResetContext()

    external fun nativeIsModelLoaded(): Boolean

    external fun nativeGetModelInfo(): String

    external fun nativeGetLoadProgress(): Float

    external fun nativeGetLoadStage(): Int

    external fun nativeGetContextUsage(): String

    external fun nativeSetSamplingParams(
        temperature: Float,
        topK: Int,
        topP: Float,
        repeatPenalty: Float,
    )

    external fun nativeSetSystemPromptPosition()

    external fun nativeProcessSystemPrompt(prompt: String): Int

    fun onTokenGenerated(token: String) {
        try {
            onTokenCallback?.invoke(token)
        } catch (e: Exception) {
            Log.e(TAG, "onTokenCallback error: ${e.message}", e)
        }
    }
}
