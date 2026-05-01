package com.agent.aios.update

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.util.concurrent.TimeUnit

class UpdateDownloader(private val context: Context) {

    private val TAG = "UpdateDownloader"

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    suspend fun downloadApk(
        url: String,
        fileName: String,
        onProgress: (Float) -> Unit,
    ): File? = withContext(Dispatchers.IO) {
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
}
