import 'package:aios/data/datasources/local/database.dart' hide Conversation;
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/conversation.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:drift/drift.dart';

class ConversationRepositoryImpl implements ConversationRepository {
  ConversationRepositoryImpl(this._db);

  final AppDatabase _db;
  String _activeConversationId = 'default';

  static const _tag = 'AIOS-ConversationRepo';

  String get activeConversationId => _activeConversationId;

  @override
  Future<void> save(List<ChatMessage> messages) async {
    await _db.deleteMessages(_activeConversationId);
    for (final message in messages) {
      await _db.insertMessage(_toCompanion(message));
    }
  }

  @override
  Future<List<ChatMessage>> load() async {
    await _ensureConversation(_activeConversationId);
    final rows = await _db.getMessages(_activeConversationId);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> clear() async {
    await _db.deleteMessages(_activeConversationId);
    await _db.deleteConversation(_activeConversationId);
  }

  @override
  Future<void> appendMessage(ChatMessage message) async {
    await _ensureConversation(_activeConversationId);
    await _db.insertMessage(_toCompanion(message));
  }

  @override
  Future<Conversation> createConversation({String? title}) async {
    final id = 'conv_${DateTime.now().millisecondsSinceEpoch}';
    await _db.insertConversation(
      ConversationsCompanion.insert(
        id: id,
        title: Value(title ?? '새 대화'),
      ),
    );
    _activeConversationId = id;
    return Conversation(
      id: id,
      title: title ?? '새 대화',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Conversation>> getAllConversations() async {
    final rows = await _db.getAllConversations();
    return rows
        .map((r) => Conversation(
              id: r.id,
              title: r.title,
              createdAt: r.createdAt,
              updatedAt: r.updatedAt,
            ))
        .toList();
  }

  @override
  Future<List<ChatMessage>> loadConversation(String id) async {
    _activeConversationId = id;
    await _ensureConversation(id);
    final rows = await _db.getMessages(id);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> deleteConversation(String id) async {
    await _db.deleteMessages(id);
    await _db.deleteConversation(id);
    if (_activeConversationId == id) {
      final remaining = await getAllConversations();
      if (remaining.isNotEmpty) {
        _activeConversationId = remaining.first.id;
      } else {
        _activeConversationId = 'default';
      }
    }
  }

  @override
  Future<void> updateConversationTitle(String id, String title) async {
    await _db.updateConversation(id, title: title);
  }

  @override
  Stream<List<Conversation>> watchAllConversations() {
    return _db.watchAllConversations().map((rows) => rows
        .map((r) => Conversation(
              id: r.id,
              title: r.title,
              createdAt: r.createdAt,
              updatedAt: r.updatedAt,
            ))
        .toList());
  }

  void setActiveConversationId(String id) {
    _activeConversationId = id;
  }

  Future<void> _ensureConversation(String id) async {
    final conversations = await _db.getAllConversations();
    final exists = conversations.any((c) => c.id == id);
    if (!exists) {
      await _db.insertConversation(
        ConversationsCompanion.insert(id: id),
      );
    }
  }

  MessagesCompanion _toCompanion(ChatMessage msg) {
    return MessagesCompanion.insert(
      id: msg.id,
      conversationId: _activeConversationId,
      role: msg.role,
      content: msg.content,
      createdAt: Value(msg.createdAt),
      toolName: Value(msg.toolName),
      toolArgs: Value(msg.toolArgs),
      toolResult: Value(msg.toolResult),
    );
  }

  ChatMessage _fromRow(Message row) {
    return ChatMessage(
      id: row.id,
      role: row.role,
      content: row.content,
      createdAt: row.createdAt,
      toolName: row.toolName,
      toolArgs: row.toolArgs,
      toolResult: row.toolResult,
    );
  }
}
