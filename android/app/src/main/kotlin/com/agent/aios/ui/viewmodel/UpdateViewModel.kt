package com.agent.aios.ui.viewmodel

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.agent.aios.update.ApkInstaller
import com.agent.aios.update.UpdateChecker
import com.agent.aios.update.UpdateDownloader
import com.agent.aios.update.UpdateInfo
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File

enum class UpdateStatus {
    IDLE, CHECKING, AVAILABLE, NOT_AVAILABLE, DOWNLOADING, DOWNLOADED, INSTALLING, ERROR
}

class UpdateViewModel(application: Application) : AndroidViewModel(application) {

    private val TAG = "UpdateVM"
    private val checker = UpdateChecker(application)
    private val downloader = UpdateDownloader(application)
    private val installer = ApkInstaller(application)

    private val _status = MutableStateFlow(UpdateStatus.IDLE)
    val status: StateFlow<UpdateStatus> = _status.asStateFlow()

    private val _updateInfo = MutableStateFlow<UpdateInfo?>(null)
    val updateInfo: StateFlow<UpdateInfo?> = _updateInfo.asStateFlow()

    private val _downloadProgress = MutableStateFlow(0f)
    val downloadProgress: StateFlow<Float> = _downloadProgress.asStateFlow()

    private val _error = MutableStateFlow("")
    val error: StateFlow<String> = _error.asStateFlow()

    private var downloadedApk: File? = null

    fun checkForUpdate() {
        viewModelScope.launch {
            _status.value = UpdateStatus.CHECKING
            _error.value = ""
            try {
                val info = kotlinx.coroutines.Dispatchers.IO.let { io ->
                    kotlinx.coroutines.withContext(io) { checker.checkForUpdate() }
                }
                if (info == null) {
                    _status.value = UpdateStatus.ERROR
                    _error.value = "No APK found in latest release"
                    return@launch
                }
                _updateInfo.value = info
                _status.value = if (info.isUpdateAvailable) {
                    UpdateStatus.AVAILABLE
                } else {
                    UpdateStatus.NOT_AVAILABLE
                }
            } catch (e: Exception) {
                Log.e(TAG, "Check failed: ${e.message}")
                _status.value = UpdateStatus.ERROR
                _error.value = e.message ?: "Unknown error"
            }
        }
    }

    fun downloadUpdate() {
        val info = _updateInfo.value ?: return
        viewModelScope.launch {
            _status.value = UpdateStatus.DOWNLOADING
            _downloadProgress.value = 0f
            _error.value = ""

            val fileName = "aios-${info.latestVersion}.apk"
            val file = downloader.downloadApk(info.downloadUrl, fileName) { progress ->
                _downloadProgress.value = progress
            }

            if (file != null) {
                downloadedApk = file
                _status.value = UpdateStatus.DOWNLOADED
            } else {
                _status.value = UpdateStatus.ERROR
                _error.value = "Download failed"
            }
        }
    }

    fun installUpdate() {
        val apk = downloadedApk ?: return
        if (!installer.canInstallApk()) {
            _status.value = UpdateStatus.ERROR
            _error.value = "INSTALL_PERMISSION_NEEDED"
            return
        }
        installer.installApk(apk)
    }

    fun requestInstallPermissionIntent() = installer.requestInstallPermission()

    fun reset() {
        _status.value = UpdateStatus.IDLE
        _updateInfo.value = null
        _downloadProgress.value = 0f
        _error.value = ""
    }
}
