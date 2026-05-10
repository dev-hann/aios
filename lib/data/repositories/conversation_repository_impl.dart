import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/data/datasources/local/database.dart' as db;
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/conversation.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:drift/drift.dart';

class ConversationRepositoryImpl implements ConversationRepository {
  ConversationRepositoryImpl(this._db);

  final db.AppDatabase _db;
  String _activeConversationId = 'default';

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
      db.ConversationsCompanion.insert(
        id: id,
        title: Value(title ?? Strings.newConversationTitle),
      ),
    );
    _activeConversationId = id;
    return Conversation(
      id: id,
      title: title ?? Strings.newConversationTitle,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Conversation>> getAllConversations() async {
    final rows = await _db.getAllConversations();
    return rows.map(_rowToConversation).toList();
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
    return _db.watchAllConversations().map(
      (rows) => rows.map(_rowToConversation).toList(),
    );
  }

  @override
  void setActiveConversationId(String id) {
    _activeConversationId = id;
  }

  Conversation _rowToConversation(db.Conversation row) {
    return Conversation(
      id: row.id,
      title: row.title,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<void> _ensureConversation(String id) async {
    final conversations = await _db.getAllConversations();
    final exists = conversations.any((c) => c.id == id);
    if (!exists) {
      await _db.insertConversation(db.ConversationsCompanion.insert(id: id));
    }
  }

  db.MessagesCompanion _toCompanion(ChatMessage msg) {
    return db.MessagesCompanion.insert(
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

  ChatMessage _fromRow(db.Message row) {
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
