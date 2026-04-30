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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.agent.aios.AIOSApp
import com.agent.aios.ui.theme.AIOSColors
import java.io.File

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
            .statusBarsPadding()
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

        SettingsCard("Model") {
            Text(
                if (isModelLoaded) "Loaded" else "Not loaded",
                fontSize = 14.sp,
                color = if (isModelLoaded) AIOSColors.StatusReady else AIOSColors.TextTertiary,
                fontWeight = FontWeight.Medium,
            )
            if (isModelLoaded) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(modelInfo, fontSize = 11.sp, color = AIOSColors.TextTertiary, fontFamily = FontFamily.Monospace)
                Spacer(modifier = Modifier.height(10.dp))
                OutlinedButton(
                    onClick = { AIOSApp.instance.releaseModel() },
                    shape = RoundedCornerShape(10.dp),
                ) { Text("Release", fontSize = 12.sp) }
            }
        }

        SettingsCard("Models Directory") {
            Text(modelsDir.absolutePath, fontSize = 11.sp, color = AIOSColors.TextTertiary, fontFamily = FontFamily.Monospace)
            Spacer(modifier = Modifier.height(4.dp))
            Text("${modelFiles.size} GGUF files", fontSize = 13.sp, color = AIOSColors.TextSecondary)
            Spacer(modifier = Modifier.height(4.dp))
            Text("adb push model.gguf ${modelsDir.absolutePath}/", fontSize = 11.sp, color = AIOSColors.TextTertiary, fontFamily = FontFamily.Monospace)
        }

        SettingsCard("Service") {
            Text("State: ${serviceState.name}", fontSize = 13.sp, color = AIOSColors.TextSecondary)
        }

        SettingsCard("About") {
            Text("AIOS - Android Local LLM Agent Runtime", fontSize = 13.sp, color = AIOSColors.TextSecondary)
            Text("v1.0.0 | Powered by llama.cpp", fontSize = 11.sp, color = AIOSColors.TextTertiary)
        }
    }
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
