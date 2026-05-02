package com.agent.aios.ui.screen

import android.Manifest
import android.content.Intent
import android.content.ClipData
import android.content.ClipboardManager
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.SmartToy
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.viewmodel.compose.viewModel
import com.agent.aios.AIOSApp
import com.agent.aios.BuildConfig
import com.agent.aios.crash.CrashLogManager
import com.agent.aios.service.AIOSAccessibilityService
import com.agent.aios.service.OverlayService
import com.agent.aios.ui.component.ModelPicker
import com.agent.aios.ui.theme.AIOSColors
import com.agent.aios.ui.viewmodel.SettingsViewModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun SettingsScreen(
    onBack: () -> Unit = {},
    onNavigateToUpdate: () -> Unit = {},
    onImportFile: () -> Unit = {},
    viewModel: SettingsViewModel = viewModel(),
) {
    val context = LocalContext.current
    val serviceState by AIOSApp.instance.serviceState.collectAsState(AIOSApp.ServiceState.DISCONNECTED)
    val isModelLoaded = AIOSApp.instance.llmService?.isModelLoaded() ?: false
    val modelInfo = AIOSApp.instance.llmService?.getModelInfo() ?: "N/A"
    val updateAvailable by AIOSApp.instance.updateAvailable.collectAsState()
    val latestVersion by AIOSApp.instance.latestVersion.collectAsState()

    val chatVm = AIOSApp.instance.chatViewModel
    val models by (chatVm?.models?.collectAsState() ?: remember { mutableStateOf(emptyList()) })
    val isImporting by (chatVm?.isImporting?.collectAsState() ?: remember { mutableStateOf(false) })
    var showModelPicker by remember { mutableStateOf(false) }

    val contextSize by viewModel.contextSize.collectAsState()
    val maxTokensChat by viewModel.maxTokensChat.collectAsState()
    val maxTokensAgent by viewModel.maxTokensAgent.collectAsState()
    val temperature by viewModel.temperature.collectAsState()
    val topK by viewModel.topK.collectAsState()
    val topP by viewModel.topP.collectAsState()
    val agentMaxIterations by viewModel.agentMaxIterations.collectAsState()
    val repeatPenalty by viewModel.repeatPenalty.collectAsState()

    val lifecycleOwner = LocalLifecycleOwner.current
    var refreshKey by remember { mutableStateOf(0) }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) refreshKey++
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val isAccessibilityEnabled = remember(refreshKey) { AIOSAccessibilityService.isEnabled(context) }
    val isOverlayPermission = remember(refreshKey) { Settings.canDrawOverlays(context) }
    val isNotifListener = remember(refreshKey) { isNotificationListenerEnabled(context) }
    val phoneControlCount = listOf(isAccessibilityEnabled, isOverlayPermission, isNotifListener).count { it }

    var contactsGranted by remember(refreshKey) {
        mutableStateOf(context.checkSelfPermission(Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED)
    }
    var smsGranted by remember(refreshKey) {
        mutableStateOf(
            context.checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED &&
            context.checkSelfPermission(Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
        )
    }
    var callGranted by remember(refreshKey) {
        mutableStateOf(context.checkSelfPermission(Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED)
    }
    val commCount = listOf(contactsGranted, smsGranted, callGranted).count { it }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        contactsGranted = permissions[Manifest.permission.READ_CONTACTS] == true
        smsGranted = permissions[Manifest.permission.SEND_SMS] == true && permissions[Manifest.permission.READ_SMS] == true
        callGranted = permissions[Manifest.permission.CALL_PHONE] == true
    }

    var overlayServiceEnabled by remember(refreshKey) { mutableStateOf(OverlayService.isRunning) }

    var advancedExpanded by remember { mutableStateOf(false) }

    if (showModelPicker) {
        ModelPicker(
            models = models,
            currentModelPath = null,
            isImporting = isImporting,
            onSelect = {
                chatVm?.loadModel(it.path)
                showModelPicker = false
            },
            onImportFile = {
                showModelPicker = false
                onImportFile()
            },
            onDismiss = { showModelPicker = false }
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AIOSColors.Background)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AIOSColors.Surface)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(
                    onClick = onBack,
                    modifier = Modifier.size(40.dp),
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = AIOSColors.TextPrimary,
                        modifier = Modifier.size(24.dp),
                    )
                }
                Text(
                    "Settings",
                    fontWeight = FontWeight.Bold,
                    fontSize = 22.sp,
                    color = AIOSColors.TextPrimary,
                )
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(3.dp)
                    .background(
                        when (serviceState) {
                            AIOSApp.ServiceState.MODEL_LOADED -> AIOSColors.StatusReady
                            AIOSApp.ServiceState.DISCONNECTED -> AIOSColors.StatusIdle
                            AIOSApp.ServiceState.GENERATING -> AIOSColors.StatusRunning
                            AIOSApp.ServiceState.AGENT_RUNNING -> AIOSColors.Accent
                            else -> AIOSColors.StatusIdle
                        }
                    )
            )
        }

        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {

        // ── SETUP ──────────────────────────────────────
        SectionHeader("SETUP")
        HorizontalDivider(color = AIOSColors.Divider, thickness = 1.dp)
        Spacer(modifier = Modifier.height(2.dp))

        SettingsCard("Model") {
            if (isModelLoaded) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Spacer(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(AIOSColors.StatusReady)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Active", fontSize = 14.sp, color = AIOSColors.StatusReady, fontWeight = FontWeight.Medium)
                }
                Spacer(modifier = Modifier.height(8.dp))
                Text(modelInfo, fontSize = 11.sp, color = AIOSColors.TextTertiary, fontFamily = FontFamily.Monospace)
                Spacer(modifier = Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(
                        onClick = { showModelPicker = true },
                        shape = RoundedCornerShape(10.dp),
                    ) {
                        Text("Change", fontSize = 12.sp, color = AIOSColors.Primary)
                    }
                    OutlinedButton(
                        onClick = { AIOSApp.instance.releaseModel() },
                        shape = RoundedCornerShape(10.dp),
                    ) {
                        Text("Release", fontSize = 12.sp, color = AIOSColors.StatusError)
                    }
                }
            } else {
                Text("Not loaded", fontSize = 14.sp, color = AIOSColors.TextTertiary, fontWeight = FontWeight.Medium)
                Spacer(modifier = Modifier.height(6.dp))
                Text("Import or select a GGUF model to start chatting.", fontSize = 12.sp, color = AIOSColors.TextTertiary)
                Spacer(modifier = Modifier.height(10.dp))
                OutlinedButton(
                    onClick = { showModelPicker = true },
                    shape = RoundedCornerShape(10.dp),
                ) {
                    Text("Load Model", fontSize = 12.sp, color = AIOSColors.Primary)
                }
            }
        }

        // Phone Control
        SettingsCard("Phone Control") {
            ProgressRow(phoneControlCount, 3)
            Spacer(modifier = Modifier.height(10.dp))
            PermissionRow("Accessibility", "Read screen & perform actions", isAccessibilityEnabled) {
                context.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            }
            Spacer(modifier = Modifier.height(8.dp))
            PermissionRow("Notifications", "Read & respond to notifications", isNotifListener) {
                context.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
            }
            Spacer(modifier = Modifier.height(8.dp))
            PermissionRow("Overlay", "Floating AI button on any app", isOverlayPermission) {
                context.startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context.packageName}")))
            }
            if (isOverlayPermission) {
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 48.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Column {
                        Text("Overlay Service", fontSize = 13.sp, color = AIOSColors.TextSecondary, fontWeight = FontWeight.Medium)
                        Text(
                            if (overlayServiceEnabled) "Running" else "Stopped",
                            fontSize = 11.sp,
                            color = if (overlayServiceEnabled) AIOSColors.StatusReady else AIOSColors.TextTertiary
                        )
                    }
                    Switch(
                        checked = overlayServiceEnabled,
                        onCheckedChange = { enabled ->
                            overlayServiceEnabled = enabled
                            val intent = Intent(context, OverlayService::class.java)
                            if (enabled) context.startService(intent) else context.stopService(intent)
                        },
                        colors = SwitchDefaults.colors(
                            checkedTrackColor = AIOSColors.Accent,
                            checkedThumbColor = Color.White,
                            uncheckedTrackColor = AIOSColors.SurfaceVariant,
                            uncheckedThumbColor = AIOSColors.TextTertiary,
                        ),
                    )
                }
            }
        }

        // Communication
        SettingsCard("Communication") {
            ProgressRow(commCount, 3)
            Spacer(modifier = Modifier.height(10.dp))
            PermissionRow("Contacts", "Search and read contacts", contactsGranted) {
                permissionLauncher.launch(arrayOf(Manifest.permission.READ_CONTACTS))
            }
            Spacer(modifier = Modifier.height(8.dp))
            PermissionRow("SMS", "Send and read text messages", smsGranted) {
                permissionLauncher.launch(arrayOf(Manifest.permission.SEND_SMS, Manifest.permission.READ_SMS))
            }
            Spacer(modifier = Modifier.height(8.dp))
            PermissionRow("Phone", "Make phone calls directly", callGranted) {
                permissionLauncher.launch(arrayOf(Manifest.permission.CALL_PHONE))
            }
        }

        Spacer(modifier = Modifier.height(6.dp))

        // ── ADVANCED ───────────────────────────────────
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(4.dp))
                .clickable { advancedExpanded = !advancedExpanded }
                .padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SectionHeader("ADVANCED")
            Spacer(modifier = Modifier.weight(1f))
            Icon(
                Icons.Filled.KeyboardArrowDown,
                contentDescription = null,
                modifier = Modifier
                    .size(20.dp)
                    .rotate(if (advancedExpanded) 180f else 0f),
                tint = AIOSColors.TextTertiary,
            )
        }
        HorizontalDivider(color = AIOSColors.Divider, thickness = 1.dp)

        AnimatedVisibility(
            visible = advancedExpanded,
            enter = expandVertically(),
            exit = shrinkVertically(),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Spacer(modifier = Modifier.height(2.dp))

                SettingsCard("Context Size") {
                    IntInput(value = contextSize, onValueChange = { viewModel.updateContextSize(it) }, label = "Context Size")
                    Text("Larger values use more memory. Default: 2048", fontSize = 11.sp, color = AIOSColors.TextTertiary)
                }

                SettingsCard("Max Tokens") {
                    IntInput(value = maxTokensChat, onValueChange = { viewModel.updateMaxTokensChat(it) }, label = "Chat Max Tokens")
                    Spacer(modifier = Modifier.height(8.dp))
                    IntInput(value = maxTokensAgent, onValueChange = { viewModel.updateMaxTokensAgent(it) }, label = "Agent Max Tokens")
                }

                SettingsCard("Temperature") {
                    SliderInput(value = temperature, onValueChange = { viewModel.updateTemperature(it) }, valueRange = 0f..2f, label = "Temperature")
                    Text("Higher = more creative, Lower = more focused", fontSize = 11.sp, color = AIOSColors.TextTertiary)
                }

                SettingsCard("Top K") {
                    IntInput(value = topK, onValueChange = { viewModel.updateTopK(it) }, label = "Top K")
                    Text("Limits sampling to top K tokens. Default: 40", fontSize = 11.sp, color = AIOSColors.TextTertiary)
                }

                SettingsCard("Top P") {
                    SliderInput(value = topP, onValueChange = { viewModel.updateTopP(it) }, valueRange = 0f..1f, label = "Top P")
                    Text("Nucleus sampling threshold. Default: 0.9", fontSize = 11.sp, color = AIOSColors.TextTertiary)
                }

                SettingsCard("Repeat Penalty") {
                    SliderInput(value = repeatPenalty, onValueChange = { viewModel.updateRepeatPenalty(it) }, valueRange = 0f..2f, label = "Repeat Penalty")
                    Text("Penalizes repeated tokens. Default: 1.1", fontSize = 11.sp, color = AIOSColors.TextTertiary)
                }

                SettingsCard("Max Iterations") {
                    IntInput(value = agentMaxIterations, onValueChange = { viewModel.updateAgentMaxIterations(it) }, label = "Agent Max Iterations")
                    Text("Maximum ReAct loop iterations. Default: 5", fontSize = 11.sp, color = AIOSColors.TextTertiary)
                }
            }
        }

        Spacer(modifier = Modifier.height(6.dp))

        // ── ABOUT ──────────────────────────────────────
        SectionHeader("ABOUT")
        HorizontalDivider(color = AIOSColors.Divider, thickness = 1.dp)
        Spacer(modifier = Modifier.height(2.dp))

        val statusColor = when (serviceState) {
            AIOSApp.ServiceState.MODEL_LOADED -> AIOSColors.StatusReady
            AIOSApp.ServiceState.DISCONNECTED -> AIOSColors.StatusError
            else -> AIOSColors.StatusRunning
        }
        val statusLabel = when (serviceState) {
            AIOSApp.ServiceState.DISCONNECTED -> "Disconnected"
            AIOSApp.ServiceState.CONNECTING -> "Connecting..."
            AIOSApp.ServiceState.READY -> "Ready"
            AIOSApp.ServiceState.MODEL_LOADED -> "Model Loaded"
            AIOSApp.ServiceState.GENERATING -> "Generating..."
            AIOSApp.ServiceState.AGENT_RUNNING -> "Agent Running"
        }
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(AIOSColors.Surface),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .clip(RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp))
                    .background(statusColor)
            )
            Column(modifier = Modifier.padding(16.dp)) {
                Text("Service Status", fontWeight = FontWeight.SemiBold, fontSize = 15.sp, color = AIOSColors.TextPrimary)
                Spacer(modifier = Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(modifier = Modifier.size(8.dp).clip(RoundedCornerShape(4.dp)).background(statusColor))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(statusLabel, fontSize = 13.sp, color = AIOSColors.TextSecondary)
                }
            }
        }

        SettingsCard("App Update") {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (updateAvailable == true) {
                            Spacer(modifier = Modifier.size(8.dp).clip(CircleShape).background(AIOSColors.Primary))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("v${latestVersion} available", fontSize = 14.sp, color = AIOSColors.Primary, fontWeight = FontWeight.Medium)
                        } else if (updateAvailable == false) {
                            Spacer(modifier = Modifier.size(8.dp).clip(CircleShape).background(AIOSColors.StatusReady))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Up to date", fontSize = 14.sp, color = AIOSColors.StatusReady, fontWeight = FontWeight.Medium)
                        } else {
                            Text("Tap to check", fontSize = 14.sp, color = AIOSColors.TextTertiary, fontWeight = FontWeight.Medium)
                        }
                    }
                }
                OutlinedButton(onClick = onNavigateToUpdate, shape = RoundedCornerShape(10.dp)) {
                    Text("Check", fontSize = 12.sp, color = AIOSColors.Primary)
                }
            }
        }

        SettingsCard("About") {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(imageVector = Icons.Filled.SmartToy, contentDescription = null, tint = AIOSColors.TextPrimary, modifier = Modifier.size(20.dp))
                Spacer(modifier = Modifier.width(8.dp))
                Text("AIOS", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = AIOSColors.TextPrimary)
            }
            Spacer(modifier = Modifier.height(6.dp))
            Text("Android Local LLM Agent Runtime", fontSize = 13.sp, color = AIOSColors.TextSecondary)
            Spacer(modifier = Modifier.height(4.dp))
            Text("v${BuildConfig.VERSION_NAME} · Powered by llama.cpp", fontSize = 11.sp, color = AIOSColors.TextTertiary)
        }

        val crashLogs = remember(refreshKey) { CrashLogManager.getCrashLogs(context) }
        var showLogDialog by remember { mutableStateOf<String?>(null) }

        if (showLogDialog != null) {
            val logContent = remember(showLogDialog) {
                showLogDialog?.let { CrashLogManager.getLogContent(context, it) }
            }
            AlertDialog(
                onDismissRequest = { showLogDialog = null },
                title = { Text("Crash Log", fontWeight = FontWeight.SemiBold, color = AIOSColors.TextPrimary) },
                text = {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 400.dp)
                    ) {
                        Text(
                            text = logContent ?: "Log not found",
                            fontSize = 11.sp,
                            fontFamily = FontFamily.Monospace,
                            color = AIOSColors.TextSecondary,
                        )
                    }
                },
                confirmButton = {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (logContent != null) {
                            val clipboard = context.getSystemService(ClipboardManager::class.java)
                            OutlinedButton(
                                onClick = {
                                    clipboard.setPrimaryClip(ClipData.newPlainText("Crash Log", logContent))
                                }
                            ) {
                                Text("Copy", color = AIOSColors.Primary, fontSize = 13.sp)
                            }
                        }
                        TextButton(onClick = { showLogDialog = null }) {
                            Text("Close", color = AIOSColors.Primary)
                        }
                    }
                },
                containerColor = AIOSColors.Surface,
            )
        }

        SettingsCard("Crash Logs") {
            if (crashLogs.isEmpty()) {
                Text("No crash logs", fontSize = 13.sp, color = AIOSColors.TextTertiary)
            } else {
                crashLogs.take(3).forEach { log ->
                    val dateStr = remember(log.timestamp) {
                        SimpleDateFormat("MM/dd HH:mm", Locale.getDefault()).format(Date(log.timestamp))
                    }
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(8.dp))
                            .background(AIOSColors.SurfaceVariant)
                            .clickable { showLogDialog = log.filename }
                            .padding(10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(log.summary, fontSize = 12.sp, color = AIOSColors.TextPrimary, maxLines = 1)
                            Text(dateStr, fontSize = 10.sp, color = AIOSColors.TextTertiary)
                        }
                    }
                    if (log != crashLogs.take(3).last()) {
                        Spacer(modifier = Modifier.height(6.dp))
                    }
                }
                if (crashLogs.size > 3) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text("+${crashLogs.size - 3} more", fontSize = 11.sp, color = AIOSColors.TextTertiary)
                }
                Spacer(modifier = Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(
                        onClick = {
                            if (crashLogs.isNotEmpty()) showLogDialog = crashLogs.first().filename
                        },
                        shape = RoundedCornerShape(10.dp),
                    ) {
                        Text("View", fontSize = 12.sp, color = AIOSColors.Primary)
                    }
                    OutlinedButton(
                        onClick = {
                            CrashLogManager.clearLogs(context)
                            refreshKey++
                        },
                        shape = RoundedCornerShape(10.dp),
                    ) {
                        Text("Clear", fontSize = 12.sp, color = AIOSColors.StatusError)
            }
        }
        }
    }
}
    }
}

