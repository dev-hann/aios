import 'package:flutter/services.dart';

typedef OverlayMessageHandler = void Function(String message);

class OverlayService {
  static const _channel = MethodChannel('com.agent.aios/overlay');

  OverlayMessageHandler? onUserMessage;

  OverlayService() {
    try {
      _channel.setMethodCallHandler(_handleMethodCall);
    } on Object catch (e) {
      print('[AIOS-Overlay] WARN: setMethodCallHandler failed - $e');
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onUserMessage':
        final text = call.arguments as String? ?? '';
        if (text.isNotEmpty) {
          onUserMessage?.call(text);
        }
    }
  }

  Future<bool> startOverlay() => _invoke('startOverlay');

  Future<bool> stopOverlay() => _invoke('stopOverlay');

  Future<bool> updateResult(String text) => _invoke('updateResult', text);

  Future<bool> showStatus(String text) => _invoke('showStatus', text);

  Future<bool> hideStatus() => _invoke('hideStatus');

  Future<bool> isOverlayPermissionGranted() =>
      _invoke('isOverlayPermissionGranted');

  Future<bool> requestOverlayPermission() =>
      _invoke('requestOverlayPermission');

  Future<bool> _invoke(String method, [dynamic arguments]) async {
    try {
      return await _channel.invokeMethod<bool>(method, arguments) ?? false;
    } on Object catch (e) {
      print('[AIOS-Overlay] ERROR: $method failed - $e');
      return false;
    }
  }

  void dispose() {
    onUserMessage = null;
  }
}
