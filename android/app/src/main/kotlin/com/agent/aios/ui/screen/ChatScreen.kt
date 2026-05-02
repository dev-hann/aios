package com.agent.aios.ui.screen

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.keyframes
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SmartToy
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.lifecycle.viewmodel.compose.viewModel
import com.agent.aios.AIOSApp
import com.agent.aios.ToolRisk
import com.agent.aios.ui.component.MessageBubble
import com.agent.aios.ui.component.ModelPicker
import com.agent.aios.ui.theme.AIOSColors
import com.agent.aios.ui.viewmodel.ChatViewModel
import com.agent.aios.ui.viewmodel.ConfirmationRequest
import android.content.Intent
import android.provider.Settings
import kotlinx.coroutines.delay

@Composable
fun ChatScreen(
    vm: ChatViewModel = viewModel(),
    onImportFile: () -> Unit = {},
    onNavigateToSettings: () -> Unit = {},
) {
    val messages by vm.messages.collectAsState()
    val inputText by vm.inputText.collectAsState()
    val models by vm.models.collectAsState()
    val isModelLoaded by vm.isModelLoaded.collectAsState()
    val isGenerating by vm.isGenerating.collectAsState()
    val isImporting by vm.isImporting.collectAsState()
    val serviceState by vm.serviceState.collectAsState()
    val currentGeneratingText by vm.currentGeneratingText.collectAsState()
    val pendingConfirmation by vm.pendingConfirmation.collectAsState()

    var showModelPicker by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()

    com.agent.aios.AIOSApp.instance.chatViewModel = vm

    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) {
            listState.animateScrollToItem(messages.size - 1)
        }
    }

    if (showModelPicker) {
        ModelPicker(
            models = models,
            currentModelPath = null,
            isImporting = isImporting,
            onSelect = {
                vm.loadModel(it.path)
                showModelPicker = false
            },
            onImportFile = {
                showModelPicker = false
                onImportFile()
            },
            onDismiss = { showModelPicker = false }
        )
    }

    if (pendingConfirmation != null) {
        ConfirmationDialog(
            request = pendingConfirmation!!,
            onApprove = { vm.approveTool() },
            onDeny = { vm.denyTool() },
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AIOSColors.Background)
    ) {
        TopBar(
            serviceState = serviceState,
            isModelLoaded = isModelLoaded,
            onModelPicker = { showModelPicker = true },
            onSettings = onNavigateToSettings,
        )

        if (!isModelLoaded) {
            if (isGenerating && serviceState == AIOSApp.ServiceState.GENERATING) {
                ModelLoadingView()
            } else {
                EmptyState(onGetStarted = { showModelPicker = true })
            }
        } else {
            Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
                LazyColumn(
                    state = listState,
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(vertical = 4.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(messages) { msg ->
                        MessageBubble(
                            role = msg.role,
                            text = msg.text,
                            toolName = msg.toolName,
                            toolArgs = msg.toolArgs,
                            toolResult = msg.toolResult,
                        )
                    }
                    messages.lastOrNull()?.let { lastMsg ->
                        if (lastMsg.role == "agent_obs" && lastMsg.toolResult.contains("Accessibility service not enabled")) {
                            item {
                                AccessibilityPermissionBanner()
                            }
                        }
                    }
                    if (isGenerating && currentGeneratingText.isNotEmpty() &&
                        messages.lastOrNull()?.role == "assistant" && messages.lastOrNull()?.text?.isEmpty() == true
                    ) {
                        item {
                            MessageBubble(role = "assistant", text = currentGeneratingText, isStreaming = true)
                        }
                    } else if (isGenerating && currentGeneratingText.isNotEmpty()) {
                        item {
                            MessageBubble(role = "agent_think", text = currentGeneratingText, isStreaming = true)
                        }
                    }
                }

                androidx.compose.animation.AnimatedVisibility(
                    visible = isGenerating,
                    enter = fadeIn() + slideInVertically { -it },
                    exit = fadeOut() + slideOutVertically { -it },
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(top = 8.dp),
                ) {
                    GeneratingIndicator(
                        thinkingText = if (currentGeneratingText.isNotEmpty()) currentGeneratingText else null
                    )
                }
            }
        }

        if (isModelLoaded) {
            InputBar(
                text = inputText,
                isGenerating = isGenerating,
                onTextChange = { vm.updateInput(it) },
                onSend = { vm.sendMessage() },
                onCancel = { vm.cancelGeneration() },
                modifier = Modifier.imePadding(),
            )
        }
    }
}

