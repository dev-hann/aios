import 'package:aios/data/datasources/local/database.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:drift/drift.dart';

class ConversationRepositoryImpl implements ConversationRepository {
  ConversationRepositoryImpl(this._db);

  static const String _defaultConversationId = 'default';
  final AppDatabase _db;

  @override
  Future<void> save(List<ChatMessage> messages) async {
    await _db.deleteMessages(_defaultConversationId);
    for (final message in messages) {
      await _db.insertMessage(_toCompanion(message));
    }
  }

  @override
  Future<List<ChatMessage>> load() async {
    await _ensureConversation();
    final rows = await _db.getMessages(_defaultConversationId);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> clear() async {
    await _db.deleteMessages(_defaultConversationId);
    await _db.deleteConversation(_defaultConversationId);
  }

  @override
  Future<void> appendMessage(ChatMessage message) async {
    await _ensureConversation();
    await _db.insertMessage(_toCompanion(message));
  }

  Future<void> _ensureConversation() async {
    final conversations = await _db.getAllConversations();
    final exists = conversations.any((c) => c.id == _defaultConversationId);
    if (!exists) {
      await _db.insertConversation(
        ConversationsCompanion.insert(id: _defaultConversationId),
      );
    }
  }

  MessagesCompanion _toCompanion(ChatMessage msg) {
    return MessagesCompanion.insert(
      id: msg.id,
      conversationId: _defaultConversationId,
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