// ── Shared Components ─────────────────────────────

@Composable
private fun ProgressRow(granted: Int, total: Int) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(AIOSColors.SurfaceVariant)
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        repeat(total) { index ->
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(6.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(if (index < granted) AIOSColors.StatusReady else AIOSColors.SurfaceVariant),
            )
        }
    }
    Text("$granted of $total granted", fontSize = 12.sp, color = AIOSColors.TextTertiary)
}

@Composable
private fun PermissionRow(
    title: String,
    subtitle: String,
    isEnabled: Boolean,
    onEnable: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(if (isEnabled) AIOSColors.StatusReady.copy(alpha = 0.15f) else AIOSColors.StatusError.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                if (isEnabled) Icons.Filled.CheckCircle else Icons.Filled.Warning,
                contentDescription = null,
                tint = if (isEnabled) AIOSColors.StatusReady else AIOSColors.StatusError,
                modifier = Modifier.size(18.dp),
            )
        }
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, color = AIOSColors.TextPrimary)
            Text(subtitle, fontSize = 11.sp, color = AIOSColors.TextTertiary)
        }
        if (!isEnabled) {
            Button(
                onClick = onEnable,
                shape = RoundedCornerShape(10.dp),
                colors = ButtonDefaults.buttonColors(containerColor = AIOSColors.Primary, contentColor = Color.White),
                contentPadding = PaddingValues(horizontal = 14.dp, vertical = 6.dp),
            ) {
                Text("Enable", fontSize = 12.sp)
            }
        }
    }
}

