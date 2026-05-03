package com.agent.aios.domain.repository

import com.agent.aios.domain.model.ConversationMessage

interface ConversationRepository {
    fun save(messages: List<ConversationMessage>)
    fun load(): List<ConversationMessage>
    fun clear()
    fun appendMessage(role: String, content: String)
}
