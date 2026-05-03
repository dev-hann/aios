package com.agent.aios.ui.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.NewReleases
import androidx.compose.material.icons.filled.SystemUpdate
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.agent.aios.domain.model.UpdateStatus
import com.agent.aios.ui.theme.AIOSColors
import com.agent.aios.ui.viewmodel.UpdateViewModel

@Composable
fun UpdateScreen(
    onBack: () -> Unit,
    vm: UpdateViewModel = hiltViewModel(),
) {
    val context = LocalContext.current
    val status by vm.status.collectAsState()
    val updateInfo by vm.updateInfo.collectAsState()
    val downloadProgress by vm.downloadProgress.collectAsState()
    val error by vm.error.collectAsState()

    LaunchedEffect(Unit) {
        if (status == UpdateStatus.IDLE) vm.checkForUpdate()
    }

    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .background(AIOSColors.Background)
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = AIOSColors.TextPrimary,
                )
            }
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                "Update",
                fontWeight = FontWeight.Bold,
                fontSize = 24.sp,
                color = AIOSColors.TextPrimary,
            )
        }

        when (status) {
            UpdateStatus.IDLE -> {}

            UpdateStatus.CHECKING -> {
                Box(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .padding(vertical = 40.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        CircularProgressIndicator(
                            color = AIOSColors.Primary,
                            modifier = Modifier.size(40.dp),
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        Text(
                            "Checking for updates...",
                            fontSize = 14.sp,
                            color = AIOSColors.TextSecondary,
                        )
                    }
                }
            }

            UpdateStatus.AVAILABLE -> {
                updateInfo?.let { info ->
                    UpdateAvailableCard(
                        info = info,
                        onDownload = { vm.downloadUpdate() },
                    )
                }
            }

            UpdateStatus.NOT_AVAILABLE -> {
                Box(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .padding(vertical = 40.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            Icons.Filled.CheckCircle,
                            contentDescription = null,
                            tint = AIOSColors.StatusReady,
                            modifier = Modifier.size(48.dp),
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        Text(
                            "You're up to date!",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium,
                            color = AIOSColors.TextPrimary,
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            "v${updateInfo?.currentVersion ?: "?"} is the latest version",
                            fontSize = 13.sp,
                            color = AIOSColors.TextTertiary,
                        )
                    }
                }

                OutlinedButton(
                    onClick = { vm.checkForUpdate() },
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Check Again", color = AIOSColors.Primary)
                }
            }

            UpdateStatus.DOWNLOADING -> {
                Column(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(AIOSColors.Surface)
                            .padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            Icons.Filled.Download,
                            contentDescription = null,
                            tint = AIOSColors.Primary,
                            modifier = Modifier.size(20.dp),
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            "Downloading v${updateInfo?.latestVersion}...",
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 15.sp,
                            color = AIOSColors.TextPrimary,
                        )
                    }

                    LinearProgressIndicator(
                        progress = { downloadProgress },
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .height(6.dp)
                                .clip(RoundedCornerShape(3.dp)),
                        color = AIOSColors.Primary,
                        trackColor = AIOSColors.SurfaceVariant,
                    )

                    Text(
                        "${(downloadProgress * 100).toInt()}%",
                        fontSize = 13.sp,
                        color = AIOSColors.TextSecondary,
                        fontFamily = FontFamily.Monospace,
                    )
                }
            }

            UpdateStatus.DOWNLOADED -> {
                Column(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(AIOSColors.Surface)
                            .padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Icon(
                        Icons.Filled.SystemUpdate,
                        contentDescription = null,
                        tint = AIOSColors.StatusReady,
                        modifier = Modifier.size(32.dp),
                    )
                    Text(
                        "Ready to install",
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 16.sp,
                        color = AIOSColors.TextPrimary,
                    )
                    Text(
                        "v${updateInfo?.latestVersion} has been downloaded.",
                        fontSize = 13.sp,
                        color = AIOSColors.TextSecondary,
                    )

                    Button(
                        onClick = { vm.installUpdate() },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        colors =
                            ButtonDefaults.buttonColors(
                                containerColor = AIOSColors.Primary,
                            ),
                    ) {
                        Text("Install Update", fontSize = 14.sp)
                    }
                }
            }

            UpdateStatus.ERROR -> {
                if (error == "INSTALL_PERMISSION_NEEDED") {
                    Column(
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(16.dp))
                                .background(AIOSColors.Surface)
                                .padding(20.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Icon(
                            Icons.Filled.SystemUpdate,
                            contentDescription = null,
                            tint = AIOSColors.StatusRunning,
                            modifier = Modifier.size(32.dp),
                        )
                        Text(
                            "Installation permission required",
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 16.sp,
                            color = AIOSColors.TextPrimary,
                        )
                        Text(
                            "Allow installation from unknown sources to proceed.",
                            fontSize = 13.sp,
                            color = AIOSColors.TextSecondary,
                        )
                        Button(
                            onClick = {
                                context.startActivity(vm.requestInstallPermissionIntent())
                            },
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(12.dp),
                            colors =
                                ButtonDefaults.buttonColors(
                                    containerColor = AIOSColors.Primary,
                                ),
                        ) {
                            Text("Open Settings")
                        }
                    }
                } else {
                    Column(
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(16.dp))
                                .background(AIOSColors.Surface)
                                .padding(20.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Icon(
                            Icons.Filled.Error,
                            contentDescription = null,
                            tint = AIOSColors.StatusError,
                            modifier = Modifier.size(32.dp),
                        )
                        Text(
                            "Error",
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 16.sp,
                            color = AIOSColors.TextPrimary,
                        )
                        Text(
                            error,
                            fontSize = 13.sp,
                            color = AIOSColors.TextSecondary,
                        )
                        OutlinedButton(
                            onClick = { vm.checkForUpdate() },
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text("Retry", color = AIOSColors.Primary)
                        }
                    }
                }
            }

            UpdateStatus.INSTALLING -> {}
        }
    }
}

