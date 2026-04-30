package com.agent.aios

class LlamaBridge {

    var onTokenCallback: ((String) -> Unit)? = null

    companion object {
        init {
            System.loadLibrary("aios-native")
        }
    }

    external fun nativeLoadModel(modelPath: String, contextSize: Int): Boolean
    external fun nativeGenerate(prompt: String, maxTokens: Int): String
    external fun nativeGenerateStream(prompt: String, maxTokens: Int): Int
    external fun nativeGenerateStreamStandalone(prompt: String, maxTokens: Int): Int
    external fun nativeReleaseModel()
    external fun nativeResetContext()
    external fun nativeIsModelLoaded(): Boolean
    external fun nativeGetModelInfo(): String

    fun onTokenGenerated(token: String) {
        onTokenCallback?.invoke(token)
    }
}
