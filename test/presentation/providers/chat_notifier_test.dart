import 'dart:async';

import 'package:aios/data/services/overlay_service.dart';
import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/presentation/providers/chat_notifier.dart';
import 'package:aios/presentation/providers/chat_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_conversation_repository.dart';
import '../../helpers/mock_llm_repository.dart';

class _MockAgentStrategy implements AgentStrategy {
  AgentResult? resultToReturn;
  String? lastPrompt;
  int? lastMaxIterations;
  int? lastMaxTokens;
  bool cancelCalled = false;
  bool? lastConfirmationApproved;
  List<AgentStep> capturedSteps = [];
  Duration executeDelay = Duration.zero;
  bool shouldThrow = false;
  Completer<void>? holdCompleter;

  @override
  Future<AgentResult> execute(
    String prompt, {
    int maxIterations = 8,
    int maxTokens = 512,
    void Function(AgentStep)? onStep,
  }) async {
    if (shouldThrow) {
      throw Exception('Agent execution failed');
    }

    lastPrompt = prompt;
    lastMaxIterations = maxIterations;
    lastMaxTokens = maxTokens;

    if (resultToReturn != null) {
      for (final step in resultToReturn!.steps) {
        capturedSteps.add(step);
        onStep?.call(step);
      }
    } else {
      onStep?.call(const AgentStep('answer', 'Default response'));
    }

    if (holdCompleter != null) {
      await holdCompleter!.future;
    }

    if (executeDelay > Duration.zero) {
      await Future<void>.delayed(executeDelay);
    }

    return resultToReturn ??
        const AgentResult(
          steps: [AgentStep('answer', 'Default response')],
          success: true,
        );
  }

  @override
  void cancel() {
    cancelCalled = true;
  }

  @override
  void resolveConfirmation({required bool approved}) {
    lastConfirmationApproved = approved;
  }

  @override
  void resolvePermission({required bool granted}) {}

  @override
  void setPermissionChecker(
    Future<bool> Function(String permissionKey)? checker,
  ) {}

  @override
  String getToolManifest() => '- test: test tool';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatNotifier', () {
    late MockLlmRepository llmRepo;
    late MockConversationRepository conversationRepo;
    late _MockAgentStrategy agent;
    late ChatNotifier notifier;

    setUp(() {
      llmRepo = MockLlmRepository();
      conversationRepo = MockConversationRepository();
      agent = _MockAgentStrategy();
      notifier = ChatNotifier(
        llmRepo,
        conversationRepo,
        agent,
        OverlayService(),
      );
    });

    tearDown(() {
      notifier.dispose();
      llmRepo.dispose();
      conversationRepo.dispose();
    });

    test('initial_state_hasEmptyMessagesAndIdle', () {
      expect(notifier.state.messages, isEmpty);
      expect(notifier.state.isGenerating, isFalse);
      expect(notifier.state.currentResponse, isEmpty);
      expect(notifier.state.serviceState, ServiceState.idle);
      expect(notifier.state.errorMessage, isNull);
    });

    test('sendMessage_addsUserMessage', () async {
      await notifier.sendMessage('Hello');

      expect(notifier.state.messages, isNotEmpty);
      expect(notifier.state.messages.first.role, 'user');
      expect(notifier.state.messages.first.content, 'Hello');
    });

    test('sendMessage_callsAgentExecute', () async {
      await notifier.sendMessage('Hello');

      expect(agent.lastPrompt, 'Hello');
    });

    test('sendMessage_setsIsGeneratingTrue', () async {
      agent.executeDelay = const Duration(milliseconds: 100);
      var wasGenerating = false;

      final future = notifier.sendMessage('Hello');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      wasGenerating = notifier.state.isGenerating;
      await future;

      expect(wasGenerating, isTrue);
    });

    test('sendMessage_addsAssistantMessageFromAnswer', () async {
      agent.resultToReturn = const AgentResult(
        steps: [AgentStep('answer', 'Hi there')],
        success: true,
      );

      await notifier.sendMessage('Hello');

      final assistantMessages = notifier.state.messages
          .where((m) => m.role == 'assistant')
          .toList();
      expect(assistantMessages, isNotEmpty);
      expect(assistantMessages.first.content, 'Hi there');
    });

    test('sendMessage_setsIsGeneratingFalseOnComplete', () async {
      await notifier.sendMessage('Hello');

      expect(notifier.state.isGenerating, isFalse);
    });

    test('sendMessage_setsIsGeneratingFalseOnError', () async {
      agent.resultToReturn = const AgentResult(steps: [], success: false);

      await notifier.sendMessage('Hello');

      expect(notifier.state.isGenerating, isFalse);
    });

    test('sendMessage_passesAgentMaxIterations', () async {
      await notifier.sendMessage(
        'Hello',
        agentMaxIterations: 5,
        maxTokens: 256,
      );

      expect(agent.lastMaxIterations, 5);
      expect(agent.lastMaxTokens, 256);
    });

