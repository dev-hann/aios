import 'package:aios/domain/entities/chat_message.dart';

abstract class ConversationRepository {
  Future<void> save(List<ChatMessage> messages);
  Future<List<ChatMessage>> load();
  Future<void> clear();
  Future<void> appendMessage(ChatMessage message);
}
