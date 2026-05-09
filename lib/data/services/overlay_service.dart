import 'package:flutter/services.dart';

typedef OverlayMessageHandler = void Function(String message);

class OverlayService {
  static const _channel = MethodChannel('com.agent.aios/overlay');

  OverlayMessageHandler? _onUserMessage;

  OverlayService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onUserMessage':
        final text = call.arguments as String? ?? '';
        if (text.isNotEmpty) {
          _onUserMessage?.call(text);
        }
    }
  }

  void setMessageHandler(OverlayMessageHandler handler) {
    _onUserMessage = handler;
  }

  Future<bool> startOverlay() async {
    try {
      return await _channel.invokeMethod<bool>('startOverlay') ?? false;
    } on PlatformException catch (e) {
      print('[AIOS-Overlay] ERROR: startOverlay failed - $e');
      return false;
    }
  }

  Future<bool> stopOverlay() async {
    try {
      return await _channel.invokeMethod<bool>('stopOverlay') ?? false;
    } on PlatformException catch (e) {
      print('[AIOS-Overlay] ERROR: stopOverlay failed - $e');
      return false;
    }
  }

  Future<bool> updateResult(String text) async {
    try {
      return await _channel.invokeMethod<bool>('updateResult', text) ?? false;
    } on PlatformException catch (e) {
      print('[AIOS-Overlay] ERROR: updateResult failed - $e');
      return false;
    }
  }

  Future<bool> isOverlayPermissionGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isOverlayPermissionGranted') ?? false;
    } on PlatformException catch (e) {
      print('[AIOS-Overlay] ERROR: permission check failed - $e');
      return false;
    }
  }

  Future<bool> requestOverlayPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestOverlayPermission') ?? false;
    } on PlatformException catch (e) {
      print('[AIOS-Overlay] ERROR: request permission failed - $e');
      return false;
    }
  }

  void dispose() {
    _onUserMessage = null;
  }
}