@Composable
private fun SliderInput(value: Float, onValueChange: (Float) -> Unit, valueRange: ClosedFloatingPointRange<Float>, label: String) {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, fontSize = 13.sp, color = AIOSColors.TextSecondary, modifier = Modifier.weight(1f))
        Text(String.format("%.2f", value), fontSize = 13.sp, color = AIOSColors.TextPrimary, fontFamily = FontFamily.Monospace, modifier = Modifier.width(50.dp))
    }
    Slider(
        value = value, onValueChange = onValueChange, valueRange = valueRange,
        colors = SliderDefaults.colors(thumbColor = AIOSColors.Primary, activeTrackColor = AIOSColors.Primary, inactiveTrackColor = AIOSColors.SurfaceVariant),
    )
}

@Composable
private fun IntInput(value: Int, onValueChange: (Int) -> Unit, label: String) {
    var text by remember(value) { mutableStateOf(value.toString()) }
    OutlinedTextField(
        value = text,
        onValueChange = { input -> text = input; input.toIntOrNull()?.let { onValueChange(it) } },
        label = { Text(label, fontSize = 12.sp, color = AIOSColors.TextTertiary) },
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = AIOSColors.TextPrimary, unfocusedTextColor = AIOSColors.TextPrimary,
            focusedBorderColor = AIOSColors.Primary, unfocusedBorderColor = AIOSColors.SurfaceVariant,
            cursorColor = AIOSColors.Primary, focusedLabelColor = AIOSColors.Primary, unfocusedLabelColor = AIOSColors.TextTertiary,
        ),
        shape = RoundedCornerShape(12.dp),
        textStyle = androidx.compose.ui.text.TextStyle(fontSize = 14.sp, fontFamily = FontFamily.Monospace),
    )
}

@Composable
private fun SectionHeader(title: String) {
    Text(title, fontWeight = FontWeight.Bold, fontSize = 11.sp, color = AIOSColors.TextTertiary, letterSpacing = 1.sp)
}

@Composable
private fun SettingsCard(title: String, content: @Composable () -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(AIOSColors.Surface).padding(16.dp),
    ) {
        Text(title, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, color = AIOSColors.TextPrimary)
        Spacer(modifier = Modifier.height(8.dp))
        content()
    }
}

private fun isNotificationListenerEnabled(context: android.content.Context): Boolean {
    val cn = android.content.ComponentName(context, com.agent.aios.service.NotificationListener::class.java)
    val flat = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
    return flat?.contains(cn.flattenToString()) == true
}
