import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/conversation.dart';

abstract class ConversationRepository {
  Future<void> save(List<ChatMessage> messages);
  Future<List<ChatMessage>> load();
  Future<void> clear();
  Future<void> appendMessage(ChatMessage message);

  Future<Conversation> createConversation({String? title});
  Future<List<Conversation>> getAllConversations();
  Future<List<ChatMessage>> loadConversation(String id);
  Future<void> deleteConversation(String id);
  Future<void> updateConversationTitle(String id, String title);
  Stream<List<Conversation>> watchAllConversations();
}
