package com.agent.aios.ui.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.agent.aios.AIOSApp
import com.agent.aios.BuildConfig
import com.agent.aios.ui.theme.AIOSColors
import com.agent.aios.ui.viewmodel.SettingsViewModel
import java.io.File
import java.text.CharacterIterator
import java.text.StringCharacterIterator
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.SmartToy

private fun formatFileSize(bytes: Long): String {
    val absB = if (bytes == Long.MIN_VALUE) Long.MAX_VALUE else Math.abs(bytes)
    if (absB < 1024) return "$bytes B"
    val ci: CharacterIterator = StringCharacterIterator("KMGTPE")
    var value = absB.toDouble()
    while (value >= 1024) {
        value /= 1024
        ci.next()
    }
    return String.format("%.1f %ciB", value, ci.current())
}

@Composable
fun SettingsScreen(
    onNavigateToUpdate: () -> Unit = {},
    viewModel: SettingsViewModel = viewModel(),
) {
    val context = LocalContext.current
    val serviceState by AIOSApp.instance.serviceState.collectAsState(AIOSApp.ServiceState.DISCONNECTED)
    val isModelLoaded = AIOSApp.instance.llmService?.isModelLoaded() ?: false
    val modelInfo = AIOSApp.instance.llmService?.getModelInfo() ?: "N/A"
    val updateAvailable by AIOSApp.instance.updateAvailable.collectAsState()
    val latestVersion by AIOSApp.instance.latestVersion.collectAsState()

    val contextSize by viewModel.contextSize.collectAsState()
    val maxTokensChat by viewModel.maxTokensChat.collectAsState()
    val maxTokensAgent by viewModel.maxTokensAgent.collectAsState()
    val temperature by viewModel.temperature.collectAsState()
    val topK by viewModel.topK.collectAsState()
    val topP by viewModel.topP.collectAsState()
    val agentMaxIterations by viewModel.agentMaxIterations.collectAsState()
    val repeatPenalty by viewModel.repeatPenalty.collectAsState()

    val modelsDir = File(context.filesDir, "models")
    val modelFiles = modelsDir.listFiles()?.filter { it.extension == "gguf" } ?: emptyList()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AIOSColors.Background)
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            "Settings",
            fontWeight = FontWeight.Bold,
            fontSize = 24.sp,
            color = AIOSColors.TextPrimary,
        )

        SectionHeader("LLM SETTINGS")
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
                    Text(
                        "Active",
                        fontSize = 14.sp,
                        color = AIOSColors.StatusReady,
                        fontWeight = FontWeight.Medium,
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    modelInfo,
                    fontSize = 11.sp,
                    color = AIOSColors.TextTertiary,
                    fontFamily = FontFamily.Monospace,
                )
                Spacer(modifier = Modifier.height(10.dp))
                OutlinedButton(
                    onClick = { AIOSApp.instance.releaseModel() },
                    shape = RoundedCornerShape(10.dp),
                ) {
                    Text(
                        "Release",
                        fontSize = 12.sp,
                        color = AIOSColors.StatusError,
                    )
                }
            } else {
                Text(
                    "Not loaded",
                    fontSize = 14.sp,
                    color = AIOSColors.TextTertiary,
                    fontWeight = FontWeight.Medium,
                )
            }
        }

        SettingsCard("Models Directory") {
            Text(
                modelsDir.absolutePath,
                fontSize = 11.sp,
                color = AIOSColors.TextTertiary,
                fontFamily = FontFamily.Monospace,
            )
            Spacer(modifier = Modifier.height(8.dp))
            if (modelFiles.isEmpty()) {
                Text(
                    "No GGUF files found",
                    fontSize = 13.sp,
                    color = AIOSColors.TextSecondary,
                )
            } else {
                modelFiles.forEach { file ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 3.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            file.name,
                            fontSize = 12.sp,
                            color = AIOSColors.TextSecondary,
                            fontFamily = FontFamily.Monospace,
                            modifier = Modifier.weight(1f),
                        )
                        Text(
                            formatFileSize(file.length()),
                            fontSize = 11.sp,
                            color = AIOSColors.TextTertiary,
                            fontFamily = FontFamily.Monospace,
                        )
                    }
                }
            }
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                "adb push model.gguf ${modelsDir.absolutePath}/",
                fontSize = 11.sp,
                color = AIOSColors.TextTertiary,
                fontFamily = FontFamily.Monospace,
            )
        }

        SettingsCard("Context Size") {
            IntInput(
                value = contextSize,
                onValueChange = { viewModel.updateContextSize(it) },
                label = "Context Size",
            )
            Text(
                "Larger values use more memory. Default: 2048",
                fontSize = 11.sp,
                color = AIOSColors.TextTertiary,
            )
        }

        SettingsCard("Max Tokens") {
            IntInput(
                value = maxTokensChat,
                onValueChange = { viewModel.updateMaxTokensChat(it) },
                label = "Chat Max Tokens",
            )
            Spacer(modifier = Modifier.height(8.dp))
            IntInput(
                value = maxTokensAgent,
                onValueChange = { viewModel.updateMaxTokensAgent(it) },
                label = "Agent Max Tokens",
            )
        }

        SettingsCard("Temperature") {
            SliderInput(
                value = temperature,
                onValueChange = { viewModel.updateTemperature(it) },
                valueRange = 0f..2f,
                label = "Temperature",
            )
            Text(
                "Higher = more creative, Lower = more focused",
                fontSize = 11.sp,
                color = AIOSColors.TextTertiary,
            )
        }

        SettingsCard("Top K") {
            IntInput(
                value = topK,
                onValueChange = { viewModel.updateTopK(it) },
                label = "Top K",
            )
            Text(
                "Limits sampling to top K tokens. Default: 40",
                fontSize = 11.sp,
                color = AIOSColors.TextTertiary,
            )
        }

        SettingsCard("Top P") {
            SliderInput(
                value = topP,
                onValueChange = { viewModel.updateTopP(it) },
                valueRange = 0f..1f,
                label = "Top P",
            )
            Text(
                "Nucleus sampling threshold. Default: 0.9",
                fontSize = 11.sp,
                color = AIOSColors.TextTertiary,
            )
        }

        SettingsCard("Repeat Penalty") {
            SliderInput(
                value = repeatPenalty,
                onValueChange = { viewModel.updateRepeatPenalty(it) },
                valueRange = 0f..2f,
                label = "Repeat Penalty",
            )
            Text(
                "Penalizes repeated tokens. Default: 1.1",
                fontSize = 11.sp,
                color = AIOSColors.TextTertiary,
            )
        }

        Spacer(modifier = Modifier.height(6.dp))

        SectionHeader("AGENT SETTINGS")
        HorizontalDivider(color = AIOSColors.Divider, thickness = 1.dp)
        Spacer(modifier = Modifier.height(2.dp))

        SettingsCard("Max Iterations") {
            IntInput(
                value = agentMaxIterations,
                onValueChange = { viewModel.updateAgentMaxIterations(it) },
                label = "Agent Max Iterations",
            )
            Text(
                "Maximum ReAct loop iterations. Default: 5",
                fontSize = 11.sp,
                color = AIOSColors.TextTertiary,
            )
        }

        Spacer(modifier = Modifier.height(6.dp))

        SectionHeader("UPDATE")
        HorizontalDivider(color = AIOSColors.Divider, thickness = 1.dp)
        Spacer(modifier = Modifier.height(2.dp))

        SettingsCard("App Update") {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (updateAvailable == true) {
                            Spacer(
                                modifier = Modifier
                                    .size(8.dp)
                                    .clip(CircleShape)
                                    .background(AIOSColors.Primary)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                "v${latestVersion} available",
                                fontSize = 14.sp,
                                color = AIOSColors.Primary,
                                fontWeight = FontWeight.Medium,
                            )
                        } else if (updateAvailable == false) {
                            Spacer(
                                modifier = Modifier
                                    .size(8.dp)
                                    .clip(CircleShape)
                                    .background(AIOSColors.StatusReady)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                "Up to date",
                                fontSize = 14.sp,
                                color = AIOSColors.StatusReady,
                                fontWeight = FontWeight.Medium,
                            )
                        } else {
                            Text(
                                "Tap to check",
                                fontSize = 14.sp,
                                color = AIOSColors.TextTertiary,
                                fontWeight = FontWeight.Medium,
                            )
                        }
                    }
                }
                OutlinedButton(
                    onClick = onNavigateToUpdate,
                    shape = RoundedCornerShape(10.dp),
                ) {
                    Text(
                        "Check",
                        fontSize = 12.sp,
                        color = AIOSColors.Primary,
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(6.dp))

        SectionHeader("SYSTEM")
        HorizontalDivider(color = AIOSColors.Divider, thickness = 1.dp)
        Spacer(modifier = Modifier.height(2.dp))

        SettingsCard("Service") {
            Text(
                "State: ${serviceState.name}",
                fontSize = 13.sp,
                color = AIOSColors.TextSecondary,
            )
        }

        Spacer(modifier = Modifier.height(6.dp))

        SectionHeader("INFO")
        HorizontalDivider(color = AIOSColors.Divider, thickness = 1.dp)
        Spacer(modifier = Modifier.height(2.dp))

        SettingsCard("About") {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Filled.SmartToy,
                    contentDescription = null,
                    tint = AIOSColors.TextPrimary,
                    modifier = Modifier.size(20.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    "AIOS",
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp,
                    color = AIOSColors.TextPrimary,
                )
            }
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                "Android Local LLM Agent Runtime",
                fontSize = 13.sp,
                color = AIOSColors.TextSecondary,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                "v${BuildConfig.VERSION_NAME} · Powered by llama.cpp",
                fontSize = 11.sp,
                color = AIOSColors.TextTertiary,
            )
        }
    }
}

