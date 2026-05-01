package com.agent.aios.update

import android.content.Context
import android.util.Log
import com.agent.aios.BuildConfig

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

class UpdateChecker(private val context: Context) {

    private val TAG = "UpdateChecker"
    private val api = GitHubReleaseApi(BuildConfig.GITHUB_REPO)

    fun checkForUpdate(): UpdateResult {
        return try {
            val release = api.getLatestRelease()
            val latestVersion = release.tag_name.removePrefix("v")
            val currentVersion = BuildConfig.VERSION_NAME

            val apkAsset = release.assets.find {
                it.name.endsWith(".apk", ignoreCase = true)
            } ?: return UpdateResult.NotAvailable

            val isUpdateAvailable = compareVersions(currentVersion, latestVersion) < 0

            UpdateResult.Success(UpdateInfo(
                isUpdateAvailable = isUpdateAvailable,
                currentVersion = currentVersion,
                latestVersion = latestVersion,
                downloadUrl = apkAsset.browser_download_url,
                fileSize = apkAsset.size,
                releaseNotes = release.body,
                publishedAt = release.published_at,
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check for update: ${e.message}")
            UpdateResult.Error(e.message ?: "Unknown error")
        }
    }

    @Suppress("unused")
    fun checkForUpdateLegacy(): UpdateInfo? {
        return when (val result = checkForUpdate()) {
            is UpdateResult.Success -> result.info
            else -> null
        }
    }

    private fun compareVersions(v1: String, v2: String): Int {
        val parts1 = v1.split(".").map { it.toIntOrNull() ?: 0 }
        val parts2 = v2.split(".").map { it.toIntOrNull() ?: 0 }
        val maxLen = maxOf(parts1.size, parts2.size)
        for (i in 0 until maxLen) {
            val p1 = parts1.getOrElse(i) { 0 }
            val p2 = parts2.getOrElse(i) { 0 }
            if (p1 != p2) return p1.compareTo(p2)
        }
        return 0
    }
}
