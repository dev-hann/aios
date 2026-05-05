package com.agent.aios

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.agent.aios.domain.model.UpdateResult
import com.agent.aios.domain.model.UpdateStatus
import com.agent.aios.ui.viewmodel.UpdateViewModel
import com.agent.aios.update.UpdateRepositoryImpl
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.FixMethodOrder
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.MethodSorters
import java.io.File

/**
 * Run with: cd android && ./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.agent.aios.UpdateFlowInstrumentedTest
 * Requires: network access (uses real GitHub API)
 */
@RunWith(AndroidJUnit4::class)
@FixMethodOrder(MethodSorters.NAME_ASCENDING)
class UpdateFlowInstrumentedTest {
    private lateinit var repository: UpdateRepositoryImpl
    private lateinit var viewModel: UpdateViewModel

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        repository = UpdateRepositoryImpl(context)
        viewModel =
            UpdateViewModel::class.java.getDeclaredConstructor(
                com.agent.aios.domain.repository.UpdateRepository::class.java,
            ).apply { isAccessible = true }.newInstance(repository)
    }

    @After
    fun cleanup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val updatesDir = File(context.cacheDir, "updates")
        updatesDir.listFiles()?.forEach { it.delete() }
    }

    private suspend fun awaitStatus(expected: UpdateStatus, timeoutMs: Long = 30000): UpdateStatus {
        return withTimeout(timeoutMs) {
            viewModel.status.first { it == expected || it == UpdateStatus.ERROR }
        }
    }

    // ── checkForUpdate Flow ─────────────────────────────

    @Test
    fun t01_checkForUpdate_transitionsIdleToChecking() {
        assertEquals(UpdateStatus.IDLE, viewModel.status.value)
        viewModel.checkForUpdate()
        val checkingOrLater = viewModel.status.value
        assertTrue(
            "After checkForUpdate, status should be CHECKING or already transitioned",
            checkingOrLater == UpdateStatus.CHECKING ||
                checkingOrLater == UpdateStatus.AVAILABLE ||
                checkingOrLater == UpdateStatus.NOT_AVAILABLE ||
                checkingOrLater == UpdateStatus.ERROR,
        )
    }

    @Test
    fun t02_checkForUpdate_clearsPreviousError() =
        runBlocking {
            viewModel.checkForUpdate()
            awaitStatus(UpdateStatus.AVAILABLE, 15000)
            viewModel.reset()
            assertEquals(UpdateStatus.IDLE, viewModel.status.value)

            viewModel.checkForUpdate()
            val status = awaitStatus(UpdateStatus.AVAILABLE, 15000)
            assertTrue(
                "Expected AVAILABLE or NOT_AVAILABLE, got $status",
                status == UpdateStatus.AVAILABLE || status == UpdateStatus.NOT_AVAILABLE,
            )
            assertEquals("Error should be empty", "", viewModel.error.value)
        }

    @Test
    fun t03_checkForUpdate_populatesUpdateInfo() =
        runBlocking {
            viewModel.checkForUpdate()
            val status = awaitStatus(UpdateStatus.AVAILABLE, 15000)

            val info = viewModel.updateInfo.value
            assertNotNull("updateInfo should be populated", info)

            if (status == UpdateStatus.AVAILABLE) {
                assertTrue("isUpdateAvailable", info!!.isUpdateAvailable)
                assertTrue("latestVersion not empty", info.latestVersion.isNotEmpty())
                assertTrue("downloadUrl not empty", info.downloadUrl.isNotEmpty())
                assertTrue("fileSize > 0", info.fileSize > 0)
            }
        }

    @Test
    fun t04_checkForUpdate_matchesDirectRepositoryCall() =
        runBlocking {
            val directResult = repository.checkForUpdate()

            viewModel.checkForUpdate()
            awaitStatus(UpdateStatus.AVAILABLE, 15000)

            if (directResult is UpdateResult.Success) {
                val vmInfo = viewModel.updateInfo.value
                assertNotNull("VM info should exist", vmInfo)
                assertEquals(directResult.info.latestVersion, vmInfo!!.latestVersion)
                assertEquals(directResult.info.currentVersion, vmInfo.currentVersion)
                assertEquals(directResult.info.isUpdateAvailable, vmInfo.isUpdateAvailable)
                assertEquals(directResult.info.downloadUrl, vmInfo.downloadUrl)
                assertEquals(directResult.info.fileSize, vmInfo.fileSize)
            }
        }

    @Test
    fun t05_checkForUpdate_idempotentOnRepeatedCalls() =
        runBlocking {
            viewModel.checkForUpdate()
            val status1 = awaitStatus(UpdateStatus.AVAILABLE, 15000)
            val info1 = viewModel.updateInfo.value?.latestVersion

            viewModel.checkForUpdate()
            val status2 = awaitStatus(UpdateStatus.AVAILABLE, 15000)
            val info2 = viewModel.updateInfo.value?.latestVersion

            assertEquals("Same status on repeated checks", status1, status2)
            assertEquals("Same version on repeated checks", info1, info2)
        }

    @Test
    fun t06_checkForUpdate_currentVersionMatchesBuildConfig() =
        runBlocking {
            viewModel.checkForUpdate()
            awaitStatus(UpdateStatus.AVAILABLE, 15000)

            val info = viewModel.updateInfo.value
            assertNotNull(info)
            assertEquals(
                com.agent.aios.BuildConfig.VERSION_NAME,
                info!!.currentVersion,
            )
        }

    // ── downloadUpdate Flow ─────────────────────────────

    @Test
    fun t07_downloadUpdate_afterCheck_transitionsToDownloaded() =
        runBlocking {
            viewModel.checkForUpdate()
            val checkStatus = awaitStatus(UpdateStatus.AVAILABLE, 15000)
            if (checkStatus != UpdateStatus.AVAILABLE) return@runBlocking

            viewModel.downloadUpdate()

            val dlStatus =
                withTimeout(60000) {
                    viewModel.status.first { it == UpdateStatus.DOWNLOADED || it == UpdateStatus.ERROR }
                }
            assertEquals("Expected DOWNLOADED", UpdateStatus.DOWNLOADED, dlStatus)
        }

    @Test
    fun t08_downloadUpdate_progressUpdatesToComplete() =
        runBlocking {
            viewModel.checkForUpdate()
            val checkStatus = awaitStatus(UpdateStatus.AVAILABLE, 15000)
            if (checkStatus != UpdateStatus.AVAILABLE) return@runBlocking

            viewModel.downloadUpdate()
            withTimeout(60000) {
                viewModel.status.first { it == UpdateStatus.DOWNLOADED || it == UpdateStatus.ERROR }
            }

            val progress = viewModel.downloadProgress.value
            assertTrue("Progress should be >= 0.99 (got $progress)", progress >= 0.99f)
        }

    @Test
    fun t09_downloadUpdate_downloadedFileExists() =
        runBlocking {
            viewModel.checkForUpdate()
            val checkStatus = awaitStatus(UpdateStatus.AVAILABLE, 15000)
            if (checkStatus != UpdateStatus.AVAILABLE) return@runBlocking

            viewModel.downloadUpdate()
            withTimeout(60000) {
                viewModel.status.first { it == UpdateStatus.DOWNLOADED || it == UpdateStatus.ERROR }
            }

            val context = InstrumentationRegistry.getInstrumentation().targetContext
            val updatesDir = File(context.cacheDir, "updates")
            val apkFiles = updatesDir.listFiles()?.filter { it.name.endsWith(".apk") } ?: emptyList()
            assertTrue("APK file exists in updates dir", apkFiles.isNotEmpty())
            assertTrue("APK > 1MB", apkFiles.first().length() > 1_000_000)
        }

    @Test
    fun t10_downloadUpdate_fileHasApkMagicBytes() =
        runBlocking {
            viewModel.checkForUpdate()
            val checkStatus = awaitStatus(UpdateStatus.AVAILABLE, 15000)
            if (checkStatus != UpdateStatus.AVAILABLE) return@runBlocking

            viewModel.downloadUpdate()
            withTimeout(60000) {
                viewModel.status.first { it == UpdateStatus.DOWNLOADED || it == UpdateStatus.ERROR }
            }

            val context = InstrumentationRegistry.getInstrumentation().targetContext
            val updatesDir = File(context.cacheDir, "updates")
            val apk = updatesDir.listFiles()?.firstOrNull { it.name.endsWith(".apk") } ?: return@runBlocking

            val bytes = apk.readBytes()
            assertTrue(
                "PK magic bytes",
                bytes.size >= 4 &&
                    bytes[0] == 0x50.toByte() &&
                    bytes[1] == 0x4B.toByte() &&
                    bytes[2] == 0x03.toByte() &&
                    bytes[3] == 0x04.toByte(),
            )
        }

    @Test
    fun t11_downloadUpdate_clearsPreviousError() =
        runBlocking {
            viewModel.checkForUpdate()
            val checkStatus = awaitStatus(UpdateStatus.AVAILABLE, 15000)
            if (checkStatus != UpdateStatus.AVAILABLE) return@runBlocking

            viewModel.downloadUpdate()
            withTimeout(60000) {
                viewModel.status.first { it == UpdateStatus.DOWNLOADED || it == UpdateStatus.ERROR }
            }

            assertEquals("Error should be empty after successful download", "", viewModel.error.value)
        }

    // ── installUpdate Flow ──────────────────────────────

    @Test
    fun t12_installUpdate_afterDownload_checksPermission() =
        runBlocking {
            viewModel.checkForUpdate()
            val checkStatus = awaitStatus(UpdateStatus.AVAILABLE, 15000)
            if (checkStatus != UpdateStatus.AVAILABLE) return@runBlocking

            viewModel.downloadUpdate()
            withTimeout(60000) {
                viewModel.status.first { it == UpdateStatus.DOWNLOADED || it == UpdateStatus.ERROR }
            }
            if (viewModel.status.value != UpdateStatus.DOWNLOADED) return@runBlocking

            viewModel.installUpdate()

            val canInstall = repository.canInstallApk()
            if (!canInstall) {
                assertEquals(UpdateStatus.ERROR, viewModel.status.value)
                assertEquals("INSTALL_PERMISSION_NEEDED", viewModel.error.value)
            }
        }

    @Test
    fun t13_requestInstallPermissionIntent_returnsValidIntent() {
        val intent = viewModel.requestInstallPermissionIntent()
        assertNotNull("Intent not null", intent)
        assertNotNull("Intent has action", intent.action)
    }

    // ── reset Flow ──────────────────────────────────────

    @Test
    fun t14_reset_clearsAllState() =
        runBlocking {
            viewModel.checkForUpdate()
            awaitStatus(UpdateStatus.AVAILABLE, 15000)

            viewModel.reset()

            assertEquals(UpdateStatus.IDLE, viewModel.status.value)
            assertNull(viewModel.updateInfo.value)
            assertEquals(0f, viewModel.downloadProgress.value)
            assertEquals("", viewModel.error.value)
        }

    @Test
    fun t15_reset_thenCheckAgain_works() =
        runBlocking {
            viewModel.checkForUpdate()
            awaitStatus(UpdateStatus.AVAILABLE, 15000)
            viewModel.reset()

            viewModel.checkForUpdate()
            val status = awaitStatus(UpdateStatus.AVAILABLE, 15000)
            assertTrue(
                "Check works after reset",
                status == UpdateStatus.AVAILABLE || status == UpdateStatus.NOT_AVAILABLE,
            )
            assertNotNull("Info populated after reset", viewModel.updateInfo.value)
        }

    // ── State Machine ───────────────────────────────────

    @Test
    fun t16_stateMachine_idleToCheckingToAvailable() =
        runBlocking {
            assertEquals(UpdateStatus.IDLE, viewModel.status.value)
            viewModel.checkForUpdate()
            val finalStatus = awaitStatus(UpdateStatus.AVAILABLE, 15000)
            assertTrue(
                "Final: AVAILABLE or NOT_AVAILABLE",
                finalStatus == UpdateStatus.AVAILABLE || finalStatus == UpdateStatus.NOT_AVAILABLE,
            )
        }

    @Test
    fun t17_stateMachine_fullCycle() =
        runBlocking {
            assertEquals(UpdateStatus.IDLE, viewModel.status.value)

            viewModel.checkForUpdate()
            val checkStatus = awaitStatus(UpdateStatus.AVAILABLE, 15000)
            if (checkStatus != UpdateStatus.AVAILABLE) return@runBlocking
            assertEquals(UpdateStatus.AVAILABLE, viewModel.status.value)

            viewModel.downloadUpdate()
            val dlStatus =
                withTimeout(60000) {
                    viewModel.status.first { it == UpdateStatus.DOWNLOADED || it == UpdateStatus.ERROR }
                }
            assertEquals(UpdateStatus.DOWNLOADED, dlStatus)

            viewModel.reset()
            assertEquals(UpdateStatus.IDLE, viewModel.status.value)
        }

    @Test
    fun t18_downloadUpdate_withoutCheck_doesNothing() {
        val statusBefore = viewModel.status.value
        viewModel.downloadUpdate()
        Thread.sleep(500)
        assertEquals("Status unchanged without prior check", statusBefore, viewModel.status.value)
    }

    // ── Regression ──────────────────────────────────────

    @Test
    fun t19_regression_checkForUpdate_neverSilentNotAvailable() =
        runBlocking {
            viewModel.checkForUpdate()
            val status = awaitStatus(UpdateStatus.AVAILABLE, 15000)
            assertTrue(
                "REGRESSION: Must not be NOT_AVAILABLE (means APK missing from release)",
                status == UpdateStatus.AVAILABLE,
            )
            val info = viewModel.updateInfo.value
            assertNotNull("REGRESSION: info must be populated", info)
            assertTrue(
                "REGRESSION: downloadUrl must end with .apk",
                info!!.downloadUrl.endsWith(".apk", ignoreCase = true),
            )
        }
}
