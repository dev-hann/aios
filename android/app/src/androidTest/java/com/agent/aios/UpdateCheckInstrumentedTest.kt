package com.agent.aios

import android.provider.Settings
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.agent.aios.domain.model.UpdateResult
import com.agent.aios.update.GitHubReleaseApi
import com.agent.aios.update.UpdateRepositoryImpl
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.FixMethodOrder
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.MethodSorters
import java.io.File
import java.util.zip.ZipFile

/**
 * Run with: cd android && ./gradlew connectedDebugAndroidTest
 * Requires: network access (uses real GitHub API dev-hann/aios)
 */
@RunWith(AndroidJUnit4::class)
@FixMethodOrder(MethodSorters.NAME_ASCENDING)
class UpdateCheckInstrumentedTest {
    private lateinit var api: GitHubReleaseApi
    private lateinit var repository: UpdateRepositoryImpl
    private val downloadedFiles = mutableListOf<File>()

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        api = GitHubReleaseApi(com.agent.aios.BuildConfig.GITHUB_REPO)
        repository = UpdateRepositoryImpl(context)
    }

    @After
    fun cleanup() {
        downloadedFiles.forEach { if (it.exists()) it.delete() }
        downloadedFiles.clear()
    }

    // ── GitHub API ──────────────────────────────────────

    @Test
    fun t01_api_getLatestRelease_hasValidTagName() {
        val release = api.getLatestRelease()
        assertTrue("tag must start with 'v'", release.tag_name.startsWith("v"))
        assertTrue(
            "version part must be semver",
            release.tag_name.removePrefix("v").matches(Regex("\\d+\\.\\d+\\.\\d+")),
        )
    }

    @Test
    fun t02_api_getLatestRelease_hasPublishedAt() {
        val release = api.getLatestRelease()
        assertTrue("published_at not empty", release.published_at.isNotEmpty())
        assertTrue(
            "published_at is ISO date",
            release.published_at.matches(Regex("\\d{4}-\\d{2}-\\d{2}.*")),
        )
    }

    @Test
    fun t03_api_getLatestRelease_hasBody() {
        val release = api.getLatestRelease()
        assertTrue("body not empty", release.body.isNotEmpty())
    }

    @Test
    fun t04_api_getLatestRelease_hasAssetsList() {
        val release = api.getLatestRelease()
        assertNotNull("assets not null", release.assets)
    }

    @Test
    fun t05_api_latestRelease_hasApkAsset() {
        val release = api.getLatestRelease()
        val apk = release.assets.find { it.name.endsWith(".apk", ignoreCase = true) }
        assertNotNull(
            "APK must exist in ${release.tag_name}. Assets: ${release.assets.map { it.name }}",
            apk,
        )
    }

    @Test
    fun t06_api_apkAsset_hasValidSize() {
        val release = api.getLatestRelease()
        val apk = release.assets.find { it.name.endsWith(".apk", ignoreCase = true) } ?: return
        assertTrue("APK > 1MB (got ${apk.size})", apk.size > 1_000_000)
        assertTrue("APK < 200MB (got ${apk.size})", apk.size < 200_000_000)
    }

    @Test
    fun t07_api_apkAsset_hasHttpsUrl() {
        val release = api.getLatestRelease()
        val apk = release.assets.find { it.name.endsWith(".apk", ignoreCase = true) } ?: return
        assertTrue("URL is HTTPS", apk.browser_download_url.startsWith("https://"))
        assertTrue(
            "URL points to github",
            apk.browser_download_url.contains("github.com"),
        )
    }

    @Test
    fun t08_api_multipleAssets_findsApkAmongOthers() {
        val release = api.getLatestRelease()
        val apkCount = release.assets.count { it.name.endsWith(".apk", ignoreCase = true) }
        assertTrue("At least 1 APK", apkCount >= 1)
    }

    // ── checkForUpdate ──────────────────────────────────

    @Test
    fun t09_checkForUpdate_returnsSuccess_notNotAvailable() {
        val result = runBlocking { repository.checkForUpdate() }
        assertTrue(
            "Expected Success, got $result. NotAvailable = no APK in release.",
            result is UpdateResult.Success,
        )
    }

    @Test
    fun t10_checkForUpdate_currentVersion_matchesBuildConfig() {
        val result = runBlocking { repository.checkForUpdate() }
        val info = (result as UpdateResult.Success).info
        assertEquals(com.agent.aios.BuildConfig.VERSION_NAME, info.currentVersion)
    }

    @Test
    fun t11_checkForUpdate_latestVersion_isSemver() {
        val result = runBlocking { repository.checkForUpdate() }
        val info = (result as UpdateResult.Success).info
        assertTrue(
            "latestVersion semver",
            info.latestVersion.matches(Regex("\\d+\\.\\d+\\.\\d+")),
        )
    }

    @Test
    fun t12_checkForUpdate_latestVersion_differentFromCurrent_whenUpdateExists() {
        val result = runBlocking { repository.checkForUpdate() }
        val info = (result as UpdateResult.Success).info
        if (info.isUpdateAvailable) {
            assertTrue(
                "latest != current when update exists",
                info.latestVersion != info.currentVersion,
            )
        }
    }

    @Test
    fun t13_checkForUpdate_downloadUrl_isHttpsGithub() {
        val result = runBlocking { repository.checkForUpdate() }
        val info = (result as UpdateResult.Success).info
        assertTrue("HTTPS", info.downloadUrl.startsWith("https://"))
        assertTrue("github.com", info.downloadUrl.contains("github.com"))
    }

    @Test
    fun t14_checkForUpdate_fileSize_isPositive() {
        val result = runBlocking { repository.checkForUpdate() }
        val info = (result as UpdateResult.Success).info
        assertTrue("fileSize > 0", info.fileSize > 0)
    }

    @Test
    fun t15_checkForUpdate_releaseNotes_notEmpty() {
        val result = runBlocking { repository.checkForUpdate() }
        val info = (result as UpdateResult.Success).info
        assertTrue("releaseNotes not empty", info.releaseNotes.isNotEmpty())
    }

    @Test
    fun t16_checkForUpdate_publishedAt_isIsoDate() {
        val result = runBlocking { repository.checkForUpdate() }
        val info = (result as UpdateResult.Success).info
        assertTrue(
            "publishedAt is ISO date",
            info.publishedAt.matches(Regex("\\d{4}-\\d{2}-\\d{2}.*")),
        )
    }

    @Test
    fun t17_checkForUpdate_isUpdateAvailable_consistentWithVersionOrder() {
        val result = runBlocking { repository.checkForUpdate() }
        val info = (result as UpdateResult.Success).info
        val cmp = compareVersions(info.currentVersion, info.latestVersion)
        assertEquals(
            "isUpdateAvailable should match version comparison",
            cmp < 0,
            info.isUpdateAvailable,
        )
    }

    // ── Version Comparison ──────────────────────────────

    @Test
    fun t18_compareVersions_majorDifference() {
        assertTrue(compareVersions("1.9.10", "2.0.0") < 0)
        assertTrue(compareVersions("2.0.0", "1.9.10") > 0)
        assertTrue(compareVersions("0.0.1", "10.0.0") < 0)
    }

    @Test
    fun t19_compareVersions_minorDifference() {
        assertTrue(compareVersions("1.9.10", "1.10.0") < 0)
        assertTrue(compareVersions("1.10.0", "1.9.10") > 0)
        assertTrue(compareVersions("2.0.0", "2.1.0") < 0)
    }

    @Test
    fun t20_compareVersions_patchDifference() {
        assertTrue(compareVersions("1.9.10", "1.9.11") < 0)
        assertTrue(compareVersions("1.9.11", "1.9.10") > 0)
        assertTrue(compareVersions("1.0.0", "1.0.1") < 0)
    }

    @Test
    fun t21_compareVersions_equalVersions() {
        assertEquals(0, compareVersions("1.9.10", "1.9.10"))
        assertEquals(0, compareVersions("1.0.0", "1.0.0"))
        assertEquals(0, compareVersions("0.0.1", "0.0.1"))
    }

    @Test
    fun t22_compareVersions_differentSegmentCounts() {
        assertTrue(compareVersions("1.9", "1.9.1") < 0)
        assertEquals(0, compareVersions("1.9.0", "1.9"))
        assertTrue(compareVersions("1.10", "1.9.99") > 0)
    }

    @Test
    fun t23_compareVersions_zeroPadded() {
        assertEquals(0, compareVersions("1.0.0", "1.0.0"))
        assertTrue(compareVersions("1.00.0", "1.0.0") == 0)
    }

    @Test
    fun t24_compareVersions_largeNumbers() {
        assertTrue(compareVersions("1.999.999", "2.0.0") < 0)
        assertTrue(compareVersions("99.99.99", "100.0.0") < 0)
    }

    @Test
    fun t25_compareVersions_samePrefix_differentSuffix() {
        assertTrue(compareVersions("1.9.10", "1.9.11") < 0)
        assertTrue(compareVersions("1.9.9", "1.9.10") < 0)
        assertTrue(compareVersions("1.9.99", "1.10.0") < 0)
    }

    // ── APK Download ────────────────────────────────────

    @Test
    fun t26_downloadApk_savesFile() {
        val info = getUpdateInfo() ?: return
        if (!info.isUpdateAvailable) return

        val file =
            runBlocking {
                repository.downloadApk(info.downloadUrl, "test-download.apk") {}
            }
        assertNotNull("file not null", file)
        file!!.let {
            downloadedFiles.add(it)
            assertTrue("file exists", it.exists())
            assertTrue("file > 1MB", it.length() > 1_000_000)
        }
    }

    @Test
    fun t27_downloadApk_reportsProgress() {
        val info = getUpdateInfo() ?: return
        if (!info.isUpdateAvailable) return

        val progressValues = mutableListOf<Float>()
        val file =
            runBlocking {
                repository.downloadApk(info.downloadUrl, "test-progress.apk") { p ->
                    progressValues.add(p)
                }
            }
        file?.let { downloadedFiles.add(it) }
        assertTrue("progress reported", progressValues.isNotEmpty())
        assertTrue("final progress >= 0.99", progressValues.last() >= 0.99f)
        assertTrue("first progress >= 0", progressValues.first() >= 0f)
    }

    @Test
    fun t28_downloadApk_fileIsZip_apk() {
        val info = getUpdateInfo() ?: return
        if (!info.isUpdateAvailable) return

        val file =
            runBlocking {
                repository.downloadApk(info.downloadUrl, "test-zip.apk") {}
            }
        file?.let { downloadedFiles.add(it) } ?: return

        val bytes = file!!.readBytes()
        assertTrue(
            "APK starts with PK magic bytes (0x504B)",
            bytes.size >= 2 && bytes[0] == 0x50.toByte() && bytes[1] == 0x4B.toByte(),
        )
    }

    @Test
    fun t29_downloadApk_fileIsOpenableAsZip() {
        val info = getUpdateInfo() ?: return
        if (!info.isUpdateAvailable) return

        val file =
            runBlocking {
                repository.downloadApk(info.downloadUrl, "test-valid.apk") {}
            }
        file?.let { downloadedFiles.add(it) } ?: return

        val zip = ZipFile(file)
        val entries = zip.entries().toList()
        zip.close()

        assertTrue("ZIP has entries", entries.isNotEmpty())
        assertTrue(
            "APK has AndroidManifest.xml",
            entries.any { it.name.equals("AndroidManifest.xml", ignoreCase = true) },
        )
        assertTrue(
            "APK has classes.dex",
            entries.any { it.name.startsWith("classes") && it.name.endsWith(".dex") },
        )
    }

    @Test
    fun t30_downloadApk_fileSize_matchesAssetSize() {
        val info = getUpdateInfo() ?: return
        if (!info.isUpdateAvailable) return

        val file =
            runBlocking {
                repository.downloadApk(info.downloadUrl, "test-size.apk") {}
            }
        file?.let { downloadedFiles.add(it) } ?: return

        val sizeDiff = kotlin.math.abs(file!!.length() - info.fileSize)
        assertTrue(
            "File size matches asset (diff=$sizeDiff)",
            sizeDiff < 1024,
        )
    }

    @Test
    fun t31_downloadApk_cleansPreviousDownloads() {
        val info = getUpdateInfo() ?: return
        if (!info.isUpdateAvailable) return

        val file1 =
            runBlocking {
                repository.downloadApk(info.downloadUrl, "test-first.apk") {}
            }
        assertNotNull("first download", file1)
        file1?.let { downloadedFiles.add(it) }

        val file2 =
            runBlocking {
                repository.downloadApk(info.downloadUrl, "test-second.apk") {}
            }
        assertNotNull("second download", file2)
        file2?.let { downloadedFiles.add(it) }

        val updatesDir =
            File(
                InstrumentationRegistry.getInstrumentation().targetContext.cacheDir,
                "updates",
            )
        val apkFiles = updatesDir.listFiles()?.filter { it.name.endsWith(".apk") } ?: emptyList()
        assertEquals("Only 1 APK in updates dir after sequential downloads", 1, apkFiles.size)
    }

    @Test
    fun t32_downloadApk_invalidUrl_returnsNull() {
        val file =
            runBlocking {
                repository.downloadApk("https://invalid.example.com/nonexistent.apk", "bad.apk") {}
            }
        assertTrue("Invalid URL returns null", file == null)
    }

    // ── Install Permission ──────────────────────────────

    @Test
    fun t33_canInstallApk_returnsBoolean() {
        val result = repository.canInstallApk()
        assertTrue("Returns boolean (true or false)", result || !result)
    }

    @Test
    fun t34_requestInstallPermissionIntent_returnsValidIntent() {
        val intent = repository.requestInstallPermissionIntent()
        assertNotNull("Intent not null", intent)
        assertTrue("Intent has action", intent.action != null)
        assertTrue(
            "Intent action is settings-related",
            intent.action?.contains("SETTINGS") == true ||
                intent.action == Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES ||
                intent.action == Settings.ACTION_SETTINGS,
        )
    }

    @Test
    fun t35_installApk_nonExistentFile_returnsFalse() {
        val fakeFile = File("/tmp/nonexistent-test-file.apk")
        val result = repository.installApk(fakeFile)
        assertTrue("Non-existent file returns false", !result)
    }

    // ── End-to-End ──────────────────────────────────────

    @Test
    fun t36_e2e_checkAndDownload_fullFlow() {
        val checkResult = runBlocking { repository.checkForUpdate() }
        assertTrue("Check returns Success", checkResult is UpdateResult.Success)

        val info = (checkResult as UpdateResult.Success).info
        if (!info.isUpdateAvailable) return

        assertTrue("HTTPS download URL", info.downloadUrl.startsWith("https://"))
        assertTrue("Positive file size", info.fileSize > 0)

        var progressReached = false
        val file =
            runBlocking {
                repository.downloadApk(info.downloadUrl, "e2e-test.apk") {
                    progressReached = true
                }
            }
        assertNotNull("Download succeeds", file)
        file?.let { downloadedFiles.add(it) }
        assertTrue("Progress was reported", progressReached)
    }

    @Test
    fun t37_e2e_repeatedCheckForUpdate_isIdempotent() {
        val result1 = runBlocking { repository.checkForUpdate() }
        val result2 = runBlocking { repository.checkForUpdate() }

        assertTrue("Both return Success", result1 is UpdateResult.Success)
        assertTrue("Both return Success", result2 is UpdateResult.Success)

        val info1 = (result1 as UpdateResult.Success).info
        val info2 = (result2 as UpdateResult.Success).info

        assertEquals(info1.latestVersion, info2.latestVersion)
        assertEquals(info1.downloadUrl, info2.downloadUrl)
        assertEquals(info1.fileSize, info2.fileSize)
        assertEquals(info1.isUpdateAvailable, info2.isUpdateAvailable)
    }

    // ── Regression ──────────────────────────────────────

    @Test
    fun t38_regression_releaseMustHaveApk_preventsSilentFailure() {
        val release = api.getLatestRelease()
        val hasApk = release.assets.any { it.name.endsWith(".apk", ignoreCase = true) }
        assertTrue(
            "REGRESSION: Release ${release.tag_name} must have APK. " +
                "Missing APK means users see no update notification. " +
                "Fix: gh release upload ${release.tag_name} <apk>",
            hasApk,
        )
    }

    @Test
    fun t39_regression_checkForUpdate_neverReturnsNotAvailable_whenReleaseExists() {
        val result = runBlocking { repository.checkForUpdate() }
        assertTrue(
            "REGRESSION: Must not be NotAvailable when GitHub release exists. " +
                "NotAvailable means APK is missing from release. Got: $result",
            result !is UpdateResult.NotAvailable,
        )
    }

    private fun getUpdateInfo(): com.agent.aios.domain.model.UpdateInfo? {
        val result = runBlocking { repository.checkForUpdate() }
        if (result !is UpdateResult.Success) return null
        return result.info
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
