package com.agent.aios.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val ColorScheme = darkColorScheme(
    primary = AIOSColors.Primary,
    onPrimary = AIOSColors.TextPrimary,
    primaryContainer = AIOSColors.PrimaryDim,
    onPrimaryContainer = AIOSColors.PrimaryVariant,
    secondary = AIOSColors.Secondary,
    onSecondary = AIOSColors.TextPrimary,
    secondaryContainer = AIOSColors.SecondaryDim,
    tertiary = AIOSColors.Accent,
    background = AIOSColors.Background,
    onBackground = AIOSColors.TextPrimary,
    surface = AIOSColors.Surface,
    onSurface = AIOSColors.TextPrimary,
    surfaceVariant = AIOSColors.SurfaceVariant,
    onSurfaceVariant = AIOSColors.TextSecondary,
    outline = AIOSColors.Divider,
    outlineVariant = AIOSColors.SurfaceElevated,
)

@Composable
fun AIOSTheme(
    content: @Composable () -> Unit,
) {
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = false
        }
    }

    MaterialTheme(
        colorScheme = ColorScheme,
        typography = AIOSTypography,
        content = content,
    )
}
