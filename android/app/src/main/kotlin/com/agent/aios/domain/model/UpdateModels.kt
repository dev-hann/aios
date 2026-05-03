package com.agent.aios.domain.model

data class UpdateInfo(
    val isUpdateAvailable: Boolean,
    val currentVersion: String,
    val latestVersion: String,
    val downloadUrl: String,
    val fileSize: Long,
    val releaseNotes: String,
    val publishedAt: String,
)

sealed class UpdateResult {
    data class Success(val info: UpdateInfo) : UpdateResult()

    data object NotAvailable : UpdateResult()

    data class Error(val message: String) : UpdateResult()
}

enum class UpdateStatus {
    IDLE,
    CHECKING,
    AVAILABLE,
    NOT_AVAILABLE,
    DOWNLOADING,
    DOWNLOADED,
    INSTALLING,
    ERROR,
}
