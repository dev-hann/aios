package com.agent.aios.update

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import com.agent.aios.BuildConfig
import com.agent.aios.domain.model.UpdateInfo
import com.agent.aios.domain.model.UpdateResult
import com.agent.aios.domain.repository.UpdateRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class UpdateRepositoryImpl
    @Inject
    constructor(
        @ApplicationContext private val context: Context,
    ) : UpdateRepository {
        private val TAG = "AIOS-UpdateRepo"
        private val api = GitHubReleaseApi(BuildConfig.GITHUB_REPO)

        private val client =
            OkHttpClient.Builder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(60, TimeUnit.SECONDS)
                .build()

        override suspend fun checkForUpdate(): UpdateResult {
            return try {
                val release = withContext(Dispatchers.IO) { api.getLatestRelease() }
                val latestVersion = release.tag_name.removePrefix("v")
                val currentVersion = BuildConfig.VERSION_NAME

                val apkAsset =
                    release.assets.find {
                        it.name.endsWith(".apk", ignoreCase = true)
                    } ?: return UpdateResult.NotAvailable

                val isUpdateAvailable = compareVersions(currentVersion, latestVersion) < 0

                UpdateResult.Success(
                    UpdateInfo(
                        isUpdateAvailable = isUpdateAvailable,
                        currentVersion = currentVersion,
                        latestVersion = latestVersion,
                        downloadUrl = apkAsset.browser_download_url,
                        fileSize = apkAsset.size,
                        releaseNotes = release.body,
                        publishedAt = release.published_at,
                    ),
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to check for update: ${e.message}")
                UpdateResult.Error(e.message ?: "Unknown error")
            }
        }

        override suspend fun downloadApk(
            url: String,
            fileName: String,
            onProgress: (Float) -> Unit,
        ): File? =
            withContext(Dispatchers.IO) {
                try {
                    val updatesDir = File(context.cacheDir, "updates")
                    if (!updatesDir.exists()) updatesDir.mkdirs()
                    updatesDir.listFiles()?.forEach { it.delete() }

                    val targetFile = File(updatesDir, fileName)
                    val request = Request.Builder().url(url).build()

                    val response = client.newCall(request).execute()
                    if (!response.isSuccessful) {
                        Log.e(TAG, "Download failed: ${response.code}")
                        return@withContext null
                    }

                    val body = response.body ?: return@withContext null
                    val contentLength = body.contentLength()

                    body.byteStream().use { input ->
                        targetFile.outputStream().use { output ->
                            val buffer = ByteArray(8192)
                            var totalRead = 0L
                            var lastProgress = -1f

                            while (true) {
                                val read = input.read(buffer)
                                if (read == -1) break
                                output.write(buffer, 0, read)
                                totalRead += read

                                if (contentLength > 0) {
                                    val progress = (totalRead.toFloat() / contentLength)
                                    if (progress - lastProgress > 0.01f) {
                                        lastProgress = progress
                                        onProgress(progress)
                                    }
                                }
                            }
                        }
                    }

                    onProgress(1f)
                    Log.i(TAG, "Download complete: ${targetFile.length()} bytes")
                    targetFile
                } catch (e: Exception) {
                    Log.e(TAG, "Download error: ${e.message}")
                    null
                }
            }

        override fun canInstallApk(): Boolean {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.packageManager.canRequestPackageInstalls()
            } else {
                true
            }
        }

        override fun requestInstallPermissionIntent(): Intent {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                    data = Uri.parse("package:${context.packageName}")
                }
            } else {
                Intent(Settings.ACTION_SETTINGS)
            }
        }

        override fun installApk(apkFile: File): Boolean {
            return try {
                val uri =
                    FileProvider.getUriForFile(
                        context,
                        "${context.packageName}.fileprovider",
                        apkFile,
                    )
                val intent =
                    Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                context.startActivity(intent)
                Log.i(TAG, "Install intent launched for ${apkFile.name}")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Install failed: ${e.message}")
                false
            }
        }

        private fun compareVersions(
            v1: String,
            v2: String,
        ): Int {
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
