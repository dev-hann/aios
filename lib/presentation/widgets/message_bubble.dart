import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    this.isStreaming = false,
    super.key,
  });

  final ChatMessage message;
  final bool isStreaming;

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
              Text(
                message.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            if (isStreaming) _StreamingCursor(),
            if (message.toolName != null) ...[
              const SizedBox(height: 6),
              _ToolInfo(message: message),
            ],
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
        '▎',
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
