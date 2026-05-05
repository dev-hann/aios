import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/presentation/providers/chat_providers.dart';
import 'package:aios/presentation/providers/chat_state.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/widgets/input_bar.dart';
import 'package:aios/presentation/widgets/message_bubble.dart';
import 'package:aios/presentation/widgets/status_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(chatStateProvider.notifier).loadConversation(),
    );
  }

  void _showClearChatDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Clear Chat',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Delete all messages?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(chatStateProvider.notifier).clearChat();
              Navigator.of(ctx).pop();
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatStateProvider);
    final llmRepo = ref.watch(llmRepositoryProvider);
    final contextUsage = chatState.serviceState == ServiceState.ready
        ? llmRepo.getContextUsage()
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: StatusBar(
          serviceState: chatState.serviceState,
          contextUsage: contextUsage,
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Clear chat',
            onPressed: () => _showClearChatDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.textPrimary),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: chatState.serviceState == ServiceState.loadingModel
          ? const _ModelLoadingView()
          : Column(
              children: [
                if (chatState.errorMessage != null)
                  _ErrorBar(message: chatState.errorMessage!),
                Expanded(
                  child: chatState.messages.isEmpty && !chatState.isGenerating
                      ? const _WelcomeView()
                      : _MessageList(chatState: chatState),
                ),
                InputBar(
                  onSubmitted: (text) {
                    if (text.isEmpty) return;
                    final settings = ref.read(settingsProvider);
                    ref.read(chatStateProvider.notifier).sendMessage(
                          text,
                          temperature: settings.temperature,
                          maxTokens: settings.maxTokens,
                          topK: settings.topK,
                          topP: settings.topP,
                          repeatPenalty: settings.repeatPenalty,
                        );
                  },
                  onStop: () {
                    ref.read(chatStateProvider.notifier).stopGeneration();
                  },
                  isGenerating: chatState.isGenerating,
                ),
              ],
            ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.error.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  const _WelcomeView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 64, color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'AIOS',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your on-device AI assistant',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList({required this.chatState});

  final ChatState chatState;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(_MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.chatState.messages;
    final isGenerating = widget.chatState.isGenerating;
    final currentResponse = widget.chatState.currentResponse;
    final showStreaming =
        isGenerating && currentResponse.isNotEmpty;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length + (showStreaming ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < messages.length) {
          return MessageBubble(message: messages[index]);
        }
        return MessageBubble(
          message: ChatMessage(
            id: 'streaming',
            role: 'assistant',
            content: currentResponse,
            createdAt: DateTime.now(),
          ),
          isStreaming: true,
        );
      },
    );
  }
}

class _ModelLoadingView extends StatelessWidget {
  const _ModelLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Loading Model...',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
