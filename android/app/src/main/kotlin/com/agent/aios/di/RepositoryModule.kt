package com.agent.aios.di

import com.agent.aios.data.ConversationRepositoryImpl
import com.agent.aios.data.llm.LlmRepositoryImpl
import com.agent.aios.data.model.ModelRepositoryImpl
import com.agent.aios.domain.repository.ConversationRepository
import com.agent.aios.domain.repository.LlmRepository
import com.agent.aios.domain.repository.ModelRepository
import com.agent.aios.domain.repository.SettingsRepository
import com.agent.aios.domain.repository.UpdateRepository
import com.agent.aios.settings.SettingsRepositoryImpl
import com.agent.aios.update.UpdateRepositoryImpl
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {
    @Binds
    @Singleton
    abstract fun bindLlmRepository(impl: LlmRepositoryImpl): LlmRepository

    @Binds
    @Singleton
    abstract fun bindModelRepository(impl: ModelRepositoryImpl): ModelRepository

    @Binds
    @Singleton
    abstract fun bindConversationRepository(impl: ConversationRepositoryImpl): ConversationRepository

    @Binds
    @Singleton
    abstract fun bindSettingsRepository(impl: SettingsRepositoryImpl): SettingsRepository

    @Binds
    @Singleton
    abstract fun bindUpdateRepository(impl: UpdateRepositoryImpl): UpdateRepository
}
