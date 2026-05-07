import 'package:aios/presentation/providers/agent_provider.dart';
import 'package:aios/presentation/providers/chat_notifier.dart';
import 'package:aios/presentation/providers/chat_state.dart';
import 'package:aios/presentation/providers/conversation_provider.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatStateProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final llmRepo = ref.watch(llmRepositoryProvider);
  final conversationRepo = ref.watch(conversationRepositoryProvider);
  final agent = ref.watch(agentProvider);
  return ChatNotifier(llmRepo, conversationRepo, agent);
});