    test('sendMessage_afterCompletion_clearsAgentSteps', () async {
      agent.resultToReturn = const AgentResult(
        steps: [
          AgentStep('thought', 'Thinking...'),
          AgentStep(
            'action',
            'Using calculator',
            toolName: 'calculator',
            toolArgs: '{"expression": "2+2"}',
          ),
          AgentStep('observation', '4.0000'),
          AgentStep('answer', 'The result is 4'),
        ],
        success: true,
      );

      await notifier.sendMessage('What is 2+2?');

      expect(notifier.state.agentSteps, isEmpty);
    });

    test('stopGeneration_cancelsAgent', () async {
      await notifier.stopGeneration();

      expect(agent.cancelCalled, isTrue);
      expect(notifier.state.isGenerating, isFalse);
    });

    test('clearChat_resetsState', () async {
      agent.resultToReturn = const AgentResult(
        steps: [AgentStep('answer', 'Hi')],
        success: true,
      );
      await notifier.sendMessage('Hello');

      expect(notifier.state.messages, isNotEmpty);

      await notifier.clearChat();

      expect(notifier.state.messages, isEmpty);
      expect(notifier.state.currentResponse, isEmpty);
      expect(notifier.state.isGenerating, isFalse);
    });

    test('resolveConfirmation_delegatesToAgent', () async {
      notifier.resolveConfirmation(approved: true);
      expect(agent.lastConfirmationApproved, isTrue);

      notifier.resolveConfirmation(approved: false);
      expect(agent.lastConfirmationApproved, isFalse);
    });

    test('sendMessage_doesNothingForEmptyText', () async {
      await notifier.sendMessage('');
      await notifier.sendMessage('   ');

      expect(notifier.state.messages, isEmpty);
    });

    test('sendMessage_savesAssistantMessageToConversationRepo', () async {
      agent.resultToReturn = const AgentResult(
        steps: [AgentStep('answer', 'Response')],
        success: true,
      );
      await notifier.sendMessage('Hello');

      expect(conversationRepo.lastAppendedMessage, isNotNull);
      expect(conversationRepo.lastAppendedMessage!.role, 'assistant');
      expect(conversationRepo.lastAppendedMessage!.content, 'Response');
    });

    test(
      'handleStep_confirmationRequired_setsIsConfirmingAndStepTogether',
      () async {
        final states = <ChatState>[];
        notifier.addListener(states.add);

        agent.resultToReturn = const AgentResult(
          steps: [
            AgentStep('thought', 'I need to open YouTube'),
            AgentStep(
              'confirmation_required',
              'High risk: app_launcher',
              toolName: 'app_launcher',
              toolArgs: '{"action": "open_app", "package": "youtube"}',
              riskLevel: 'high',
            ),
          ],
          success: true,
        );

        await notifier.sendMessage('open youtube');

        final confirmState = states.firstWhere(
          (s) =>
              s.isConfirming &&
              s.agentSteps.any((s) => s.type == 'confirmation_required'),
          orElse: () => const ChatState(),
        );

        expect(
          confirmState.isConfirming,
          isTrue,
          reason:
              'isConfirming and agentSteps must be set '
              'in the SAME state update',
        );
        expect(
          confirmState.agentSteps
              .where((s) => s.type == 'confirmation_required')
              .isNotEmpty,
          isTrue,
          reason:
              'confirmation_required step must exist when '
              'isConfirming is true',
        );
      },
    );

    test('handleStep_confirmationRequired_noOrphanIsConfirming', () async {
      var confirmWithoutStepCount = 0;
      var stepWithoutConfirmCount = 0;

      notifier.addListener((state) {
        final hasConfirmStep = state.agentSteps.any(
          (s) => s.type == 'confirmation_required',
        );
        if (state.isConfirming && !hasConfirmStep) {
          confirmWithoutStepCount++;
        }
        if (hasConfirmStep && !state.isConfirming) {
          stepWithoutConfirmCount++;
        }
      });

      agent.resultToReturn = const AgentResult(
        steps: [
          AgentStep(
            'confirmation_required',
            'confirm',
            toolName: 'sms_sender',
            toolArgs: '{"action": "send"}',
            riskLevel: 'critical',
          ),
        ],
        success: true,
      );

      await notifier.sendMessage('send SMS');

      expect(
        confirmWithoutStepCount,
        0,
        reason:
            'isConfirming should never be true '
            'without a confirmation step',
      );
      expect(
        stepWithoutConfirmCount,
        0,
        reason:
            'confirmation step should never exist '
            'without isConfirming being true',
      );
    });

