import 'package:aios/domain/agent/tool_context.dart';
import 'package:flutter/services.dart';

class ToolContextImpl implements ToolContext {
  static const _channel = MethodChannel('com.agent.aios/tools');

  static const _tag = 'AIOS-ToolContext';

  @override
  Future<String?> invokeMethod(String method, [dynamic arguments]) async {
    try {
      final result = await _channel.invokeMethod<String>(method, arguments);
      return result;
    } on PlatformException catch (e) {
      print('[$_tag] ERROR: MethodChannel error: $method - $e');
      return 'Error: ${e.message}';
    }
  }

  @override
  Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isAccessibilityEnabled',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('[$_tag] ERROR: isAccessibilityEnabled error: $e');
      return false;
    }
  }

  @override
  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod<void>('openAccessibilitySettings');
    } on PlatformException catch (e) {
      print('[$_tag] ERROR: openAccessibilitySettings error: $e');
    }
  }

  @override
  Future<bool> isNotificationListenerEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isNotificationListenerEnabled',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('[$_tag] ERROR: isNotificationListenerEnabled error: $e');
      return false;
    }
  }
}
