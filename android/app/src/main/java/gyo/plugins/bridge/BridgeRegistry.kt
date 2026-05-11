package gyo.plugins.bridge

import android.util.Log

object BridgeRegistry {
    private val handlers = mutableMapOf<String, BridgeHandler>()

    fun initialize() {
        handlers.clear()
    }

    fun register(bridgeName: String, handler: BridgeHandler) {
        handlers[bridgeName] = handler
        Log.d("AIOS-Bridge", "Registered bridge: $bridgeName")
    }

    fun unregister(bridgeName: String) {
        handlers.remove(bridgeName)
        Log.d("AIOS-Bridge", "Unregistered bridge: $bridgeName")
    }

    fun get(bridgeName: String): BridgeHandler? {
        return handlers[bridgeName]
    }
}
