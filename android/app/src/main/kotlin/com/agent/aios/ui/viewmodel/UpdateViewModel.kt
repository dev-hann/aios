package com.agent.aios.ui.viewmodel

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.agent.aios.domain.model.UpdateInfo
import com.agent.aios.domain.model.UpdateResult
import com.agent.aios.domain.model.UpdateStatus
import com.agent.aios.domain.repository.UpdateRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File
import javax.inject.Inject

@HiltViewModel
class UpdateViewModel
    @Inject
    constructor(
        private val updateRepository: UpdateRepository,
    ) : ViewModel() {
        private val TAG = "AIOS-UpdateVM"

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
                    when (val result = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) { updateRepository.checkForUpdate() }) {
                        is UpdateResult.Success -> {
                            _updateInfo.value = result.info
                            _status.value =
                                if (result.info.isUpdateAvailable) {
                                    UpdateStatus.AVAILABLE
                                } else {
                                    UpdateStatus.NOT_AVAILABLE
                                }
                        }
                        is UpdateResult.NotAvailable -> {
                            _status.value = UpdateStatus.NOT_AVAILABLE
                        }
                        is UpdateResult.Error -> {
                            _status.value = UpdateStatus.ERROR
                            _error.value = result.message
                        }
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
                val file =
                    updateRepository.downloadApk(info.downloadUrl, fileName) { progress ->
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
            if (!updateRepository.canInstallApk()) {
                _status.value = UpdateStatus.ERROR
                _error.value = "INSTALL_PERMISSION_NEEDED"
                return
            }
            updateRepository.installApk(apk)
        }

        fun requestInstallPermissionIntent() = updateRepository.requestInstallPermissionIntent()

        fun reset() {
            _status.value = UpdateStatus.IDLE
            _updateInfo.value = null
            _downloadProgress.value = 0f
            _error.value = ""
        }
    }
