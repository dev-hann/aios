package com.agent.aios.ui

import android.app.Application
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.agent.aios.ui.screen.UpdateScreen
import com.agent.aios.ui.theme.AIOSTheme
import com.agent.aios.ui.viewmodel.UpdateStatus
import com.agent.aios.ui.viewmodel.UpdateViewModel
import com.agent.aios.update.UpdateInfo
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class UpdateScreenTest {

    @get:Rule
    val composeRule = createComposeRule()

    private lateinit var viewModel: UpdateViewModel

    @Before
    fun setup() {
        val app = InstrumentationRegistry.getInstrumentation()
            .targetContext.applicationContext as Application
        viewModel = UpdateViewModel(app)
    }

    @Suppress("UNCHECKED_CAST")
    private fun setFlow(fieldName: String, value: Any?) {
        val field = UpdateViewModel::class.java.getDeclaredField(fieldName)
        field.isAccessible = true
        (field.get(viewModel) as MutableStateFlow<Any?>).value = value
    }

    private fun testUpdateInfo(
        isUpdateAvailable: Boolean = true,
        currentVersion: String = "1.0.0",
        latestVersion: String = "1.1.0",
    ) = UpdateInfo(
        isUpdateAvailable = isUpdateAvailable,
        currentVersion = currentVersion,
        latestVersion = latestVersion,
        downloadUrl = "https://example.com/aios-1.1.0.apk",
        fileSize = 50_000_000L,
        releaseNotes = "Bug fixes and improvements",
        publishedAt = "2024-01-01",
    )

    private fun setContentWithTheme(onBack: () -> Unit = {}) {
        composeRule.setContent {
            AIOSTheme {
                UpdateScreen(onBack = onBack, vm = viewModel)
            }
        }
    }

    @Test
    fun checkingState_showsProgressAndText() {
        setFlow("_status", UpdateStatus.CHECKING)
        setContentWithTheme()

        composeRule.onNodeWithText("Checking for updates...").assertIsDisplayed()
    }

    @Test
    fun updateAvailable_showsVersionAndDownloadButton() {
        setFlow("_status", UpdateStatus.AVAILABLE)
        setFlow("_updateInfo", testUpdateInfo())
        setContentWithTheme()

        composeRule.onNodeWithText("v1.1.0 available").assertIsDisplayed()
        composeRule.onNodeWithText("Current: v1.0.0").assertIsDisplayed()
        composeRule.onNodeWithText("Latest: v1.1.0").assertIsDisplayed()
        composeRule.onNodeWithText("Download Update").assertIsDisplayed()
    }

    @Test
    fun upToDate_showsCheckmarkAndText() {
        setFlow("_status", UpdateStatus.NOT_AVAILABLE)
        setFlow("_updateInfo", testUpdateInfo(
            isUpdateAvailable = false,
            currentVersion = "1.1.0",
            latestVersion = "1.1.0",
        ))
        setContentWithTheme()

        composeRule.onNodeWithText("You're up to date!").assertIsDisplayed()
        composeRule.onNodeWithText("v1.1.0 is the latest version").assertIsDisplayed()
        composeRule.onNodeWithText("Check Again").assertIsDisplayed()
    }

    @Test
    fun errorState_showsErrorAndRetry() {
        setFlow("_status", UpdateStatus.ERROR)
        setFlow("_error", "Network error")
        setContentWithTheme()

        composeRule.onNodeWithText("Error").assertIsDisplayed()
        composeRule.onNodeWithText("Network error").assertIsDisplayed()
        composeRule.onNodeWithText("Retry").assertIsDisplayed()
    }

    @Test
    fun downloadingState_showsProgressBarAndPercentage() {
        setFlow("_status", UpdateStatus.DOWNLOADING)
        setFlow("_downloadProgress", 0.45f)
        setFlow("_updateInfo", testUpdateInfo())
        setContentWithTheme()

        composeRule.onNodeWithText("Downloading v1.1.0...").assertIsDisplayed()
        composeRule.onNodeWithText("45%").assertIsDisplayed()
    }

    @Test
    fun backButton_callsOnBack() {
        var backCalled = false
        setFlow("_status", UpdateStatus.CHECKING)
        setContentWithTheme(onBack = { backCalled = true })

        composeRule.onNodeWithContentDescription("Back").performClick()
        assertTrue(backCalled)
    }
}
