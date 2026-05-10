import 'dart:async';

import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/data/services/overlay_service.dart';
import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/presentation/providers/overlay_assistant_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockAgentStrategy implements AgentStrategy {
  AgentResult? resultToReturn;
  String? lastPrompt;
  bool shouldThrow = false;
  Completer<void>? holdCompleter;

  @override
  Future<AgentResult> execute(
    String prompt, {
    int maxIterations = 8,
    int maxTokens = 512,
    void Function(AgentStep)? onStep,
  }) async {
    lastPrompt = prompt;

    if (shouldThrow) throw Exception('Agent failed');

    if (resultToReturn != null) {
      for (final step in resultToReturn!.steps) {
        onStep?.call(step);
      }
    }

    if (holdCompleter != null) {
      await holdCompleter!.future;
    }

    return resultToReturn ??
        const AgentResult(
          steps: [AgentStep('answer', 'Default')],
          success: true,
        );
  }

  @override
  void cancel() {}

  @override
  void resolveConfirmation({required bool approved}) {}

  @override
  void resolvePermission({required bool granted}) {}

  @override
  void setPermissionChecker(
    Future<bool> Function(String permissionKey)? checker,
  ) {}

  @override
  String getToolManifest() => '';

  @override
  List<({String role, String content})> getConversationHistory() => [];

  @override
  void clearHistory() {}

  @override
  Future<void> warmup() async {}

  @override
  void setConversationContext(ConversationContext? context) {}

  @override
  void setToolPreferenceTracker(ToolPreferenceTracker? tracker) {}
}

class _SpyOverlayService extends OverlayService {
  _SpyOverlayService() : super();
  final List<String> updatedResults = [];
  OverlayMessageHandler? capturedHandler;

  @override
  set onUserMessage(OverlayMessageHandler? handler) {
    capturedHandler = handler;
    super.onUserMessage = handler;
  }

  @override
  Future<bool> startOverlay() async => true;

  @override
  Future<bool> stopOverlay() async => true;

  @override
  Future<bool> updateResult(String text) async {
    updatedResults.add(text);
    return true;
  }

  @override
  Future<bool> showStatus(String text) async => true;

  @override
  Future<bool> hideStatus() async => true;

  @override
  Future<bool> isOverlayPermissionGranted() async => true;

  @override
  Future<bool> requestOverlayPermission() async => true;
}

const _serviceChannel = MethodChannel('com.agent.aios/service');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_serviceChannel, (call) async {
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_serviceChannel, null);
  });

  group('OverlayAssistantNotifier', () {
    late _MockAgentStrategy agent;
    late _SpyOverlayService overlayService;
    OverlayAssistantNotifier? notifier;

    setUp(() {
      agent = _MockAgentStrategy();
      overlayService = _SpyOverlayService();
      notifier = OverlayAssistantNotifier(overlayService, agent);
    });

    tearDown(() {
      notifier?.dispose();
    });

    test('initial_state_isFalse', () {
      expect(notifier!.state, isFalse);
    });

    test('onUserMessage_calledOnConstruction', () {
      expect(overlayService.capturedHandler, isNotNull);
    });

    test('checkOverlayPermission_returnsTrue', () async {
      final result = await notifier!.checkOverlayPermission();
      expect(result, isTrue);
    });

    test('requestOverlayPermission_returnsTrue', () async {
      final result = await notifier!.requestOverlayPermission();
      expect(result, isTrue);
    });

    test('stopBackgroundMode_setsStateFalse', () async {
      await notifier!.stopBackgroundMode();
      expect(notifier!.state, isFalse);
    });

    test('handleMessage_sendsPromptToAgent', () async {
      agent.resultToReturn = const AgentResult(
        steps: [AgentStep('answer', 'Hello!')],
        success: true,
      );

      overlayService.capturedHandler!('test message');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(agent.lastPrompt, 'test message');
    });

    test('handleMessage_updatesResultWithAnswer', () async {
      agent.resultToReturn = const AgentResult(
        steps: [AgentStep('answer', 'The answer')],
        success: true,
      );

      overlayService.capturedHandler!('what is 2+2');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(overlayService.updatedResults, contains('The answer'));
    });

    test('handleMessage_onStepAnswer_updatesResultImmediately', () async {
      agent.resultToReturn = const AgentResult(
        steps: [
          AgentStep('action', 'calc', toolName: 'calculator'),
          AgentStep('answer', 'Step answer'),
        ],
        success: true,
      );

      overlayService.capturedHandler!('calc');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        overlayService.updatedResults.any((r) => r == 'Step answer'),
        isTrue,
      );
    });

    test('handleMessage_showsError_onException', () async {
      agent.shouldThrow = true;

      overlayService.capturedHandler!('test');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        overlayService.updatedResults.any(
          (r) => r.contains(Strings.state.error),
        ),
        isTrue,
      );
    });

    test('handleMessage_noAnswer_showsFallbackMessage', () async {
      agent.resultToReturn = const AgentResult(
        steps: [AgentStep('thought', 'thinking')],
        success: false,
      );

      overlayService.capturedHandler!('test');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        overlayService.updatedResults,
        contains(Strings.overlay.failedToProcess),
      );
    });

    test('handleMessage_preventsConcurrentProcessing', () async {
      final completer = Completer<void>();
      agent
        ..holdCompleter = completer
        ..resultToReturn = const AgentResult(
          steps: [AgentStep('answer', 'First')],
          success: true,
        );

      overlayService.capturedHandler!('first');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      overlayService.capturedHandler!('second');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        overlayService.updatedResults,
        contains(Strings.overlay.processingPrevious),
      );

      completer.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });
}
