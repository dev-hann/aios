package com.agent.aios.ui.navigation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.agent.aios.ui.screen.AccessibilitySetupScreen
import com.agent.aios.ui.screen.ChatScreen
import com.agent.aios.ui.screen.DashboardScreen
import com.agent.aios.ui.screen.SettingsScreen
import com.agent.aios.ui.theme.AIOSColors

sealed class Screen(val route: String, val label: String, val icon: ImageVector) {
    data object Chat : Screen("chat", "Chat", Icons.AutoMirrored.Filled.Chat)
    data object Dashboard : Screen("dashboard", "Control", Icons.Filled.Dashboard)
    data object Settings : Screen("settings", "Settings", Icons.Filled.Settings)
    data object AccessibilitySetup : Screen("accessibility_setup", "Accessibility", Icons.Filled.Settings)
}

@Composable
fun AIOSApp() {
    val navController = rememberNavController()
    val screens = listOf(Screen.Chat, Screen.Dashboard, Screen.Settings)

    Scaffold(
        containerColor = AIOSColors.Background,
        bottomBar = {
            val navBackStackEntry by navController.currentBackStackEntryAsState()
            val currentRoute = navBackStackEntry?.destination?.route

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AIOSColors.Surface)
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
            ) {
                screens.forEach { screen ->
                    val isSelected = currentRoute == screen.route
                    Column(
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .clickable {
                                navController.navigate(screen.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            }
                            .padding(horizontal = 20.dp, vertical = 8.dp),
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
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Screen.Chat.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            composable(Screen.Chat.route) { ChatScreen() }
            composable(Screen.Dashboard.route) {
                DashboardScreen(
                    onSetupAccessibility = {
                        navController.navigate(Screen.AccessibilitySetup.route)
                    }
                )
            }
            composable(Screen.Settings.route) { SettingsScreen() }
            composable(Screen.AccessibilitySetup.route) {
                AccessibilitySetupScreen(onBack = { navController.popBackStack() })
            }
        }
    }
}
