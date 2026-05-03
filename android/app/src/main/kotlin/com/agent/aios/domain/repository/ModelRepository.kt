package com.agent.aios.domain.repository

import com.agent.aios.domain.model.ModelInfo
import android.net.Uri

interface ModelRepository {
    fun scanModels(): List<ModelInfo>
    fun restoreModel(name: String): Boolean
    fun importModelFromUri(uri: Uri, fileName: String): Boolean
}
