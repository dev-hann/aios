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
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.material.icons.filled.SmartToy
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
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
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.agent.aios.AIOSApp
import com.agent.aios.ui.component.MessageBubble
import com.agent.aios.ui.component.ModelPicker
import com.agent.aios.ui.theme.AIOSColors
import com.agent.aios.ui.viewmodel.AgentMode
import com.agent.aios.ui.viewmodel.ChatViewModel

@Composable
fun ChatScreen(vm: ChatViewModel = viewModel()) {
    val messages by vm.messages.collectAsState()
    val inputText by vm.inputText.collectAsState()
    val models by vm.models.collectAsState()
    val isModelLoaded by vm.isModelLoaded.collectAsState()
    val isGenerating by vm.isGenerating.collectAsState()
    val agentMode by vm.agentMode.collectAsState()
    val serviceState by vm.serviceState.collectAsState()
    val currentGeneratingText by vm.currentGeneratingText.collectAsState()

    var showModelPicker by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()

    LaunchedEffect(messages.size, currentGeneratingText) {
        if (messages.isNotEmpty()) {
            listState.animateScrollToItem(messages.size - 1)
        }
    }

    if (showModelPicker) {
        ModelPicker(
            models = models,
            currentModelPath = null,
            isImporting = isImporting,
            onSelect = { vm.loadModel(it.path) },
            onImportFile = {
                showModelPicker = false
                onPickModelFile()
            },
            onDismiss = { showModelPicker = false }
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AIOSColors.Background)
    ) {
        TopBar(
            serviceState = serviceState,
            agentMode = agentMode,
            isModelLoaded = isModelLoaded,
            onToggleMode = { vm.toggleMode() },
            onModelPicker = { showModelPicker = true }
        )

        if (!isModelLoaded) {
            EmptyState(onGetStarted = { showModelPicker = true })
        } else {
            Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
                LazyColumn(
                    state = listState,
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(vertical = 4.dp),
                    verticalArrangement = Arrangement.spacedBy(2.dp),
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
                    if (isGenerating && currentGeneratingText.isNotEmpty() &&
                        messages.lastOrNull()?.role == "assistant" && messages.lastOrNull()?.text?.isEmpty() == true
                    ) {
                        item {
                            MessageBubble(role = "assistant", text = currentGeneratingText)
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
                    GeneratingIndicator()
                }
            }
        }

        InputBar(
            text = inputText,
            isGenerating = isGenerating,
            onTextChange = { vm.updateInput(it) },
            onSend = { vm.sendMessage() },
            modifier = Modifier.imePadding(),
        )
    }
}

@Composable
private fun TopBar(
    serviceState: AIOSApp.ServiceState,
    agentMode: AgentMode,
    isModelLoaded: Boolean,
    onToggleMode: () -> Unit,
    onModelPicker: () -> Unit,
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
            .background(AIOSColors.Surface.copy(alpha = 0.8f))
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

            Row(verticalAlignment = Alignment.CenterVertically) {
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(AIOSColors.SurfaceVariant)
                        .padding(3.dp),
                    horizontalArrangement = Arrangement.Center,
                ) {
                    val isChat = agentMode == AgentMode.CHAT
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(18.dp))
                            .background(if (!isChat) AIOSColors.Primary else Color.Transparent)
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                                onClick = { if (isChat) onToggleMode() }
                            )
                            .padding(horizontal = 16.dp, vertical = 6.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = "Agent",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (!isChat) Color.White else AIOSColors.TextTertiary,
                        )
                    }
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(18.dp))
                            .background(if (isChat) AIOSColors.Primary else Color.Transparent)
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                                onClick = { if (!isChat) onToggleMode() }
                            )
                            .padding(horizontal = 16.dp, vertical = 6.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = "Chat",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (isChat) Color.White else AIOSColors.TextTertiary,
                        )
                    }
                }

                Spacer(modifier = Modifier.width(10.dp))

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
                        Icon(
                            Icons.Outlined.AutoAwesome,
                            contentDescription = "Model",
                            tint = AIOSColors.TextSecondary,
                            modifier = Modifier.size(16.dp),
                        )
                        Text(
                            text = if (isModelLoaded) "Model" else "Model",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = AIOSColors.TextSecondary,
                        )
                    }
                }
            }
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
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
                text = "Load a model to start chatting",
                fontSize = 14.sp,
                color = AIOSColors.TextTertiary,
            )
            Spacer(modifier = Modifier.height(24.dp))
            OutlinedButton(
                onClick = onGetStarted,
                shape = RoundedCornerShape(24.dp),
                colors = ButtonDefaults.outlinedButtonColors(
                    containerColor = AIOSColors.Primary.copy(alpha = 0.15f),
                    contentColor = AIOSColors.Primary,
                ),
                border = ButtonDefaults.outlinedButtonBorder(enabled = true).copy(
                    brush = SolidColor(AIOSColors.Primary.copy(alpha = 0.4f))
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
private fun GeneratingIndicator() {
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
    }
}

@Composable
private fun InputBar(
    text: String,
    isGenerating: Boolean,
    onTextChange: (String) -> Unit,
    onSend: () -> Unit,
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
                                text = "Message AIOS...",
                                color = AIOSColors.TextTertiary,
                                fontSize = 15.sp,
                            )
                        }
                        innerTextField()
                    }
                    IconButton(
                        onClick = onSend,
                        enabled = text.isNotBlank() && !isGenerating,
                        colors = IconButtonDefaults.iconButtonColors(
                            containerColor = if (text.isNotBlank() && !isGenerating) AIOSColors.Primary else AIOSColors.SurfaceVariant,
                            disabledContainerColor = AIOSColors.SurfaceVariant,
                        ),
                        modifier = Modifier.size(40.dp),
                    ) {
                        Icon(
                            Icons.AutoMirrored.Filled.Send,
                            contentDescription = "Send",
                            tint = if (text.isNotBlank() && !isGenerating) Color.White else AIOSColors.TextTertiary,
                            modifier = Modifier.size(18.dp),
                        )
                    }
                }
            },
        )
    }
}
