package com.agent.aios.update

import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

data class GitHubRelease(
    val tag_name: String,
    val name: String,
    val body: String,
    val assets: List<GitHubAsset>,
    val published_at: String,
)

data class GitHubAsset(
    val name: String,
    val browser_download_url: String,
    val size: Long,
)

class GitHubReleaseApi(private val repo: String) {

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    private val gson = Gson()

    fun getLatestRelease(): GitHubRelease {
        val url = "https://api.github.com/repos/$repo/releases/latest"
        val request = Request.Builder()
            .url(url)
            .header("Accept", "application/vnd.github+json")
            .build()

        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw Exception("GitHub API error: ${response.code}")
            }
            val body = response.body?.string()
                ?: throw Exception("Empty response")
            return gson.fromJson(body, GitHubRelease::class.java)
        }
    }
}
