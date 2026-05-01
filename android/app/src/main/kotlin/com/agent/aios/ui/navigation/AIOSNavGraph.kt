package com.agent.aios.ui.navigation

import android.net.Uri
import androidx.activity.result.ActivityResultLauncher
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.agent.aios.rememberModelImportLauncher
import com.agent.aios.ui.screen.AccessibilitySetupScreen
import com.agent.aios.ui.screen.ChatScreen
import com.agent.aios.ui.screen.SettingsScreen
import com.agent.aios.ui.screen.UpdateScreen
import com.agent.aios.ui.theme.AIOSColors

sealed class Screen(val route: String, val label: String, val icon: ImageVector) {
    data object Chat : Screen("chat", "Chat", Icons.AutoMirrored.Filled.Chat)
    data object Settings : Screen("settings", "Settings", Icons.Filled.Settings)
    data object Update : Screen("update", "Update", Icons.Filled.Settings)
}

@Composable
fun AIOSApp(
    onPickModelFile: (ActivityResultLauncher<Array<String>>) -> Unit = {},
    pendingImportUri: Uri? = null,
    pendingImportName: String? = null,
    onImportConsumed: () -> Unit = {},
) {
    val navController = rememberNavController()
    val screens = listOf(Screen.Chat, Screen.Settings)

    val pendingImportCallback = remember { mutableStateOf<((Uri, String) -> Unit)?>(null) }

    val modelImportLauncher = rememberModelImportLauncher { uri, name ->
        pendingImportCallback.value?.invoke(uri, name)
        pendingImportCallback.value = null
    }

    Scaffold(
        containerColor = AIOSColors.Background,
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            NavHost(
                navController = navController,
                startDestination = Screen.Chat.route,
                modifier = Modifier.fillMaxSize()
            ) {
                composable(Screen.Chat.route) {
                    ChatScreen(
                        onImportFile = {
                            pendingImportCallback.value = { uri, name ->
                                com.agent.aios.AIOSApp.instance.chatViewModel?.importModelFromUri(uri, name)
                            }
                            onPickModelFile(modelImportLauncher)
                        }
                    )
                }
                composable(Screen.Settings.route) {
                    SettingsScreen(
                        onNavigateToUpdate = {
                            navController.navigate(Screen.Update.route)
                        }
                    )
                }
                composable(Screen.Update.route) {
                    UpdateScreen(onBack = { navController.popBackStack() })
                }
            }

            val navBackStackEntry by navController.currentBackStackEntryAsState()
            val currentRoute = navBackStackEntry?.destination?.route

            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = 24.dp)
                    .padding(bottom = 8.dp)
                    .navigationBarsPadding()
            ) {
                Row(
                    modifier = Modifier
                        .shadow(8.dp, RoundedCornerShape(24.dp))
                        .clip(RoundedCornerShape(24.dp))
                        .background(AIOSColors.SurfaceElevated)
                        .border(1.dp, AIOSColors.SurfaceVariant, RoundedCornerShape(24.dp))
                        .padding(horizontal = 8.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                ) {
                    screens.forEach { screen ->
                        val isSelected = currentRoute == screen.route
                        Column(
                            modifier = Modifier
                                .clip(RoundedCornerShape(16.dp))
                                .clickable {
                                    navController.navigate(screen.route) {
                                        popUpTo(navController.graph.findStartDestination().id) {
                                            saveState = true
                                        }
                                        launchSingleTop = true
                                        restoreState = true
                                    }
                                }
                                .padding(horizontal = 24.dp, vertical = 8.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Icon(
                                screen.icon,
                                contentDescription = screen.label,
                                tint = if (isSelected) AIOSColors.Primary else AIOSColors.TextTertiary,
                                modifier = Modifier.size(22.dp),
                            )
                            Text(
                                screen.label,
                                fontSize = 11.sp,
                                color = if (isSelected) AIOSColors.Primary else AIOSColors.TextTertiary,
                            )
                        }
                    }
                }
            }
        }
    }
}
