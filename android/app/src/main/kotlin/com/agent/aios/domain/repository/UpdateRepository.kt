package com.agent.aios.domain.repository

import com.agent.aios.domain.model.UpdateResult
import java.io.File

interface UpdateRepository {
    suspend fun checkForUpdate(): UpdateResult
    suspend fun downloadApk(url: String, fileName: String, onProgress: (Float) -> Unit): File?
    fun canInstallApk(): Boolean
    fun installApk(apkFile: File): Boolean
    fun requestInstallPermissionIntent(): android.content.Intent
}