    test('resolveConfirmation_resetsIsConfirming', () async {
      final completer = Completer<void>();
      agent
        ..resultToReturn = const AgentResult(
          steps: [
            AgentStep(
              'confirmation_required',
              'confirm',
              toolName: 'app_launcher',
              toolArgs: '{}',
              riskLevel: 'high',
            ),
          ],
          success: true,
        )
        ..holdCompleter = completer;

      final future = notifier.sendMessage('open youtube');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state.isConfirming, isTrue);

      notifier.resolveConfirmation(approved: true);
      completer.complete();
      await future;

      expect(notifier.state.isConfirming, isFalse);
    });

    test('sendMessage_fullAgentFlow_thoughtActionObservationAnswer', () async {
      final stepTypes = <String>[];
      notifier.addListener((state) {
        for (final step in state.agentSteps) {
          if (!stepTypes.contains(step.type)) {
            stepTypes.add(step.type);
          }
        }
      });

      agent.resultToReturn = const AgentResult(
        steps: [
          AgentStep('thought', 'User wants to calculate'),
          AgentStep(
            'action',
            'calc',
            toolName: 'calculator',
            toolArgs: '{"expression": "2+2"}',
          ),
          AgentStep('observation', '4.0000'),
          AgentStep('answer', 'The result is 4'),
        ],
        success: true,
      );

      await notifier.sendMessage('What is 2+2?');

      expect(stepTypes, containsAll(['thought', 'action', 'observation']));
      final assistantMsgs = notifier.state.messages
          .where((m) => m.role == 'assistant')
          .toList();
      expect(assistantMsgs, hasLength(1));
      expect(assistantMsgs.first.content, 'The result is 4');
    });

    test('sendMessage_agentError_setsErrorMessage', () async {
      agent.resultToReturn = const AgentResult(steps: [], success: false);

      await notifier.sendMessage('Hello');

      expect(notifier.state.isGenerating, isFalse);
    });

    test('sendMessage_throwsException_setsErrorMessage', () async {
      agent.shouldThrow = true;

      await notifier.sendMessage('Hello');

      expect(notifier.state.isGenerating, isFalse);
      expect(notifier.state.errorMessage, isNotNull);
    });

    test('sendMessage_concurrentCalls_bothExecute', () async {
      final completer = Completer<void>();
      agent
        ..holdCompleter = completer
        ..resultToReturn = const AgentResult(
          steps: [AgentStep('answer', 'First')],
          success: true,
        );

      final future1 = notifier.sendMessage('First');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state.isGenerating, isTrue);

      completer.complete();
      await future1;

      expect(notifier.state.isGenerating, isFalse);
    });

    test('sendMessage_preservesMessages_acrossMultipleCalls', () async {
      agent.resultToReturn = const AgentResult(
        steps: [AgentStep('answer', 'R1')],
        success: true,
      );
      await notifier.sendMessage('Q1');

      agent.resultToReturn = const AgentResult(
        steps: [AgentStep('answer', 'R2')],
        success: true,
      );
      await notifier.sendMessage('Q2');

      final messages = notifier.state.messages;
      expect(messages.where((m) => m.role == 'user'), hasLength(2));
      expect(messages.where((m) => m.role == 'assistant'), hasLength(2));
    });

    test('loadConversation_populatesMessages', () async {
      final testMessages = [
        ChatMessage(
          id: '1',
          role: 'user',
          content: 'Hello',
          createdAt: DateTime.now(),
        ),
        ChatMessage(
          id: '2',
          role: 'assistant',
          content: 'Hi',
          createdAt: DateTime.now(),
        ),
      ];
      conversationRepo.messages.addAll(testMessages);

      await notifier.loadConversation();

      expect(notifier.state.messages, hasLength(2));
      expect(notifier.state.messages.first.content, 'Hello');
      expect(notifier.state.messages.last.content, 'Hi');
    });

    test('clearChat_clearsAgentHistory', () async {
      agent.resultToReturn = const AgentResult(
        steps: [AgentStep('answer', 'Hi')],
        success: true,
      );
      await notifier.sendMessage('Hello');

      await notifier.clearChat();

      expect(notifier.state.agentSteps, isEmpty);
    });

    test('sendMessage_withWhitespaceOnly_doesNotSend', () async {
      await notifier.sendMessage('   \t\n  ');

      expect(notifier.state.messages, isEmpty);
      expect(agent.lastPrompt, isNull);
    });

    test('sendMessage_passesAllParams', () async {
      await notifier.sendMessage(
        'Test',
        temperature: 0.5,
        maxTokens: 128,
        topP: 0.8,
        agentMaxIterations: 3,
      );

      expect(agent.lastMaxIterations, 3);
      expect(agent.lastMaxTokens, 128);
    });

    test('state_reflectsServiceState_fromRepository', () async {
      llmRepo.emitState(ServiceState.loadingModel);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state.serviceState, ServiceState.loadingModel);

      llmRepo.emitState(ServiceState.ready);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state.serviceState, ServiceState.ready);
    });
  });
}
