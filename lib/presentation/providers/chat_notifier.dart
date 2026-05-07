import 'dart:async';

import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/presentation/providers/chat_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(
    this._llmRepository,
    this._conversationRepository,
    this._agent,
  ) : super(const ChatState()) {
    _listenToStateChanges();
  }

  final LlmRepository _llmRepository;
  final ConversationRepository _conversationRepository;
  final AgentStrategy _agent;
  StreamSubscription<ServiceState>? _stateSub;

  static const _tag = 'AIOS-ChatNotifier';

  void _listenToStateChanges() {
    _stateSub = _llmRepository.state.listen((serviceState) {
      if (!mounted) return;
      state = state.copyWith(serviceState: serviceState);
    });
  }

  Future<void> sendMessage(
    String text, {
    double? temperature,
    int? maxTokens,
    int? topK,
    double? topP,
    double? repeatPenalty,
    int? agentMaxIterations,
  }) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: text.trim(),
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isGenerating: true,
      currentResponse: '',
      errorMessage: null,
      agentSteps: [],
      isConfirming: false,
    );

    await _conversationRepository.appendMessage(userMessage);

    try {
      final result = await _agent.execute(
        text.trim(),
        maxIterations: agentMaxIterations ?? 8,
        maxTokens: maxTokens ?? 512,
        onStep: _handleStep,
      );

      if (!mounted) return;

      _agent.clearHistory();

      final answerStep = result.steps.where(
        (s) => s.type == 'answer',
      );
      if (answerStep.isNotEmpty) {
        final assistantMessage = ChatMessage(
          id: 'assistant_${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          content: answerStep.last.content,
          createdAt: DateTime.now(),
        );
        state = state.copyWith(
          messages: [...state.messages, assistantMessage],
        );
        await _conversationRepository.appendMessage(assistantMessage);
      }

      state = state.copyWith(
        isGenerating: false,
        agentSteps: [],
        isConfirming: false,
      );
    } on Object catch (e) {
      print('[$_tag] ERROR: sendMessage failed - $e');
      if (!mounted) return;
      state = state.copyWith(
        isGenerating: false,
        errorMessage: e.toString(),
      );
    }
  }

  void _handleStep(AgentStep step) {
    if (!mounted) return;

    state = state.copyWith(
      agentSteps: [...state.agentSteps, step],
      isConfirming:
          step.type == 'confirmation_required' ? true : state.isConfirming,
    );
  }

  void resolveConfirmation(bool approved) {
    _agent.resolveConfirmation(approved);
    state = state.copyWith(isConfirming: false);
  }

  Future<void> stopGeneration() async {
    _agent.cancel();
    await _llmRepository.stopGeneration();

    if (!mounted) return;

    final lastStep = state.agentSteps
        .where((s) => s.type == 'answer')
        .lastOrNull;
    if (lastStep != null) {
      final assistantMessage = ChatMessage(
        id: 'assistant_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: lastStep.content,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
      );
    }

    state = state.copyWith(
      isGenerating: false,
      isConfirming: false,
      agentSteps: [],
    );
  }

  Future<void> loadConversation() async {
    try {
      final messages = await _conversationRepository.load();
      if (!mounted) return;
      if (messages.isNotEmpty) {
        state = state.copyWith(messages: messages);
        print('[$_tag] Loaded ${messages.length} messages');
      }
    } on Object catch (e) {
      print('[$_tag] ERROR: loadConversation failed - $e');
    }
  }

  Future<void> loadModel(String path, {int? contextSize}) async {
    await _llmRepository.loadModel(path, contextSize: contextSize);
  }

  Future<void> clearChat() async {
    _agent.clearHistory();
    await _conversationRepository.clear();
    state = const ChatState();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }
}
