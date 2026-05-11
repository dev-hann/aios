package gyo.plugins.bridge

import android.content.Context
import gyo.plugins.app_launcher.AppLauncherBridge
import gyo.plugins.bridge.BridgeRegistry

object PluginRegistry {
    fun registerAll(context: Context) {
        BridgeRegistry.register("app_launcher", AppLauncherBridge(context))
    }
}
