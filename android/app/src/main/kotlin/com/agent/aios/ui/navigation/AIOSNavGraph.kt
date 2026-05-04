package com.agent.aios.ui.navigation

import android.net.Uri
import androidx.activity.result.ActivityResultLauncher
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.agent.aios.rememberModelImportLauncher
import com.agent.aios.ui.screen.ChatScreen
import com.agent.aios.ui.screen.SettingsScreen
import com.agent.aios.ui.screen.UpdateScreen
import com.agent.aios.ui.theme.AIOSColors
import com.agent.aios.ui.viewmodel.ChatViewModel

sealed class Screen(val route: String) {
    data object Chat : Screen("chat")

    data object Settings : Screen("settings")

    data object Update : Screen("update")
}

@Composable
fun AIOSNavHost(
    onPickModelFile: (ActivityResultLauncher<Array<String>>) -> Unit = {},
    pendingImportUri: Uri? = null,
    pendingImportName: String? = null,
    onImportConsumed: () -> Unit = {},
) {
    val navController = rememberNavController()
    val chatViewModel: ChatViewModel = hiltViewModel()

    val pendingImportCallback = remember { mutableStateOf<((Uri, String) -> Unit)?>(null) }

    val modelImportLauncher =
        rememberModelImportLauncher { uri, name ->
            pendingImportCallback.value?.invoke(uri, name)
            pendingImportCallback.value = null
        }

    Scaffold(
        containerColor = AIOSColors.Background,
    ) { innerPadding ->
        Box(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
        ) {
            NavHost(
                navController = navController,
                startDestination = Screen.Chat.route,
                modifier = Modifier.fillMaxSize(),
            ) {
                composable(Screen.Chat.route) {
                    ChatScreen(
                        vm = chatViewModel,
                        onNavigateToSettings = {
                            navController.navigate(Screen.Settings.route)
                        },
                    )
                }
                composable(Screen.Settings.route) {
                    SettingsScreen(
                        onBack = { navController.popBackStack() },
                        onNavigateToUpdate = {
                            navController.navigate(Screen.Update.route)
                        },
                        onImportFile = {
                            pendingImportCallback.value = { uri, name ->
                                chatViewModel.importModelFromUri(uri, name)
                            }
                            onPickModelFile(modelImportLauncher)
                        },
                        chatViewModel = chatViewModel,
                    )
                }
                composable(Screen.Update.route) {
                    UpdateScreen(onBack = { navController.popBackStack() })
                }
            }
        }
    }
}
