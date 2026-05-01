package com.agent.aios.ui.screen

import android.content.Intent
import android.provider.Settings
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.agent.aios.AIOSApp
import com.agent.aios.service.AIOSAccessibilityService
import com.agent.aios.ui.theme.AIOSColors

@Composable
fun DashboardScreen(
    onSetupAccessibility: () -> Unit,
) {
    val context = LocalContext.current
    val serviceState by AIOSApp.instance.serviceState.collectAsState(AIOSApp.ServiceState.DISCONNECTED)
    val isAccessibilityEnabled = AIOSAccessibilityService.isEnabled(context)
    val isNotificationEnabled = hasNotificationAccess(context)
    val isOverlayEnabled = Settings.canDrawOverlays(context)
    val grantedCount = listOf(isAccessibilityEnabled, isNotificationEnabled, isOverlayEnabled).count { it }
    var overlayEnabled by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AIOSColors.Background)
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            "Phone Control",
            fontWeight = FontWeight.Bold,
            fontSize = 24.sp,
            color = AIOSColors.TextPrimary,
        )
        Text(
            "Grant permissions to let AI control your device.",
            fontSize = 14.sp,
            color = AIOSColors.TextSecondary,
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(8.dp))
                .background(AIOSColors.SurfaceVariant)
                .padding(4.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            repeat(3) { index ->
                val isGranted = index < grantedCount
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(6.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(
                            if (isGranted) AIOSColors.StatusReady
                            else AIOSColors.SurfaceVariant
                        ),
                )
            }
        }
        Text(
            "$grantedCount of 3 permissions granted",
            fontSize = 12.sp,
            color = AIOSColors.TextTertiary,
        )

        PermissionCard(
            title = "Accessibility",
            subtitle = "Read screen & perform actions",
            isEnabled = isAccessibilityEnabled,
            onEnable = { context.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }
        )

        PermissionCard(
            title = "Notifications",
            subtitle = "Read & respond to notifications",
            isEnabled = isNotificationEnabled,
            onEnable = { context.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)) }
        )

        PermissionCard(
            title = "Overlay",
            subtitle = "Floating AI button on any app",
            isEnabled = isOverlayEnabled,
            onEnable = {
                context.startActivity(
                    Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        android.net.Uri.parse("package:${context.packageName}"))
                )
            }
        )

        Spacer(modifier = Modifier.height(8.dp))

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(AIOSColors.Surface)
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column {
                Text(
                    "Overlay Service",
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 15.sp,
                    color = AIOSColors.TextPrimary,
                )
                Text(
                    if (overlayEnabled) "Running" else "Stopped",
                    fontSize = 12.sp,
                    color = if (overlayEnabled) AIOSColors.StatusReady else AIOSColors.TextTertiary,
                )
            }
            Switch(
                checked = overlayEnabled,
                onCheckedChange = { enabled ->
                    overlayEnabled = enabled
                    val intent = Intent(context, Class.forName("com.agent.aios.service.OverlayService"))
                    if (enabled) {
                        context.startService(intent)
                    } else {
                        context.stopService(intent)
                    }
                },
                colors = SwitchDefaults.colors(
                    checkedTrackColor = AIOSColors.Accent,
                    checkedThumbColor = Color.White,
                    uncheckedTrackColor = AIOSColors.SurfaceVariant,
                    uncheckedThumbColor = AIOSColors.TextTertiary,
                ),
            )
        }

        StatusCard(serviceState)
    }
}

private fun hasNotificationAccess(context: android.content.Context): Boolean {
    val cn = android.content.ComponentName(context, Class.forName("com.agent.aios.service.NotificationListener"))
    val flat = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
    return flat != null && flat.contains(cn.flattenToString())
}

@Composable
private fun PermissionCard(
    title: String,
    subtitle: String,
    isEnabled: Boolean,
    onEnable: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(AIOSColors.Surface)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(42.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(
                    if (isEnabled) AIOSColors.StatusReady.copy(alpha = 0.15f)
                    else AIOSColors.StatusError.copy(alpha = 0.15f)
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                if (isEnabled) Icons.Filled.CheckCircle else Icons.Filled.Warning,
                contentDescription = null,
                tint = if (isEnabled) AIOSColors.StatusReady else AIOSColors.StatusError,
                modifier = Modifier.size(22.dp),
            )
        }
        Spacer(modifier = Modifier.width(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                title,
                fontWeight = FontWeight.SemiBold,
                fontSize = 15.sp,
                color = AIOSColors.TextPrimary,
            )
            Text(
                subtitle,
                fontSize = 12.sp,
                color = AIOSColors.TextTertiary,
            )
        }
        if (!isEnabled) {
            Button(
                onClick = onEnable,
                shape = RoundedCornerShape(10.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = AIOSColors.Primary,
                    contentColor = Color.White,
                ),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 14.dp, vertical = 6.dp),
            ) { Text("Enable", fontSize = 12.sp) }
        }
    }
}

@Composable
private fun StatusCard(state: AIOSApp.ServiceState) {
    val borderColor = when (state) {
        AIOSApp.ServiceState.MODEL_LOADED -> AIOSColors.StatusReady
        AIOSApp.ServiceState.DISCONNECTED -> AIOSColors.StatusError
        else -> AIOSColors.StatusRunning
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
                .background(borderColor)
        )
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                "Service Status",
                fontWeight = FontWeight.SemiBold,
                fontSize = 15.sp,
                color = AIOSColors.TextPrimary,
            )
            Spacer(modifier = Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(borderColor)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(state.name, fontSize = 13.sp, color = AIOSColors.TextSecondary)
            }
        }
    }
}
