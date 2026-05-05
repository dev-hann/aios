import 'dart:developer' as developer;

import 'package:aios/domain/agent/tool_context.dart';
import 'package:flutter/services.dart';

class ToolContextImpl implements ToolContext {
  static const _channel = MethodChannel('com.agent.aios/tools');

  static const _tag = 'AIOS-ToolContext';

  @override
  Future<String?> invokeMethod(String method, [dynamic arguments]) async {
    try {
      final result = await _channel.invokeMethod<String>(
        method,
        arguments,
      );
      return result;
    } on PlatformException catch (e) {
      developer.log(
        'MethodChannel error: $method',
        name: _tag,
        error: e,
        level: 1000,
      );
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
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> isNotificationListenerEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isNotificationListenerEnabled',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
