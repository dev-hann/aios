import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    this.isStreaming = false,
    super.key,
  });

  final ChatMessage message;
  final bool isStreaming;

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';
    if (now.year == dt.year &&
        now.month == dt.month &&
        now.day == dt.day) {
      return timeStr;
    }
    final diff = now.difference(dt).inDays;
    if (diff < 7) {
      return '$diff\uC77C \uC804 $timeStr';
    }
    return '${dt.month}/${dt.day} $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isUser ? AppColors.userBubble : AppColors.assistantBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.md),
            topRight: const Radius.circular(AppRadius.md),
            bottomLeft:
                isUser ? const Radius.circular(AppRadius.md) : Radius.zero,
            bottomRight:
                isUser ? Radius.zero : const Radius.circular(AppRadius.md),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.content.isNotEmpty)
              GestureDetector(
                onLongPress: () => _copyToClipboard(context),
                child: isUser
                    ? Text(
                        message.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      )
                    : MarkdownBody(
                        data: message.content,
                        styleSheet: MarkdownStyleSheet(
                          p: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          code: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.secondary,
                            fontFamily: 'monospace',
                            backgroundColor:
                                AppColors.surfaceModal,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: AppColors.surfaceModal,
                            borderRadius: BorderRadius.circular(
                              AppRadius.sm,
                            ),
                          ),
                          codeblockPadding: const EdgeInsets.all(8),
                          listBullet: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          h1: theme.textTheme.titleLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          h2: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          h3: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          blockquote: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          blockquoteDecoration: const BoxDecoration(
                            color: AppColors.surfaceModal,
                            border: Border(
                              left: BorderSide(
                                color: AppColors.secondary,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                        selectable: true,
                        onTapLink: (text, href, title) {
                          if (href != null) {
                            Clipboard.setData(
                              ClipboardData(text: href),
                            );
                            ScaffoldMessenger.of(context)
                                .clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Link copied'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
              ),
            if (isStreaming) _StreamingCursor(),
            if (message.toolName != null) ...[
              const SizedBox(height: 6),
              _ToolInfo(message: message),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                _formatTimestamp(message.createdAt),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamingCursor extends StatefulWidget {
  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const Text(
        '\u258E',
        style: TextStyle(color: AppColors.primaryHover),
      ),
    );
  }
}

class _ToolInfo extends StatelessWidget {
  const _ToolInfo({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.build, size: 14, color: AppColors.secondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  message.toolName!,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (message.toolArgs != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                message.toolArgs!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (message.toolResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                message.toolResult!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
