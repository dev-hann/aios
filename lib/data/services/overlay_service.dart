import 'package:flutter/services.dart';

typedef OverlayMessageHandler = void Function(String message);

class OverlayService {
  static const _channel = MethodChannel('com.agent.aios/overlay');

  OverlayMessageHandler? _onUserMessage;

  OverlayService() {
    try {
      _channel.setMethodCallHandler(_handleMethodCall);
    } on Object {
      // Platform channel not available in test environment
    }
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
    } on Object catch (e) {
      print('[AIOS-Overlay] ERROR: startOverlay failed - $e');
      return false;
    }
  }

  Future<bool> stopOverlay() async {
    try {
      return await _channel.invokeMethod<bool>('stopOverlay') ?? false;
    } on Object catch (e) {
      print('[AIOS-Overlay] ERROR: stopOverlay failed - $e');
      return false;
    }
  }

  Future<bool> updateResult(String text) async {
    try {
      return await _channel.invokeMethod<bool>('updateResult', text) ?? false;
    } on Object catch (e) {
      print('[AIOS-Overlay] ERROR: updateResult failed - $e');
      return false;
    }
  }

  Future<bool> showStatus(String text) async {
    try {
      return await _channel.invokeMethod<bool>('showStatus', text) ?? false;
    } on Object catch (e) {
      print('[AIOS-Overlay] ERROR: showStatus failed - $e');
      return false;
    }
  }

  Future<bool> hideStatus() async {
    try {
      return await _channel.invokeMethod<bool>('hideStatus') ?? false;
    } on Object catch (e) {
      print('[AIOS-Overlay] ERROR: hideStatus failed - $e');
      return false;
    }
  }

  Future<bool> isOverlayPermissionGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isOverlayPermissionGranted') ??
          false;
    } on Object catch (e) {
      print('[AIOS-Overlay] ERROR: permission check failed - $e');
      return false;
    }
  }

  Future<bool> requestOverlayPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestOverlayPermission') ??
          false;
    } on Object catch (e) {
      print('[AIOS-Overlay] ERROR: request permission failed - $e');
      return false;
    }
  }

  void dispose() {
    _onUserMessage = null;
  }
}
