package com.agent.aios

class LlamaBridge {

    var onTokenCallback: ((String) -> Unit)? = null

    companion object {
        init {
            System.loadLibrary("aios-native")
        }
    }

    external fun nativeLoadModel(modelPath: String, contextSize: Int): Boolean
    external fun nativeFormatChat(roles: Array<String>, contents: Array<String>): String
    external fun nativeInfer(prompt: String, maxTokens: Int): Int
    external fun nativeReleaseModel()
    external fun nativeResetContext()
    external fun nativeIsModelLoaded(): Boolean
    external fun nativeGetModelInfo(): String
    external fun nativeGetContextUsage(): String
    external fun nativeSetSamplingParams(temperature: Float, topK: Int, topP: Float, repeatPenalty: Float)

    fun onTokenGenerated(token: String) {
        onTokenCallback?.invoke(token)
    }
}