@Composable
private fun TopBar(
    serviceState: AIOSApp.ServiceState,
    isModelLoaded: Boolean,
    onModelPicker: () -> Unit,
    onSettings: () -> Unit,
) {
    val statusColor = when (serviceState) {
        AIOSApp.ServiceState.DISCONNECTED -> AIOSColors.StatusIdle
        AIOSApp.ServiceState.CONNECTING -> AIOSColors.StatusRunning
        AIOSApp.ServiceState.READY -> AIOSColors.StatusIdle
        AIOSApp.ServiceState.MODEL_LOADED -> AIOSColors.StatusReady
        AIOSApp.ServiceState.GENERATING -> AIOSColors.StatusRunning
        AIOSApp.ServiceState.AGENT_RUNNING -> AIOSColors.Accent
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(AIOSColors.Surface)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = "AIOS",
                fontWeight = FontWeight.Bold,
                fontSize = 22.sp,
                color = AIOSColors.TextPrimary,
            )

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                IconButton(
                    onClick = onSettings,
                    modifier = Modifier.size(36.dp),
                ) {
                    Icon(
                        Icons.Filled.Settings,
                        contentDescription = "Settings",
                        tint = AIOSColors.TextSecondary,
                        modifier = Modifier.size(20.dp),
                    )
                }

                Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(16.dp))
                    .background(AIOSColors.SurfaceVariant)
                    .border(1.dp, AIOSColors.Divider, RoundedCornerShape(16.dp))
                    .clickable { onModelPicker() }
                    .padding(horizontal = 12.dp, vertical = 6.dp),
                contentAlignment = Alignment.Center,
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    if (isModelLoaded) {
                        Box(
                            modifier = Modifier
                                .size(6.dp)
                                .clip(CircleShape)
                                .background(AIOSColors.StatusReady)
                        )
                        Text(
                            text = "Loaded",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = AIOSColors.TextSecondary,
                        )
                    } else {
                        Icon(
                            Icons.Outlined.AutoAwesome,
                            contentDescription = "Model",
                            tint = AIOSColors.TextSecondary,
                            modifier = Modifier.size(16.dp),
                        )
                        Text(
                            text = "Model",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = AIOSColors.TextSecondary,
                        )
                    }
                }
            }
            }
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(3.dp)
                .background(statusColor)
        )
    }
}

@Composable
private fun EmptyState(onGetStarted: () -> Unit) {
    val infiniteTransition = rememberInfiniteTransition()
    val scale by infiniteTransition.animateFloat(
        initialValue = 0.95f,
        targetValue = 1.05f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200),
            repeatMode = RepeatMode.Reverse
        ),
        label = "iconPulse"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .scale(scale)
                    .clip(RoundedCornerShape(20.dp))
                    .background(AIOSColors.PrimaryDim),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Filled.SmartToy,
                    contentDescription = null,
                    tint = AIOSColors.PrimaryVariant,
                    modifier = Modifier.size(36.dp),
                )
            }
            Spacer(modifier = Modifier.height(20.dp))
            Text(
                text = "Welcome to AIOS",
                fontWeight = FontWeight.SemiBold,
                fontSize = 20.sp,
                color = AIOSColors.TextPrimary,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Import a GGUF model to get started",
                fontSize = 14.sp,
                color = AIOSColors.TextTertiary,
            )
            Spacer(modifier = Modifier.height(24.dp))
            OutlinedButton(
                onClick = onGetStarted,
                shape = RoundedCornerShape(24.dp),
                colors = ButtonDefaults.outlinedButtonColors(
                    containerColor = AIOSColors.Primary.copy(alpha = 0.25f),
                    contentColor = AIOSColors.Primary,
                ),
                border = ButtonDefaults.outlinedButtonBorder(enabled = true).copy(
                    brush = SolidColor(AIOSColors.Primary.copy(alpha = 0.5f))
                ),
            ) {
                Text(
                    text = "Get Started",
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp,
                )
            }
        }
    }
}

@Composable
private fun GeneratingIndicator(thinkingText: String? = null) {
    val infiniteTransition = rememberInfiniteTransition()

    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(AIOSColors.SurfaceVariant.copy(alpha = 0.9f))
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        repeat(3) { index ->
            val offsetY by infiniteTransition.animateFloat(
                initialValue = 0f,
                targetValue = -6f,
                animationSpec = infiniteRepeatable(
                    animation = keyframes {
                        durationMillis = 600
                        0f at 0
                        -6f at 150
                        0f at 300
                    },
                    initialStartOffset = androidx.compose.animation.core.StartOffset(index * 150),
                ),
                label = "dot_$index"
            )
            Box(
                modifier = Modifier
                    .offset(y = offsetY.dp)
                    .size(6.dp)
                    .clip(CircleShape)
                    .background(AIOSColors.Primary)
            )
        }
        if (!thinkingText.isNullOrBlank()) {
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = thinkingText.take(60) + if (thinkingText.length > 60) "..." else "",
                fontSize = 13.sp,
                color = AIOSColors.TextSecondary,
                maxLines = 1,
            )
        }
    }
}

