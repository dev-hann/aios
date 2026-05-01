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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Divider
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.toUpperCase
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.agent.aios.AIOSApp
import com.agent.aios.ui.theme.AIOSColors
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
fun SettingsScreen() {
    val context = LocalContext.current
    val serviceState by AIOSApp.instance.serviceState.collectAsState(AIOSApp.ServiceState.DISCONNECTED)
    val isModelLoaded = AIOSApp.instance.llmService?.isModelLoaded() ?: false
    val modelInfo = AIOSApp.instance.llmService?.getModelInfo() ?: "N/A"

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

        SectionHeader("AI MODEL")
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
                "v1.0.0 · Powered by llama.cpp",
                fontSize = 11.sp,
                color = AIOSColors.TextTertiary,
            )
        }
    }
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
