package com.agent.aios.ui.screen

import android.content.Intent
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.agent.aios.service.AIOSAccessibilityService
import com.agent.aios.ui.theme.AIOSColors

@Composable
fun AccessibilitySetupScreen(
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val isEnabled = AIOSAccessibilityService.isEnabled(context)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AIOSColors.Background)
            .statusBarsPadding()
            .padding(20.dp)
            .verticalScroll(rememberScrollState())
    ) {
        IconButton(onClick = onBack) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
                tint = AIOSColors.TextPrimary,
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            "Accessibility Setup",
            fontWeight = FontWeight.Bold,
            fontSize = 24.sp,
            color = AIOSColors.TextPrimary,
        )
        Spacer(modifier = Modifier.height(16.dp))

        val capabilities = listOf(
            "Read screen text" to "AI understands what's displayed in any app",
            "Tap buttons & controls" to "Interact with any UI element",
            "Type into fields" to "Enter text in any input field",
            "Scroll content" to "Navigate through lists and pages",
            "Switch between apps" to "Open and manage applications",
        )

        capabilities.forEach { (title, desc) ->
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(AIOSColors.Surface)
                    .padding(14.dp),
            ) {
                Text(title, fontWeight = FontWeight.Medium, fontSize = 15.sp, color = AIOSColors.TextPrimary)
                Text(desc, fontSize = 12.sp, color = AIOSColors.TextTertiary)
            }
            Spacer(modifier = Modifier.height(8.dp))
        }

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            "All processing is on-device. No data leaves your phone.",
            fontSize = 13.sp,
            color = AIOSColors.TextTertiary,
        )

        Spacer(modifier = Modifier.height(24.dp))

        Button(
            onClick = {
                if (!isEnabled) {
                    context.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                } else {
                    onBack()
                }
            },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = AIOSColors.Primary,
                contentColor = Color.White,
            ),
        ) {
            Text(
                if (isEnabled) "Enabled - Go Back" else "Open Accessibility Settings",
                fontWeight = FontWeight.SemiBold,
            )
        }

        if (!isEnabled) {
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                "Find \"AIOS\" in the list and enable it.",
                fontSize = 12.sp,
                color = AIOSColors.TextTertiary,
            )
        }
    }
}
