package com.agent.aios.ui.screen

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.AttachFile
import androidx.compose.material.icons.filled.SmartToy
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.agent.aios.AIOSApp
import com.agent.aios.ui.component.MessageBubble
import com.agent.aios.ui.component.ModelPicker
import com.agent.aios.ui.component.StatusBar
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
            onSelect = { vm.loadModel(it.path) },
            onDismiss = { showModelPicker = false }
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AIOSColors.Background)
            .statusBarsPadding()
    ) {
        TopBar(
            serviceState = serviceState,
            agentMode = agentMode,
            isModelLoaded = isModelLoaded,
            onToggleMode = { vm.toggleMode() },
            onModelPicker = { showModelPicker = true }
        )

        if (!isModelLoaded) {
            EmptyState()
        } else {
            Box(modifier = Modifier.weight(1f)) {
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
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(AIOSColors.Surface.copy(alpha = 0.8f))
            .padding(horizontal = 20.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column {
            Text(
                text = "AIOS",
                fontWeight = FontWeight.Bold,
                fontSize = 22.sp,
                color = AIOSColors.TextPrimary,
            )
            StatusBar(state = serviceState)
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = if (agentMode == AgentMode.CHAT) "Chat" else "Agent",
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = AIOSColors.TextSecondary,
            )
            Spacer(modifier = Modifier.width(4.dp))
            Switch(
                checked = agentMode == AgentMode.AGENT,
                onCheckedChange = { onToggleMode() },
                colors = SwitchDefaults.colors(
                    checkedTrackColor = AIOSColors.Accent,
                    checkedThumbColor = Color.White,
                    uncheckedTrackColor = AIOSColors.SurfaceVariant,
                    uncheckedThumbColor = AIOSColors.TextTertiary,
                ),
                modifier = Modifier.height(24.dp),
            )
            Spacer(modifier = Modifier.width(8.dp))
            IconButton(
                onClick = onModelPicker,
                colors = IconButtonDefaults.iconButtonColors(
                    containerColor = AIOSColors.SurfaceVariant,
                ),
                modifier = Modifier.size(36.dp),
            ) {
                Icon(
                    Icons.Filled.AttachFile,
                    contentDescription = "Model",
                    tint = AIOSColors.TextSecondary,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
    }
}

@Composable
private fun EmptyState() {
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
                text = "No model loaded",
                fontWeight = FontWeight.SemiBold,
                fontSize = 18.sp,
                color = AIOSColors.TextPrimary,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Tap the clip icon to select a GGUF model",
                fontSize = 14.sp,
                color = AIOSColors.TextTertiary,
            )
        }
    }
}

@Composable
private fun GeneratingIndicator() {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(AIOSColors.SurfaceVariant.copy(alpha = 0.9f))
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        CircularProgressIndicator(
            modifier = Modifier.size(14.dp),
            color = AIOSColors.Primary,
            strokeWidth = 2.dp,
        )
        Text(
            text = "Generating...",
            fontSize = 12.sp,
            color = AIOSColors.TextSecondary,
        )
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
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(AIOSColors.Surface)
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .navigationBarsPadding(),
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        TextField(
            value = text,
            onValueChange = onTextChange,
            modifier = Modifier.weight(1f),
            placeholder = {
                Text(
                    "Message AIOS...",
                    color = AIOSColors.TextTertiary,
                    fontSize = 15.sp,
                )
            },
            maxLines = 4,
            shape = RoundedCornerShape(24.dp),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = AIOSColors.SurfaceVariant,
                unfocusedContainerColor = AIOSColors.SurfaceVariant,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent,
                cursorColor = AIOSColors.Primary,
                focusedTextColor = AIOSColors.TextPrimary,
                unfocusedTextColor = AIOSColors.TextPrimary,
            ),
        )
        IconButton(
            onClick = onSend,
            enabled = text.isNotBlank() && !isGenerating,
            colors = IconButtonDefaults.iconButtonColors(
                containerColor = if (text.isNotBlank() && !isGenerating) AIOSColors.Primary else AIOSColors.SurfaceVariant,
                disabledContainerColor = AIOSColors.SurfaceVariant,
            ),
            modifier = Modifier.size(44.dp),
        ) {
            Icon(
                Icons.AutoMirrored.Filled.Send,
                contentDescription = "Send",
                tint = if (text.isNotBlank() && !isGenerating) Color.White else AIOSColors.TextTertiary,
                modifier = Modifier.size(20.dp),
            )
        }
    }
}
