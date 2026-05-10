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
      await _overlayService.updateResult('이전 요청을 처리 중입니다. 잠시 후 다시 시도해주세요.');
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
        await _overlayService.updateResult('요청을 처리하지 못했습니다.');
      }
    } on Object catch (e) {
      print('[$_tag] ERROR: overlay agent execution failed - $e');
      await _overlayService.updateResult('오류가 발생했습니다: $e');
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