@Composable
private fun SliderInput(
    value: Float,
    onValueChange: (Float) -> Unit,
    valueRange: ClosedFloatingPointRange<Float>,
    label: String,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            label,
            fontSize = 13.sp,
            color = AIOSColors.TextSecondary,
            modifier = Modifier.weight(1f),
        )
        Text(
            String.format("%.2f", value),
            fontSize = 13.sp,
            color = AIOSColors.TextPrimary,
            fontFamily = FontFamily.Monospace,
            modifier = Modifier.width(50.dp),
        )
    }
    Slider(
        value = value,
        onValueChange = onValueChange,
        valueRange = valueRange,
        colors = SliderDefaults.colors(
            thumbColor = AIOSColors.Primary,
            activeTrackColor = AIOSColors.Primary,
            inactiveTrackColor = AIOSColors.SurfaceVariant,
        ),
    )
}

@Composable
private fun IntInput(
    value: Int,
    onValueChange: (Int) -> Unit,
    label: String,
) {
    var text by remember(value) { mutableStateOf(value.toString()) }

    OutlinedTextField(
        value = text,
        onValueChange = { input ->
            text = input
            input.toIntOrNull()?.let { onValueChange(it) }
        },
        label = {
            Text(
                label,
                fontSize = 12.sp,
                color = AIOSColors.TextTertiary,
            )
        },
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = AIOSColors.TextPrimary,
            unfocusedTextColor = AIOSColors.TextPrimary,
            focusedBorderColor = AIOSColors.Primary,
            unfocusedBorderColor = AIOSColors.SurfaceVariant,
            cursorColor = AIOSColors.Primary,
            focusedLabelColor = AIOSColors.Primary,
            unfocusedLabelColor = AIOSColors.TextTertiary,
        ),
        shape = RoundedCornerShape(12.dp),
        textStyle = androidx.compose.ui.text.TextStyle(
            fontSize = 14.sp,
            fontFamily = FontFamily.Monospace,
        ),
    )
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        title,
        fontWeight = FontWeight.Bold,
        fontSize = 11.sp,
        color = AIOSColors.TextTertiary,
        letterSpacing = 1.sp,
    )
}

@Composable
private fun SettingsCard(
    title: String,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(AIOSColors.Surface)
            .padding(16.dp),
    ) {
        Text(
            title,
            fontWeight = FontWeight.SemiBold,
            fontSize = 15.sp,
            color = AIOSColors.TextPrimary,
        )
        Spacer(modifier = Modifier.height(8.dp))
        content()
    }
}