@Composable
private fun InputBar(
    text: String,
    isGenerating: Boolean,
    onTextChange: (String) -> Unit,
    onSend: () -> Unit,
    onCancel: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(AIOSColors.Surface)
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        BasicTextField(
            value = text,
            onValueChange = onTextChange,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(AIOSColors.SurfaceVariant),
            maxLines = 4,
            enabled = !isGenerating,
            textStyle = TextStyle(
                color = AIOSColors.TextPrimary,
                fontSize = 15.sp,
            ),
            cursorBrush = SolidColor(AIOSColors.Primary),
            decorationBox = { innerTextField ->
                Row(
                    modifier = Modifier.padding(end = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                    ) {
                        if (text.isEmpty()) {
                            Text(
                                text = "Ask AIOS to do something...",
                                color = AIOSColors.TextTertiary,
                                fontSize = 15.sp,
                            )
                        }
                        innerTextField()
                    }
                    if (isGenerating) {
                        IconButton(
                            onClick = onCancel,
                            colors = IconButtonDefaults.iconButtonColors(
                                containerColor = AIOSColors.StatusError.copy(alpha = 0.2f),
                            ),
                            modifier = Modifier.size(40.dp),
                        ) {
                            Icon(
                                Icons.Filled.Close,
                                contentDescription = "Stop",
                                tint = AIOSColors.StatusError,
                                modifier = Modifier.size(18.dp),
                            )
                        }
                    } else {
                        IconButton(
                            onClick = onSend,
                            enabled = text.isNotBlank(),
                            colors = IconButtonDefaults.iconButtonColors(
                                containerColor = if (text.isNotBlank()) AIOSColors.Primary else AIOSColors.SurfaceVariant,
                                disabledContainerColor = AIOSColors.SurfaceVariant,
                            ),
                            modifier = Modifier.size(40.dp),
                        ) {
                            Icon(
                                Icons.AutoMirrored.Filled.Send,
                                contentDescription = "Send",
                                tint = if (text.isNotBlank()) Color.White else AIOSColors.TextTertiary,
                                modifier = Modifier.size(18.dp),
                            )
                        }
                    }
                }
            },
        )
    }
}

@Composable
private fun ConfirmationDialog(
    request: ConfirmationRequest,
    onApprove: () -> Unit,
    onDeny: () -> Unit,
) {
    val risk = try { ToolRisk.valueOf(request.risk) } catch (_: Exception) { ToolRisk.HIGH }
    val riskColor = when (risk) {
        ToolRisk.SAFE -> AIOSColors.StatusReady
        ToolRisk.LOW -> AIOSColors.StatusRunning
        ToolRisk.HIGH -> Color(0xFFFF9800)
        ToolRisk.CRITICAL -> AIOSColors.StatusError
    }
    val riskLabel = when (risk) {
        ToolRisk.SAFE -> "SAFE"
        ToolRisk.LOW -> "LOW"
        ToolRisk.HIGH -> "HIGH"
        ToolRisk.CRITICAL -> "CRITICAL"
    }

    var remainingSeconds by remember {
        val elapsed = (System.currentTimeMillis() - request.createdAtMs) / 1000
        mutableStateOf(maxOf(0, (request.timeoutMs / 1000 - elapsed).toInt()))
    }

    LaunchedEffect(request) {
        while (remainingSeconds > 0) {
            delay(1000)
            remainingSeconds--
        }
        if (remainingSeconds <= 0) onDeny()
    }

    Dialog(onDismissRequest = {}) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(20.dp))
                .background(AIOSColors.Surface)
                .padding(24.dp)
        ) {
            Text(
                text = "Action Confirmation",
                color = AIOSColors.TextPrimary,
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
            )

            Spacer(modifier = Modifier.height(8.dp))

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(4.dp))
                        .background(riskColor.copy(alpha = 0.2f))
                        .padding(horizontal = 8.dp, vertical = 2.dp),
                ) {
                    Text(
                        text = riskLabel,
                        color = riskColor,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                    )
                }
                Text(
                    text = request.toolName,
                    color = AIOSColors.TextSecondary,
                    fontSize = 13.sp,
                    fontFamily = FontFamily.Monospace,
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                text = "The agent wants to perform:",
                color = AIOSColors.TextSecondary,
                fontSize = 14.sp,
            )

            Spacer(modifier = Modifier.height(8.dp))

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(AIOSColors.SurfaceVariant)
                    .padding(12.dp),
            ) {
                Text(
                    text = parseArgsForDisplay(request.toolName, request.args),
                    color = AIOSColors.TextPrimary,
                    fontSize = 13.sp,
                    fontFamily = FontFamily.Monospace,
                    lineHeight = 18.sp,
                )
            }

            if (risk == ToolRisk.CRITICAL) {
                Spacer(modifier = Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(AIOSColors.StatusError),
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "This action is irreversible. Review carefully.",
                        color = AIOSColors.StatusError,
                        fontSize = 12.sp,
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(if (remainingSeconds <= 10) AIOSColors.StatusError else AIOSColors.TextTertiary),
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = "Auto-deny in ${remainingSeconds}s",
                    color = if (remainingSeconds <= 10) AIOSColors.StatusError else AIOSColors.TextTertiary,
                    fontSize = 12.sp,
                    fontFamily = FontFamily.Monospace,
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                TextButton(
                    onClick = onDeny,
                    colors = ButtonDefaults.textButtonColors(
                        containerColor = AIOSColors.SurfaceVariant,
                        contentColor = AIOSColors.TextSecondary,
                    ),
                    shape = RoundedCornerShape(8.dp),
                ) {
                    Text(
                        text = "Deny",
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(horizontal = 8.dp),
                    )
                }
                Spacer(modifier = Modifier.width(8.dp))
                TextButton(
                    onClick = onApprove,
                    colors = ButtonDefaults.textButtonColors(
                        containerColor = riskColor.copy(alpha = 0.15f),
                        contentColor = riskColor,
                    ),
                    shape = RoundedCornerShape(8.dp),
                ) {
                    Text(
                        text = "Allow",
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(horizontal = 8.dp),
                    )
                }
            }
        }
    }
}

