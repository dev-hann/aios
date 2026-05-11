package gyo.plugins.bridge

import android.content.Context
import gyo.plugins.app_launcher.AppLauncherBridge
import gyo.plugins.bridge.BridgeRegistry
import gyo.plugins.contact_search.ContactSearchBridge
import gyo.plugins.device_info.DeviceInfoBridge
import gyo.plugins.notification_reader.NotificationReaderBridge
import gyo.plugins.phone_caller.PhoneCallerBridge
import gyo.plugins.screen_action.ScreenActionBridge
import gyo.plugins.screen_find.ScreenFindBridge
import gyo.plugins.screen_reader.ScreenReaderBridge
import gyo.plugins.sms_sender.SmsSenderBridge

object PluginRegistry {
    fun registerAll(context: Context) {
        BridgeRegistry.register("app_launcher", AppLauncherBridge(context))
        BridgeRegistry.register("contact_search", ContactSearchBridge(context))
        BridgeRegistry.register("device_info", DeviceInfoBridge(context))
        BridgeRegistry.register("notification_reader", NotificationReaderBridge(context))
        BridgeRegistry.register("phone_caller", PhoneCallerBridge(context))
        BridgeRegistry.register("screen_action", ScreenActionBridge(context))
        BridgeRegistry.register("screen_find", ScreenFindBridge(context))
        BridgeRegistry.register("screen_reader", ScreenReaderBridge(context))
        BridgeRegistry.register("sms_sender", SmsSenderBridge(context))
    }
}
