import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/data/services/foreground_service.dart';
import 'package:aios/data/services/overlay_service.dart';
import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OverlayAssistantNotifier extends StateNotifier<bool> {
  OverlayAssistantNotifier(this._overlayService, this._agent) : super(false) {
    _overlayService.onUserMessage = _handleMessage;
  }
  static const _tag = 'AIOS-OverlayAssistant';

  final OverlayService _overlayService;
  final AgentStrategy _agent;
  bool _isProcessing = false;

  Future<bool> startBackgroundMode() async {
    final fgStarted = await ForegroundService.start();
    if (!fgStarted) {
      print('[$_tag] ERROR: Failed to start foreground service');
      return false;
    }

    final overlayStarted = await _overlayService.startOverlay();
    if (!overlayStarted) {
      print('[$_tag] WARN: Overlay not started (permission may be missing)');
    }

    state = true;
    print('[$_tag] Background mode started');
    return true;
  }

  Future<void> stopBackgroundMode() async {
    await _overlayService.stopOverlay();
    await ForegroundService.stop();
    state = false;
    print('[$_tag] Background mode stopped');
  }

  Future<void> _handleMessage(String text) async {
    if (_isProcessing) {
      await _overlayService.updateResult(Strings.overlay.processingPrevious);
      return;
    }

    _isProcessing = true;
    print('[$_tag] Processing overlay message: "$text"');

    try {
      final result = await _agent.execute(
        text,
        onStep: (step) {
          if (step.type == 'answer') {
            _overlayService.updateResult(step.content);
          }
        },
      );

      final answerStep = result.steps
          .where((s) => s.type == 'answer')
          .lastOrNull;
      if (answerStep != null) {
        await _overlayService.updateResult(answerStep.content);
      } else {
        await _overlayService.updateResult(Strings.overlay.failedToProcess);
      }
    } on Object catch (e) {
      print('[$_tag] ERROR: overlay agent execution failed - $e');
      await _overlayService.updateResult(Strings.overlay.errorOccurred('$e'));
    } finally {
      _isProcessing = false;
    }
  }

  Future<bool> checkOverlayPermission() async {
    return _overlayService.isOverlayPermissionGranted();
  }

  Future<bool> requestOverlayPermission() async {
    return _overlayService.requestOverlayPermission();
  }

  @override
  void dispose() {
    _overlayService.dispose();
    super.dispose();
  }
}
