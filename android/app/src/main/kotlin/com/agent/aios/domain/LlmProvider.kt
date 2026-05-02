package com.agent.aios.domain

interface LlmProvider {
    fun processPrompt(prompt: String): Int
    fun processPromptIncremental(prompt: String): Int
    fun processSystemPrompt(prompt: String): Int
    fun generateOneToken(): String?
    fun formatChat(roles: Array<String>, contents: Array<String>): String
    fun setSystemPromptPosition()
    fun resetContext()
    fun getContextUsage(): String
    fun isModelLoaded(): Boolean
    fun getModelInfo(): String
    fun setSamplingParams(temperature: Float, topK: Int, topP: Float, repeatPenalty: Float)
    fun releaseModel()
    fun updateNotification(text: String)
    fun setTokenCallback(cb: ((String) -> Unit)?)
    fun swapTokenCallback(cb: ((String) -> Unit)?): ((String) -> Unit)?
}
