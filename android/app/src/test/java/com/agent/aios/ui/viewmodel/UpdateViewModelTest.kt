package com.agent.aios.ui.viewmodel

import com.agent.aios.domain.model.UpdateInfo
import com.agent.aios.domain.model.UpdateResult
import com.agent.aios.domain.model.UpdateStatus
import com.agent.aios.domain.repository.UpdateRepository
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
    private lateinit var mockRepo: UpdateRepository
    private lateinit var viewModel: UpdateViewModel

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        mockRepo = mockk(relaxed = true)
        viewModel = UpdateViewModel(mockRepo)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        unmockkAll()
    }

    private val testUpdateInfo =
        UpdateInfo(
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
        coEvery { mockRepo.checkForUpdate() } returns UpdateResult.Success(testUpdateInfo)

        viewModel.checkForUpdate()
        advance()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.AVAILABLE)
        assertThat(viewModel.updateInfo.value).isEqualTo(testUpdateInfo)
    }

    @Test
    fun checkForUpdate_noUpdate_setsStatusNotAvailable() {
        coEvery { mockRepo.checkForUpdate() } returns UpdateResult.NotAvailable

        viewModel.checkForUpdate()
        advance()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.NOT_AVAILABLE)
    }

    @Test
    fun checkForUpdate_error_setsStatusError() {
        coEvery { mockRepo.checkForUpdate() } returns UpdateResult.Error("Network error")

        viewModel.checkForUpdate()
        advance()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.ERROR)
        assertThat(viewModel.error.value).isEqualTo("Network error")
    }

    @Test
    fun checkForUpdate_setsCheckingThenResult() {
        coEvery { mockRepo.checkForUpdate() } returns UpdateResult.NotAvailable

        viewModel.checkForUpdate()

        testDispatcher.scheduler.advanceUntilIdle()
        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.CHECKING)

        advance()
        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.NOT_AVAILABLE)
    }

    @Test
    fun checkForUpdate_exception_setsErrorStatus() {
        coEvery { mockRepo.checkForUpdate() } throws RuntimeException("Oops")

        viewModel.checkForUpdate()
        advance()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.ERROR)
        assertThat(viewModel.error.value).isEqualTo("Oops")
    }

    @Test
    fun checkForUpdate_updateNotAvailableFalse_setsNotAvailable() {
        val info = testUpdateInfo.copy(isUpdateAvailable = false, latestVersion = "1.0.0")
        coEvery { mockRepo.checkForUpdate() } returns UpdateResult.Success(info)

        viewModel.checkForUpdate()
        advance()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.NOT_AVAILABLE)
    }

    @Test
    fun downloadUpdate_success_setsStatusDownloaded() {
        val mockFile = mockk<File>()
        coEvery { mockRepo.checkForUpdate() } returns UpdateResult.Success(testUpdateInfo)
        coEvery { mockRepo.downloadApk(any(), any(), any()) } returns mockFile

        viewModel.checkForUpdate()
        advance()

        viewModel.downloadUpdate()
        advance()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.DOWNLOADED)
    }

    @Test
    fun downloadUpdate_failure_setsErrorStatus() {
        coEvery { mockRepo.checkForUpdate() } returns UpdateResult.Success(testUpdateInfo)
        coEvery { mockRepo.downloadApk(any(), any(), any()) } returns null

        viewModel.checkForUpdate()
        advance()

        viewModel.downloadUpdate()
        advance()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.ERROR)
        assertThat(viewModel.error.value).isEqualTo("Download failed")
    }

    @Test
    fun downloadUpdate_noUpdateInfo_returnsEarly() {
        viewModel.downloadUpdate()
        advance()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.IDLE)
    }

    @Test
    fun downloadUpdate_progressUpdates() {
        val mockFile = mockk<File>()
        coEvery { mockRepo.checkForUpdate() } returns UpdateResult.Success(testUpdateInfo)
        coEvery { mockRepo.downloadApk(any(), any(), captureLambda()) } answers {
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
        coEvery { mockRepo.checkForUpdate() } returns UpdateResult.Success(testUpdateInfo)
        coEvery { mockRepo.downloadApk(any(), any(), any()) } returns mockFile
        every { mockRepo.canInstallApk() } returns true
        every { mockRepo.installApk(any()) } returns true

        viewModel.checkForUpdate()
        advance()

        viewModel.downloadUpdate()
        advance()

        viewModel.installUpdate()

        verify { mockRepo.installApk(mockFile) }
    }

    @Test
    fun installUpdate_cannotInstall_setsPermissionError() {
        val mockFile = mockk<File>()
        coEvery { mockRepo.checkForUpdate() } returns UpdateResult.Success(testUpdateInfo)
        coEvery { mockRepo.downloadApk(any(), any(), any()) } returns mockFile
        every { mockRepo.canInstallApk() } returns false

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
        viewModel.installUpdate()

        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.IDLE)
    }

    @Test
    fun reset_resetsToIdle() {
        coEvery { mockRepo.checkForUpdate() } returns UpdateResult.Error("fail")

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
        assertThat(viewModel.status.value).isEqualTo(UpdateStatus.IDLE)
    }

    @Test
    fun initialError_isEmpty() {
        assertThat(viewModel.error.value).isEmpty()
    }

    @Test
    fun initialDownloadProgress_isZero() {
        assertThat(viewModel.downloadProgress.value).isEqualTo(0f)
    }
}
