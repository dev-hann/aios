import 'dart:async';

import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/conversation.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';

class MockConversationRepository implements ConversationRepository {
  final List<ChatMessage> messages = [];
  final List<Conversation> conversations = [];
  StreamController<List<Conversation>>? _liveController;
  ChatMessage? lastAppendedMessage;
  String? activeConversationId;
  int _convCounter = 0;

  bool get _isLive => _liveController != null;

  StreamController<List<Conversation>> get _controller {
    return _liveController ??= StreamController<List<Conversation>>.broadcast(
      onListen: () {
        _liveController!.add(List.of(conversations));
      },
    );
  }

  void enableLiveStream() {
    _liveController ??= StreamController<List<Conversation>>.broadcast(
      onListen: () {
        _liveController!.add(List.of(conversations));
      },
    );
  }

  @override
  Future<void> save(List<ChatMessage> msgs) async {
    messages
      ..clear()
      ..addAll(msgs);
  }

  @override
  Future<List<ChatMessage>> load() async => List.unmodifiable(messages);

  @override
  Future<void> clear() async {
    messages.clear();
  }

  @override
  Future<void> appendMessage(ChatMessage message) async {
    lastAppendedMessage = message;
    messages.add(message);
  }

  @override
  Future<Conversation> createConversation({String? title}) async {
    final conv = Conversation(
      id: 'conv_${_convCounter++}',
      title: title ?? '새 대화',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    conversations.add(conv);
    _notify();
    return conv;
  }

  @override
  Future<List<Conversation>> getAllConversations() async =>
      List.of(conversations);

  @override
  Future<List<ChatMessage>> loadConversation(String id) async =>
      List.unmodifiable(messages);

  @override
  Future<void> deleteConversation(String id) async {
    conversations.removeWhere((c) => c.id == id);
    _notify();
  }

  @override
  Future<void> updateConversationTitle(String id, String title) async {
    final idx = conversations.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      conversations[idx] = conversations[idx].copyWith(title: title);
      _notify();
    }
  }

  @override
  Stream<List<Conversation>> watchAllConversations() {
    if (_isLive) {
      return _controller.stream;
    }
    return Stream.value(List.of(conversations));
  }

  @override
  void setActiveConversationId(String id) {
    activeConversationId = id;
  }

  void _notify() {
    _liveController?.add(List.of(conversations));
  }

  void emitConversations(List<Conversation> convs) {
    conversations.clear();
    conversations.addAll(convs);
    _notify();
  }

  void dispose() {
    _liveController?.close();
  }
}
