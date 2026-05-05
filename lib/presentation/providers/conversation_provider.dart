import 'package:aios/data/repositories/conversation_repository_impl.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:aios/presentation/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepositoryImpl(ref.watch(appDatabaseProvider));
});
