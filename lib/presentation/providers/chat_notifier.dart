import 'dart:async';
import 'dart:developer' as developer;

import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/presentation/providers/chat_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._llmRepository, this._conversationRepository)
      : super(const ChatState()) {
    _listenToStateChanges();
  }

  final LlmRepository _llmRepository;
  final ConversationRepository _conversationRepository;
  StreamSubscription<ServiceState>? _stateSub;
  StreamSubscription<String>? _tokenSub;

  static const _tag = 'AIOS-ChatNotifier';

  void _listenToStateChanges() {
    _stateSub = _llmRepository.state.listen((serviceState) {
      if (!mounted) return;
      state = state.copyWith(serviceState: serviceState);
    });
  }

  Future<void> sendMessage(String text) async {
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
    );

    _tokenSub = _llmRepository.tokenStream.listen(
      (token) {
        if (!mounted) return;
        state = state.copyWith(
          currentResponse: state.currentResponse + token,
        );
      },
      onError: (Object e) {
        developer.log(
          'Token stream error',
          name: _tag,
          error: e,
          level: 1000,
        );
      },
    );

    try {
      await _llmRepository.sendMessage(
        state.messages,
        userMessage: text.trim(),
      );

      await _tokenSub?.cancel();
      _tokenSub = null;

      if (!mounted) return;

      await _finalizeResponse();
    } on Object catch (e) {
      await _tokenSub?.cancel();
      _tokenSub = null;
      developer.log(
        'sendMessage failed',
        name: _tag,
        error: e,
        level: 1000,
      );
      if (!mounted) return;
      state = state.copyWith(
        isGenerating: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _finalizeResponse() async {
    final responseText = state.currentResponse;
    if (responseText.isNotEmpty) {
      final assistantMessage = ChatMessage(
        id: 'assistant_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: responseText,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        currentResponse: '',
      );
      await _conversationRepository.appendMessage(assistantMessage);
    }
    state = state.copyWith(isGenerating: false);
  }

  Future<void> stopGeneration() async {
    await _llmRepository.stopGeneration();
    await _tokenSub?.cancel();
    _tokenSub = null;

    if (!mounted) return;

    await _finalizeResponse();
  }

  Future<void> loadModel(String path, {int? contextSize}) async {
    await _llmRepository.loadModel(path, contextSize: contextSize);
  }

  void clearChat() {
    state = const ChatState();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _tokenSub?.cancel();
    super.dispose();
  }
}
