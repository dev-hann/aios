import 'package:aios/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class InputBar extends StatefulWidget {
  const InputBar({
    required this.onSubmitted,
    required this.onStop,
    required this.isGenerating,
    super.key,
  });

  final ValueChanged<String> onSubmitted;
  final VoidCallback onStop;
  final bool isGenerating;

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmitted(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: Colors.white10, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !widget.isGenerating,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: widget.isGenerating
                      ? 'Generating...'
                      : 'Type a message...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: widget.isGenerating
                    ? null
                    : (_) => _handleSubmit(),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.isGenerating)
              _StopButton(onStop: widget.onStop)
            else
              _SendButton(onSend: _handleSubmit),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onSend});

  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onSend,
      icon: const Icon(Icons.send, color: AppColors.primary),
      tooltip: 'Send',
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.onStop});

  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onStop,
      icon: const Icon(Icons.stop_circle, color: AppColors.generating),
      tooltip: 'Stop',
    );
  }
}
