package com.agent.aios.data.model

import android.content.Context
import android.net.Uri
import android.os.Environment
import android.util.Log
import com.agent.aios.domain.model.ModelInfo
import com.agent.aios.domain.repository.ModelRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ModelRepositoryImpl @Inject constructor(
    @ApplicationContext private val context: Context,
) : ModelRepository {
    override fun scanModels(): List<ModelInfo> {
        val found = mutableListOf<ModelInfo>()

        val dir = File(context.filesDir, "models")
        if (!dir.exists()) dir.mkdirs()
        dir.listFiles()
            ?.filter { it.extension == "gguf" }
            ?.mapTo(found) { ModelInfo(it.name, it.length(), it.absolutePath) }

        val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (downloadDir.exists()) {
            downloadDir.listFiles()
                ?.filter { it.name.endsWith(".gguf") }
                ?.mapTo(found) { ModelInfo(it.name, it.length(), it.absolutePath) }
        }

        return found
    }

    override fun restoreModel(name: String): Boolean {
        val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val src = File(downloadDir, name)
        val dst = File(File(context.filesDir, "models"), name)

        if (!src.exists()) return false
        if (dst.exists()) return true

        dst.parentFile?.mkdirs()
        src.inputStream().use { input ->
            dst.outputStream().use { output ->
                input.copyTo(output, 8192)
            }
        }
        Log.i("ModelRepository", "Model restored: ${dst.length()} bytes")
        return true
    }

    override fun importModelFromUri(
        uri: Uri,
        fileName: String,
    ): Boolean {
        val modelsDir = File(context.filesDir, "models")
        if (!modelsDir.exists()) modelsDir.mkdirs()
        val safeName = if (fileName.endsWith(".gguf")) fileName else "$fileName.gguf"
        val dst = File(modelsDir, safeName)
        context.contentResolver.openInputStream(uri)?.use { input ->
            dst.outputStream().use { output ->
                input.copyTo(output, 8192)
            }
        } ?: return false
        Log.i("ModelRepository", "Model imported: ${dst.length()} bytes -> ${dst.absolutePath}")
        return true
    }
}
