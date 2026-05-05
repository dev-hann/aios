abstract class ToolContext {
  Future<String?> invokeMethod(String method, [dynamic arguments]);
  Future<bool> isAccessibilityEnabled();
  Future<bool> isNotificationListenerEnabled();
}
