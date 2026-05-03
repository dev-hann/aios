package com.agent.aios

import android.app.Application
import com.agent.aios.crash.CrashLogManager
import com.agent.aios.data.llm.LlmRepositoryImpl
import com.agent.aios.domain.repository.LlmRepository
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class AIOSApp : Application() {
    @Inject
    lateinit var llmRepository: LlmRepository

    @Inject
    lateinit var llmRepositoryImpl: LlmRepositoryImpl

    override fun onCreate() {
        super.onCreate()
        instance = this
        CrashLogManager.init(this)
        llmRepositoryImpl.checkForUpdateBackground()
    }

    companion object {
        lateinit var instance: AIOSApp
            private set
    }
}
