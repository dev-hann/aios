package com.agent.aios.domain.repository

import android.net.Uri
import com.agent.aios.domain.model.ModelInfo

interface ModelRepository {
    fun scanModels(): List<ModelInfo>

    fun restoreModel(name: String): Boolean

    fun importModelFromUri(uri: Uri, fileName: String): Boolean
}
