package com.agent.aios.ui.viewmodel

import android.app.Application
import com.agent.aios.update.ApkInstaller
import com.agent.aios.update.UpdateChecker
import com.agent.aios.update.UpdateDownloader
import com.agent.aios.update.UpdateInfo
import com.agent.aios.update.UpdateResult
import com.google.common.truth.Truth.assertThat
import io.mockk.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.*
import org.junit.After
import org.junit.Before
import org.junit.Test
import java.io.File

@OptIn(ExperimentalCoroutinesApi::class)
class UpdateViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var mockApplication: Application
    private lateinit var viewModel: UpdateViewModel

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        mockApplication = mockk(relaxed = true)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        unmockkAll()
    }

    private fun createViewModel(
        checkResult: UpdateResult = UpdateResult.NotAvailable,
        downloadResult: File? = null,
        canInstall: Boolean = true,
    ): UpdateViewModel {
        mockkConstructor(UpdateChecker::class)
        every { anyConstructed<UpdateChecker>().checkForUpdate() } returns checkResult

        mockkConstructor(UpdateDownloader::class)
        coEvery { anyConstructed<UpdateDownloader>().downloadApk(any(), any(), any()) } returns downloadResult

        mockkConstructor(ApkInstaller::class)
        every { anyConstructed<ApkInstaller>().canInstallApk() } returns canInstall
        every { anyConstructed<ApkInstaller>().installApk(any()) } returns true

        return UpdateViewModel(mockApplication)
    }

    private val testUpdateInfo = UpdateInfo(
        isUpdateAvailable = true,
        currentVersion = "1.0.0",
        latestVersion = "1.1.0",
        downloadUrl = "https://example.com/app.apk",
        fileSize = 1024L,
        releaseNotes = "Bug fixes",
        publishedAt = "2025-01-01",
    )

    private fun advance() {
        repeat(5) {
            testDispatcher.scheduler.advanceUntilIdle()
            Thread.sleep(100)
        }
        testDispatcher.scheduler.advanceUntilIdle()
    }

    @Test
    fun checkForUpdate_updateAvailable_setsStatusAvailable() {
        viewModel = createViewModel(checkResult = UpdateResult.Success(testUpdateInfo))

        viewModel.checkForUpdate()
        advance()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.AVAILABLE)
        assertThat(viewModel.updateInfo.value).isEqualTo(testUpdateInfo)
    }

    @Test
    fun checkForUpdate_noUpdate_setsStatusNotAvailable() {
        viewModel = createViewModel(checkResult = UpdateResult.NotAvailable)

        viewModel.checkForUpdate()
        advance()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.NOT_AVAILABLE)
    }

    @Test
    fun checkForUpdate_error_setsStatusError() {
        viewModel = createViewModel(checkResult = UpdateResult.Error("Network error"))

        viewModel.checkForUpdate()
        advance()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.ERROR)
        assertThat(viewModel.error.value).isEqualTo("Network error")
    }

    @Test
    fun checkForUpdate_setsCheckingThenResult() {
        viewModel = createViewModel(checkResult = UpdateResult.NotAvailable)

        viewModel.checkForUpdate()

        testDispatcher.scheduler.advanceUntilIdle()
        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.CHECKING)

        advance()
        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.NOT_AVAILABLE)
    }

    @Test
    fun checkForUpdate_exception_setsErrorStatus() {
        viewModel = createViewModel()
        every { anyConstructed<UpdateChecker>().checkForUpdate() } throws RuntimeException("Oops")

        viewModel.checkForUpdate()
        advance()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.ERROR)
        assertThat(viewModel.error.value).isEqualTo("Oops")
    }

    @Test
    fun checkForUpdate_updateNotAvailableFalse_setsNotAvailable() {
        val info = testUpdateInfo.copy(isUpdateAvailable = false, latestVersion = "1.0.0")
        viewModel = createViewModel(checkResult = UpdateResult.Success(info))

        viewModel.checkForUpdate()
        advance()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.NOT_AVAILABLE)
    }

    @Test
    fun downloadUpdate_success_setsStatusDownloaded() {
        val mockFile = mockk<File>()
        viewModel = createViewModel(
            checkResult = UpdateResult.Success(testUpdateInfo),
            downloadResult = mockFile,
        )

        viewModel.checkForUpdate()
        advance()

        viewModel.downloadUpdate()
        advance()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.DOWNLOADED)
    }

    @Test
    fun downloadUpdate_failure_setsErrorStatus() {
        viewModel = createViewModel(
            checkResult = UpdateResult.Success(testUpdateInfo),
            downloadResult = null,
        )

        viewModel.checkForUpdate()
        advance()

        viewModel.downloadUpdate()
        advance()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.ERROR)
        assertThat(viewModel.error.value).isEqualTo("Download failed")
    }

    @Test
    fun downloadUpdate_noUpdateInfo_returnsEarly() {
        viewModel = createViewModel()

        viewModel.downloadUpdate()
        advance()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.IDLE)
    }

    @Test
    fun downloadUpdate_progressUpdates() {
        val mockFile = mockk<File>()
        viewModel = createViewModel(
            checkResult = UpdateResult.Success(testUpdateInfo),
            downloadResult = mockFile,
        )
        coEvery { anyConstructed<UpdateDownloader>().downloadApk(any(), any(), captureLambda()) } answers {
            lambda<(Float) -> Unit>().captured.invoke(0.5f)
            mockFile
        }

        viewModel.checkForUpdate()
        advance()

        viewModel.downloadUpdate()
        advance()

        assertThat(viewModel.downloadProgress.value).isEqualTo(0.5f)
    }

    @Test
    fun installUpdate_canInstall_triggersInstall() {
        val mockFile = mockk<File>()
        viewModel = createViewModel(
            checkResult = UpdateResult.Success(testUpdateInfo),
            downloadResult = mockFile,
            canInstall = true,
        )

        viewModel.checkForUpdate()
        advance()

        viewModel.downloadUpdate()
        advance()

        viewModel.installUpdate()

        verify { anyConstructed<ApkInstaller>().installApk(mockFile) }
    }

    @Test
    fun installUpdate_cannotInstall_setsPermissionError() {
        val mockFile = mockk<File>()
        viewModel = createViewModel(
            checkResult = UpdateResult.Success(testUpdateInfo),
            downloadResult = mockFile,
            canInstall = false,
        )

        viewModel.checkForUpdate()
        advance()

        viewModel.downloadUpdate()
        advance()

        viewModel.installUpdate()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.ERROR)
        assertThat(viewModel.error.value).isEqualTo("INSTALL_PERMISSION_NEEDED")
    }

    @Test
    fun installUpdate_noDownloadedApk_returnsEarly() {
        viewModel = createViewModel()

        viewModel.installUpdate()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.IDLE)
    }

    @Test
    fun reset_resetsToIdle() {
        viewModel = createViewModel(checkResult = UpdateResult.Error("fail"))

        viewModel.checkForUpdate()
        advance()
        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.ERROR)

        viewModel.reset()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.IDLE)
        assertThat(viewModel.updateInfo.value).isNull()
        assertThat(viewModel.downloadProgress.value).isEqualTo(0f)
        assertThat(viewModel.error.value).isEmpty()
    }

    @Test
    fun initialStatus_isIdle() {
        viewModel = createViewModel()
        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.IDLE)
    }

    @Test
    fun initialError_isEmpty() {
        viewModel = createViewModel()
        assertThat(viewModel.error.value).isEmpty()
    }

    @Test
    fun initialDownloadProgress_isZero() {
        viewModel = createViewModel()
        assertThat(viewModel.downloadProgress.value).isEqualTo(0f)
    }
}
