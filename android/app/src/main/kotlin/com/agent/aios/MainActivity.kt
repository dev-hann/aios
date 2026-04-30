package com.agent.aios

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class MainActivity : FlutterActivity() {

    private val TAG = "AIOS-Main"
    private val CHANNEL = "com.agent.aios/runtime"
    private val TOKEN_CHANNEL = "com.agent.aios/tokens"
    private val AGENT_CHANNEL = "com.agent.aios/agent"

    private var llmService: LlmService? = null
    private var isBound = false
    private var tokenSink: EventChannel.EventSink? = null
    private var agentStepSink: EventChannel.EventSink? = null

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val binder = service as LlmService.LlmBinder
            llmService = binder.getService()
            isBound = true
            llmService!!.setTokenCallback { token ->
                runOnUiThread { tokenSink?.success(token) }
            }
            Log.i(TAG, "Service connected")
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            llmService = null
            isBound = false
            Log.i(TAG, "Service disconnected")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val intent = Intent(this, LlmService::class.java)
        startForegroundService(intent)
        bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, TOKEN_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    tokenSink = sink
                    Log.i(TAG, "Token stream: listening")
                }
                override fun onCancel(args: Any?) {
                    tokenSink = null
                    Log.i(TAG, "Token stream: cancelled")
                }
            })

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, AGENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    agentStepSink = sink
                    Log.i(TAG, "Agent stream: listening")
                }
                override fun onCancel(args: Any?) {
                    agentStepSink = null
                    Log.i(TAG, "Agent stream: cancelled")
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "loadModel" -> handleLoadModel(call, result)
                        "generateStream" -> handleGenerateStream(call, result)
                        "releaseModel" -> {
                            llmService?.releaseModel()
                            llmService?.updateNotification("Model released")
                            result.success(true)
                        }
                        "isModelLoaded" -> result.success(llmService?.isModelLoaded() ?: false)
                        "getModelInfo" -> result.success(llmService?.getModelInfo() ?: "No service")
                        "getModelsDir" -> {
                            val dir = File(filesDir, "models")
                            if (!dir.exists()) dir.mkdirs()
                            result.success(dir.absolutePath)
                        }
                        "listModels" -> {
                            val models = mutableListOf<String>()
                            val internalDir = File(filesDir, "models")
                            if (!internalDir.exists()) internalDir.mkdirs()
                            internalDir.listFiles()
                                ?.filter { it.extension == "gguf" }
                                ?.forEach { models.add("internal|${it.name}|${it.length()}|${it.absolutePath}") }
                            result.success(models)
                        }
                        "getToolManifest" -> {
                            val engine = llmService?.getAgentEngine()
                            if (engine != null) {
                                result.success(engine.getToolManifest())
                            } else {
                                result.error("NO_AGENT", "Agent engine not initialized. Load a model first.", null)
                            }
                        }
                        "runAgent" -> {
                            val prompt = call.argument<String>("prompt") ?: ""
                            val maxIter = call.argument<Int>("maxIterations") ?: 5
                            handleAgentRun(prompt, maxIter, result)
                        }
                        "stopService" -> {
                            llmService?.releaseModel()
                            unbindService(serviceConnection)
                            stopService(Intent(this, LlmService::class.java))
                            isBound = false
                            llmService = null
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Method ${call.method} error: ${e.message}", e)
                    result.error("ERROR", e.message, null)
                }
            }

        Log.i(TAG, "Flutter engine configured")
    }

    private fun handleLoadModel(call: io.flutter.plugin.common.MethodCall, result: io.flutter.plugin.common.MethodChannel.Result) {
        val modelPath = call.argument<String>("path")!!
        val contextSize = call.argument<Int>("contextSize") ?: 1024
        val svc = llmService

        if (svc == null) {
            result.error("NO_SERVICE", "LlmService not bound", null)
            return
        }

        val file = File(modelPath)
        if (!file.exists()) {
            result.error("NOT_FOUND", "File not found: $modelPath", null)
            return
        }
        Log.i(TAG, "Model file size: ${file.length()} bytes (${file.absolutePath})")

        Thread {
            Log.i(TAG, "Starting model load (n_ctx=$contextSize)")
            svc.updateNotification("Loading model...")
            val success = svc.loadModel(modelPath, contextSize)
            Log.i(TAG, "Model load result: $success")
            runOnUiThread {
                if (success) {
                    svc.updateNotification("Model loaded - Ready")
                    result.success(true)
                } else {
                    result.error("LOAD_FAILED", "nativeLoadModel returned false", null)
                }
            }
        }.start()
    }

    private fun handleGenerateStream(call: io.flutter.plugin.common.MethodCall, result: io.flutter.plugin.common.MethodChannel.Result) {
        val prompt = call.argument<String>("prompt") ?: ""
        val maxTokens = call.argument<Int>("maxTokens") ?: 128
        val svc = llmService

        if (svc == null) {
            result.error("NO_SERVICE", "LlmService not bound", null)
            return
        }

        Thread {
            svc.updateNotification("Generating...")
            val count = svc.generateStream(prompt, maxTokens)
            Log.i(TAG, "Stream generate done: $count tokens")
            runOnUiThread {
                svc.updateNotification("Ready")
                result.success(count)
            }
        }.start()
    }

    private fun handleAgentRun(prompt: String, maxIterations: Int, result: io.flutter.plugin.common.MethodChannel.Result) {
        val svc = llmService
        if (svc == null) {
            result.error("NO_SERVICE", "LlmService not bound", null)
            return
        }

        val engine = svc.getAgentEngine()
        if (engine == null) {
            result.error("NO_AGENT", "Agent engine not initialized", null)
            return
        }

        Thread {
            svc.updateNotification("Agent running...")
            engine.setStepCallback { step ->
                runOnUiThread {
                    val json = JSONObject().apply {
                        put("type", step.type)
                        put("content", step.content)
                        if (step.toolName.isNotEmpty()) {
                            put("toolName", step.toolName)
                            put("toolArgs", step.toolArgs)
                            put("toolResult", step.toolResult)
                        }
                    }
                    agentStepSink?.success(json.toString())
                }
            }

            val steps = engine.run(prompt, maxIterations)
            val resultArray = JSONArray()
            for (step in steps) {
                resultArray.put(JSONObject().apply {
                    put("type", step.type)
                    put("content", step.content)
                    if (step.toolName.isNotEmpty()) {
                        put("toolName", step.toolName)
                        put("toolArgs", step.toolArgs)
                        put("toolResult", step.toolResult)
                    }
                })
            }

            runOnUiThread {
                svc.updateNotification("Ready")
                result.success(resultArray.toString())
            }
        }.start()
    }

    override fun onDestroy() {
        if (isBound) {
            try { unbindService(serviceConnection) } catch (_: Exception) {}
        }
        super.onDestroy()
    }
}
