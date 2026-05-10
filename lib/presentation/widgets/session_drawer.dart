import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/domain/entities/conversation.dart';
import 'package:aios/presentation/providers/chat_providers.dart';
import 'package:aios/presentation/providers/conversation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SessionDrawer extends ConsumerWidget {
  const SessionDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatStateProvider);
    final conversationsAsync = ref.watch(conversationListProvider);

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(
              onNewChat: () {
                Navigator.of(context).pop();
                ref.read(chatStateProvider.notifier).createNewChat();
              },
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: conversationsAsync.when(
                data: (conversations) => _ConversationList(
                  conversations: conversations,
                  activeId: chatState.currentConversationId,
                  onSelect: (conv) {
                    Navigator.of(context).pop();
                    ref
                        .read(chatStateProvider.notifier)
                        .switchConversation(conv.id, conv.title);
                  },
                  onDelete: (id) {
                    ref.read(chatStateProvider.notifier).deleteConversation(id);
                  },
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    Strings.drawer.errorLoadConversations,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            _DrawerFooter(
              onSettings: () {
                Navigator.of(context).pop();
                context.push('/settings');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.onNewChat});

  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              Strings.appName,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: AppColors.primary,
              size: 24,
            ),
            tooltip: Strings.chat.newConversation,
            onPressed: onNewChat,
          ),
        ],
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.activeId,
    required this.onSelect,
    required this.onDelete,
  });

  final List<Conversation> conversations;
  final String? activeId;
  final ValueChanged<Conversation> onSelect;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return Center(
        child: Text(
          Strings.drawer.noConversations,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conv = conversations[index];
        final isActive = conv.id == activeId;
        return _ConversationItem(
          conversation: conv,
          isActive: isActive,
          onSelect: () => onSelect(conv),
          onDelete: () => _confirmDelete(context, conv),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Conversation conv) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceModal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        title: Text(Strings.drawer.deleteConversation),
        content: Text(Strings.drawer.deleteConfirm(conv.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(Strings.drawer.settings),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete(conv.id);
            },
            child: Text(
              Strings.drawer.delete,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationItem extends StatelessWidget {
  const _ConversationItem({
    required this.conversation,
    required this.isActive,
    required this.onSelect,
    required this.onDelete,
  });

  final Conversation conversation;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: isActive,
      selectedTileColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      leading: Icon(
        Icons.chat_bubble_outline,
        size: 18,
        color: isActive ? AppColors.primary : AppColors.textSecondary,
      ),
      title: Text(
        conversation.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: conversation.updatedAt != null
          ? Text(
              _formatDate(conversation.updatedAt!),
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            )
          : null,
      trailing: isActive
          ? null
          : IconButton(
              icon: const Icon(
                Icons.close,
                size: 16,
                color: AppColors.textSecondary,
              ),
              tooltip: Strings.drawer.delete,
              onPressed: onDelete,
            ),
      onTap: onSelect,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else if (diff.inDays < 7) {
      return Strings.daysAgo(diff.inDays);
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'drawer_settings_tile',
      button: true,
      child: ListTile(
        dense: true,
        leading: const Icon(
          Icons.settings_outlined,
          size: 20,
          color: AppColors.textSecondary,
        ),
        title: Text(
          Strings.drawer.settings,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        onTap: onSettings,
      ),
    );
  }
}
