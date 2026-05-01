package com.agent.aios

import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.agent.aios.ui.navigation.AIOSApp
import com.agent.aios.ui.theme.AIOSTheme

class MainActivity : ComponentActivity() {

    companion object {
        var pendingModelImport by mutableStateOf<Uri?>(null)
            private set
        var pendingModelImportName by mutableStateOf<String?>(null)
            private set
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            AIOSTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    AIOSApp(
                        onPickModelFile = { launcher ->
                            launcher.launch(arrayOf("*/*"))
                        },
                        pendingImportUri = pendingModelImport,
                        pendingImportName = pendingModelImportName,
                        onImportConsumed = {
                            pendingModelImport = null
                            pendingModelImportName = null
                        }
                    )
                }
            }
        }
    }
}

@Composable
fun rememberModelImportLauncher(
    onResult: (Uri, String) -> Unit
): androidx.activity.result.ActivityResultLauncher<Array<String>> {
    return rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        uri?.let {
            val name = getFileName(it)
            onResult(it, name)
        }
    }
}

private fun getFileName(uri: Uri): String {
    return try {
        AIOSApp.instance.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (cursor.moveToFirst() && nameIndex >= 0) cursor.getString(nameIndex)
            else uri.lastPathSegment ?: "model.gguf"
        } ?: uri.lastPathSegment ?: "model.gguf"
    } catch (e: Exception) {
        Log.w("MainActivity", "Failed to get file name", e)
        "model.gguf"
    }
}