@Composable
private fun UpdateAvailableCard(
    info: com.agent.aios.domain.model.UpdateInfo,
    onDownload: () -> Unit,
) {
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(AIOSColors.Surface)
                .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Filled.NewReleases,
                contentDescription = null,
                tint = AIOSColors.Primary,
                modifier = Modifier.size(24.dp),
            )
            Spacer(modifier = Modifier.width(10.dp))
            Text(
                "v${info.latestVersion} available",
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
                color = AIOSColors.TextPrimary,
            )
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Spacer(
                modifier =
                    Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(AIOSColors.TextTertiary),
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                "Current: v${info.currentVersion}",
                fontSize = 13.sp,
                color = AIOSColors.TextTertiary,
            )
            Spacer(modifier = Modifier.width(16.dp))
            Spacer(
                modifier =
                    Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(AIOSColors.StatusReady),
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                "Latest: v${info.latestVersion}",
                fontSize = 13.sp,
                color = AIOSColors.StatusReady,
            )
        }

        if (info.fileSize > 0) {
            Text(
                "Size: ${info.fileSize / (1024 * 1024)} MB",
                fontSize = 12.sp,
                color = AIOSColors.TextTertiary,
                fontFamily = FontFamily.Monospace,
            )
        }

        if (info.releaseNotes.isNotBlank()) {
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                "Release Notes",
                fontWeight = FontWeight.SemiBold,
                fontSize = 13.sp,
                color = AIOSColors.TextSecondary,
            )
            Text(
                info.releaseNotes.take(500),
                fontSize = 12.sp,
                color = AIOSColors.TextTertiary,
                lineHeight = 18.sp,
            )
        }

        Button(
            onClick = onDownload,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors =
                ButtonDefaults.buttonColors(
                    containerColor = AIOSColors.Primary,
                ),
        ) {
            Icon(
                Icons.Filled.Download,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text("Download Update", fontSize = 14.sp)
        }
    }
}
