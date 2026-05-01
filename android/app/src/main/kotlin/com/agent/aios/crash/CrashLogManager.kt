package com.agent.aios.crash

import android.content.Context
import android.os.Build
import android.util.Log
import com.agent.aios.BuildConfig
import java.io.File
import java.io.FileOutputStream
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object CrashLogManager {

    private const val TAG = "AIOS-Crash"
    private const val MAX_LOG_FILES = 10
    private const val LOG_DIR = "crash_logs"
    private const val SIGNAL_LOG_PREFIX = "signal_"
    private val DATE_FORMAT = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US)

    private var crashLogDir: String? = null

    fun init(context: Context) {
        crashLogDir = getLogDir(context).absolutePath

        installSignalHandler()

        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            logCrash(context, thread, throwable)
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }

    private fun installSignalHandler() {
        try {
            System.loadLibrary("aios-crash")
            nativeInstallSignalHandler(crashLogDir)
            Log.i(TAG, "Native signal handler installed")
        } catch (e: UnsatisfiedLinkError) {
            Log.w(TAG, "aios-crash library not available, signal handling disabled")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to install signal handler", e)
        }
    }

    private external fun nativeInstallSignalHandler(logDir: String?)

    fun logCrash(context: Context, thread: Thread, throwable: Throwable) {
        try {
            val logDir = getLogDir(context)
            if (!logDir.exists()) logDir.mkdirs()

            val timestamp = System.currentTimeMillis()
            val filename = "crash_${DATE_FORMAT.format(Date(timestamp))}.log"
            val file = File(logDir, filename)

            val sw = StringWriter()
            PrintWriter(sw).use { pw ->
                pw.println("=== AIOS Crash Log ===")
                pw.println("Time: ${SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date(timestamp))}")
                pw.println("Thread: ${thread.name}")
                pw.println("App Version: ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})")
                pw.println("Device: ${Build.MANUFACTURER} ${Build.MODEL} (Android ${Build.VERSION.RELEASE}, SDK ${Build.VERSION.SDK_INT})")
                pw.println()
                pw.println("Exception: ${throwable.javaClass.name}")
                pw.println("Message: ${throwable.message ?: "N/A"}")
                pw.println()
                pw.println("Stack Trace:")
                throwable.printStackTrace(pw)

                var cause = throwable.cause
                while (cause != null) {
                    pw.println()
                    pw.println("Caused by: ${cause.javaClass.name}: ${cause.message ?: "N/A"}")
                    cause.printStackTrace(pw)
                    cause = cause.cause
                }
            }

            file.writeText(sw.toString())
            trimOldLogs(logDir)
            Log.i(TAG, "Crash log written: $filename")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write crash log", e)
        }
    }

    fun logSignalCrash(context: Context, signal: Int, timestamp: Long) {
        try {
            val logDir = getLogDir(context)
            if (!logDir.exists()) logDir.mkdirs()

            val filename = "${SIGNAL_LOG_PREFIX}${DATE_FORMAT.format(Date(timestamp))}.log"
            val file = File(logDir, filename)

            val sb = StringBuilder()
            sb.appendLine("=== AIOS Native Crash Log ===")
            sb.appendLine("Time: ${SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date(timestamp))}")
            sb.appendLine("Signal: $signal (${signalName(signal)})")
            sb.appendLine("App Version: ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})")
            sb.appendLine("Device: ${Build.MANUFACTURER} ${Build.MODEL} (Android ${Build.VERSION.RELEASE}, SDK ${Build.VERSION.SDK_INT})")
            sb.appendLine()
            sb.appendLine("This was a native crash (SIGSEGV/SIGABRT/etc).")
            sb.appendLine("Check logcat for detailed stack trace.")
            sb.appendLine()
            sb.appendLine("To reproduce: adb logcat | grep AIOS-Native")

            file.writeText(sb.toString())
            trimOldLogs(logDir)
            Log.i(TAG, "Signal crash log written: $filename")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write signal crash log", e)
        }
    }

    private fun signalName(sig: Int): String = when (sig) {
        6 -> "SIGABRT"
        7 -> "SIGBUS"
        8 -> "SIGFPE"
        9 -> "SIGKILL"
        11 -> "SIGSEGV"
        13 -> "SIGPIPE"
        15 -> "SIGTERM"
        else -> "SIG$sig"
    }

    fun getCrashLogs(context: Context): List<CrashLog> {
        val logDir = getLogDir(context)
        if (!logDir.exists()) return emptyList()

        return logDir.listFiles()
            ?.filter { it.isFile && it.name.endsWith(".log") }
            ?.map { file ->
                val lines = file.readLines()
                val exceptionLine = lines
                    .dropWhile { !it.startsWith("Exception:") && !it.startsWith("Signal:") }
                    .firstOrNull()
                    ?: "Unknown"
                val summary = when {
                    exceptionLine.startsWith("Exception:") -> exceptionLine.removePrefix("Exception: ").trim()
                    exceptionLine.startsWith("Signal:") -> exceptionLine.removePrefix("Signal: ").trim()
                    else -> exceptionLine
                }
                val isNative = file.name.startsWith(SIGNAL_LOG_PREFIX)
                CrashLog(
                    filename = file.name,
                    timestamp = file.lastModified(),
                    summary = if (isNative) "[Native] $summary" else summary,
                )
            }
            ?.sortedByDescending { it.timestamp }
            ?: emptyList()
    }

    fun clearLogs(context: Context) {
        val logDir = getLogDir(context)
        if (!logDir.exists()) return
        logDir.listFiles()?.forEach { it.delete() }
    }

    fun getLogContent(context: Context, filename: String): String? {
        val file = File(getLogDir(context), filename)
        return if (file.exists()) file.readText() else null
    }

    private fun getLogDir(context: Context): File {
        return File(context.filesDir, LOG_DIR)
    }

    private fun trimOldLogs(logDir: File) {
        val files = logDir.listFiles()
            ?.filter { it.isFile && it.name.endsWith(".log") }
            ?.sortedByDescending { it.lastModified() }
            ?: return

        if (files.size > MAX_LOG_FILES) {
            files.drop(MAX_LOG_FILES).forEach { it.delete() }
        }
    }
}

data class CrashLog(
    val filename: String,
    val timestamp: Long,
    val summary: String,
)
