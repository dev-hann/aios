import 'dart:async';

import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/conversation.dart';
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

  bool _warmedUp = false;

  void _listenToStateChanges() {
    _stateSub = _llmRepository.state.listen((serviceState) {
      if (!mounted) return;
      state = state.copyWith(serviceState: serviceState);

      if (serviceState == ServiceState.ready) {
        if (!_warmedUp) {
          _warmedUp = true;
          _agent.warmup();
        }
        if (state.currentConversationId == null) {
          initializeSession();
        }
      }
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
      currentResponse: '',
      errorMessage: null,
      agentSteps: [const AgentStep('thinking_start', '')],
      isConfirming: false,
    );

    _conversationRepository
        .appendMessage(userMessage)
        .catchError((e) => print('[$_tag] WARN: appendMessage fire-forget - $e'));

    if (state.currentConversationTitle == '새 대화' &&
        state.messages.where((m) => m.role == 'user').length == 1) {
      final title = text.trim().length > 20
          ? '${text.trim().substring(0, 20)}...'
          : text.trim();
      final convId = state.currentConversationId;
      if (convId != null) {
        state = state.copyWith(currentConversationTitle: title);
        _conversationRepository
            .updateConversationTitle(convId, title)
            .catchError(
                (e) => print('[$_tag] WARN: updateTitle fire-forget - $e'));
      }
    }

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
        agentSteps: [],
        isConfirming: false,
      );
    } on Object catch (e) {
      print('[$_tag] ERROR: sendMessage failed - $e');
      if (!mounted) return;
      state = state.copyWith(
        agentSteps: [],
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

  Future<void> initializeSession() async {
    try {
      final conversations = await _conversationRepository.getAllConversations();
      if (conversations.isEmpty) {
        final conv = await _conversationRepository.createConversation();
        if (!mounted) return;
        state = state.copyWith(
          currentConversationId: conv.id,
          currentConversationTitle: conv.title,
        );
      } else {
        final active = conversations.first;
        final messages =
            await _conversationRepository.loadConversation(active.id);
        if (!mounted) return;
        state = state.copyWith(
          currentConversationId: active.id,
          currentConversationTitle: active.title,
          messages: messages,
        );
      }
      print('[$_tag] Session initialized: ${state.currentConversationId}');
    } on Object catch (e) {
      print('[$_tag] ERROR: initializeSession failed - $e');
      await loadConversation();
    }
  }

  Future<void> createNewChat() async {
    try {
      final conv = await _conversationRepository.createConversation();
      _agent.clearHistory();
      if (!mounted) return;
      state = state.copyWith(
        messages: [],
        currentResponse: '',
        errorMessage: null,
        agentSteps: [],
        isConfirming: false,
        currentConversationId: conv.id,
        currentConversationTitle: conv.title,
      );
      print('[$_tag] Created new conversation: ${conv.id}');
    } on Object catch (e) {
      print('[$_tag] ERROR: createNewChat failed - $e');
    }
  }

  Future<void> switchConversation(String id, String title) async {
    try {
      _conversationRepository.setActiveConversationId(id);
      _agent.clearHistory();
      final messages = await _conversationRepository.loadConversation(id);
      if (!mounted) return;
      state = state.copyWith(
        messages: messages,
        currentResponse: '',
        errorMessage: null,
        agentSteps: [],
        isConfirming: false,
        currentConversationId: id,
        currentConversationTitle: title,
      );
      print('[$_tag] Switched to conversation: $id');
    } on Object catch (e) {
      print('[$_tag] ERROR: switchConversation failed - $e');
    }
  }

  Future<void> deleteConversation(String id) async {
    try {
      await _conversationRepository.deleteConversation(id);
      if (!mounted) return;
      if (state.currentConversationId == id) {
        final remaining =
            await _conversationRepository.getAllConversations();
        if (remaining.isNotEmpty) {
          final first = remaining.first;
          await switchConversation(first.id, first.title);
        } else {
          final conv = await _conversationRepository.createConversation();
          _agent.clearHistory();
          state = state.copyWith(
            messages: [],
            currentResponse: '',
            errorMessage: null,
            agentSteps: [],
            isConfirming: false,
            currentConversationId: conv.id,
            currentConversationTitle: conv.title,
          );
        }
      }
      print('[$_tag] Deleted conversation: $id');
    } on Object catch (e) {
      print('[$_tag] ERROR: deleteConversation failed - $e');
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
