import 'package:aios/domain/entities/conversation.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  throw UnimplementedError('conversationRepositoryProvider must be overridden');
});

final conversationListProvider = StreamProvider<List<Conversation>>((ref) {
  final repo = ref.watch(conversationRepositoryProvider);
  return repo.watchAllConversations();
});
