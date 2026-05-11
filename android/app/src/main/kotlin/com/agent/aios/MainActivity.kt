package com.agent.aios

import android.annotation.SuppressLint
import android.os.Bundle
import android.util.Log
import android.webkit.ConsoleMessage
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import org.json.JSONObject
import gyo.plugins.bridge.AndroidBridgeInterface
import gyo.plugins.bridge.BridgeRegistry
import gyo.plugins.bridge.PluginRegistry

class MainActivity : AppCompatActivity() {
    private lateinit var webView: WebView
    private lateinit var gyoConfig: GyoConfig

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        gyoConfig = loadGyoConfig()

        webView = WebView(this)
        setContentView(webView)

        setupWebView()
        loadApp()
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun setupWebView() {
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            allowFileAccess = false
            allowContentAccess = true
            allowUniversalAccessFromFileURLs = false
            mediaPlaybackRequiresUserGesture = false
            WebView.setWebContentsDebuggingEnabled(true)
        }

        BridgeRegistry.initialize()
        PluginRegistry.registerAll(this)

        val bridgeInterface = AndroidBridgeInterface(webView)
        webView.addJavascriptInterface(bridgeInterface, "androidBridge")

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                injectGyoRuntime()
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(consoleMessage: ConsoleMessage): Boolean {
                val logTag = "WebView-Console"
                val message = "${consoleMessage.message()} -- From line ${consoleMessage.lineNumber()} of ${consoleMessage.sourceId()}"

                when (consoleMessage.messageLevel()) {
                    ConsoleMessage.MessageLevel.ERROR -> Log.e(logTag, message)
                    ConsoleMessage.MessageLevel.WARNING -> Log.w(logTag, message)
                    ConsoleMessage.MessageLevel.DEBUG -> Log.d(logTag, message)
                    else -> Log.i(logTag, message)
                }

                return true
            }
        }
    }

    private fun loadApp() {
        val url = gyoConfig.serverUrl
        webView.loadUrl(url)
    }

    private fun injectGyoRuntime() {
        val script = """
            (function() {
                function postMessage(message) {
                    if (window.androidBridge) {
                        window.androidBridge.postMessage(JSON.stringify(message));
                    }
                }

                window.gyo = {
                    platform: 'android',
                    __bridge: {
                        postMessage: postMessage
                    }
                };

                console.log('[AIOS] gyo runtime initialized on Android');
            })();
        """.trimIndent()

        webView.evaluateJavascript(script, null)
    }

    private fun loadGyoConfig(): GyoConfig {
        try {
            val json = assets.open("gyo-config.json").bufferedReader().use { it.readText() }
            val jsonObject = JSONObject(json)
            val serverUrl = jsonObject.optString("serverUrl", "")

            if (serverUrl.isEmpty()) {
                Log.e("AIOS-Main", "serverUrl is empty in gyo-config.json")
                throw IllegalStateException("serverUrl is empty in gyo-config.json")
            }

            Log.i("AIOS-Main", "Loaded config - serverUrl: $serverUrl")
            return GyoConfig(serverUrl = serverUrl)
        } catch (e: Exception) {
            Log.e("AIOS-Main", "Failed to load gyo-config.json: ${e.message}")
            throw IllegalStateException("gyo-config.json must be present with valid serverUrl", e)
        }
    }

    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }

    data class GyoConfig(val serverUrl: String)
}
