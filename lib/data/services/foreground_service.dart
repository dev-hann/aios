import 'package:flutter/services.dart';

class ForegroundService {
  static const _channel = MethodChannel('com.agent.aios/service');

  static Future<bool> start() async {
    try {
      return await _channel.invokeMethod<bool>('startForegroundService') ??
          false;
    } on PlatformException catch (e) {
      print('[AIOS-FgService] ERROR: start failed - $e');
      return false;
    }
  }

  static Future<bool> stop() async {
    try {
      return await _channel.invokeMethod<bool>('stopForegroundService') ??
          false;
    } on PlatformException catch (e) {
      print('[AIOS-FgService] ERROR: stop failed - $e');
      return false;
    }
  }

  static Future<bool> isRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isForegroundServiceRunning') ??
          false;
    } on PlatformException catch (e) {
      print('[AIOS-FgService] ERROR: isRunning check failed - $e');
      return false;
    }
  }
}
