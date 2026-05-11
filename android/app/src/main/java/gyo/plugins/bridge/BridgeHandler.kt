package gyo.plugins.bridge

import org.json.JSONObject

interface BridgeHandler {
    fun handle(method: String, data: JSONObject): Any?
}