private fun parseArgsForDisplay(toolName: String, args: String): String {
    val json = try { org.json.JSONObject(args) } catch (_: Exception) { return args }
    val action = json.optString("action", "")
    return when (toolName) {
        "sms_sender" -> when (action) {
            "send" -> "Send SMS\n  To: ${json.optString("to", "?")}\n  Body: ${json.optString("body", "?")}"
            "read" -> "Read SMS messages (limit: ${json.optInt("limit", 10)})"
            else -> args
        }
        "phone_caller" -> when (action) {
            "call" -> "Phone call to ${json.optString("number", "?")}"
            "dial" -> "Open dialer with ${json.optString("number", "?")}"
            else -> args
        }
        "screen_action" -> when (action) {
            "tap" -> {
                val text = json.optString("text", "")
                val x = json.optDouble("x", -1.0)
                val y = json.optDouble("y", -1.0)
                if (text.isNotBlank()) "Tap on \"$text\""
                else if (x >= 0 && y >= 0) "Tap at ($x, $y)"
                else args
            }
            "type" -> "Type \"${json.optString("content", "")}\""
            "scroll" -> "Scroll ${json.optString("direction", "?")}"
            "swipe" -> "Swipe ${json.optString("direction", "?")}"
            "long_click" -> "Long click on \"${json.optString("text", "")}\""
            "global" -> "Global action: ${json.optString("global_action", "?")}"
            else -> args
        }
        "app_launcher" -> when (action) {
            "open_app" -> "Open app: ${json.optString("package_name", "?")}"
            "open_url" -> "Open URL: ${json.optString("url", "?")}"
            else -> args
        }
        else -> args
    }
}

@Composable
private fun ModelLoadingView() {
    val infiniteTransition = rememberInfiniteTransition()
    val pulse by infiniteTransition.animateFloat(
        initialValue = 0.6f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(800),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "loading_pulse",
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .scale(pulse)
                    .clip(RoundedCornerShape(20.dp))
                    .background(AIOSColors.PrimaryDim),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Filled.SmartToy,
                    contentDescription = null,
                    tint = AIOSColors.PrimaryVariant,
                    modifier = Modifier.size(36.dp),
                )
            }
            Spacer(modifier = Modifier.height(20.dp))
            Text(
                text = "Loading model...",
                fontWeight = FontWeight.SemiBold,
                fontSize = 18.sp,
                color = AIOSColors.TextPrimary,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "This may take a moment",
                fontSize = 14.sp,
                color = AIOSColors.TextTertiary,
            )
            Spacer(modifier = Modifier.height(16.dp))
            androidx.compose.material3.LinearProgressIndicator(
                modifier = Modifier
                    .fillMaxWidth(0.5f)
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp)),
                color = AIOSColors.Primary,
                trackColor = AIOSColors.SurfaceVariant,
            )
        }
    }
}

@Composable
private fun AccessibilityPermissionBanner() {
    val context = LocalContext.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(AIOSColors.Surface)
            .border(1.dp, AIOSColors.Primary.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
            .clickable {
                context.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            }
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = "Accessibility service required",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = AIOSColors.TextPrimary,
            )
            Text(
                text = "Tap to enable in Settings",
                fontSize = 12.sp,
                color = AIOSColors.TextTertiary,
            )
        }
        Text(
            text = "Open",
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            color = AIOSColors.Primary,
        )
    }
}
