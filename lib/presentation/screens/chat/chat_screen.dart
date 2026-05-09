import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/domain/agent/user_message_mapper.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/presentation/providers/chat_providers.dart';
import 'package:aios/presentation/providers/chat_state.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/widgets/input_bar.dart';
import 'package:aios/presentation/widgets/loading_indicator.dart';
import 'package:aios/presentation/widgets/message_bubble.dart';
import 'package:aios/presentation/widgets/session_drawer.dart';
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
    Future.microtask(() {
      _initializeSession();
    });
  }

  void _initializeSession() {
    ref.read(chatStateProvider.notifier).initializeSession();
  }

  void _showClearChatDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceModal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        title: const Text('Clear Chat'),
        content: const Text('Delete all messages?'),
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

  void _showConfirmationDialog(
    BuildContext context,
    AgentStep step,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceModal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        title: Row(
          children: [
            Icon(
              step.riskLevel == 'critical'
                  ? Icons.warning
                  : Icons.shield,
              color: step.riskLevel == 'critical'
                  ? AppColors.error
                  : AppColors.warning,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text('Confirm Action'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tool: ${step.toolName}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              step.toolArgs,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref
                  .read(chatStateProvider.notifier)
                  .resolveConfirmation(false);
            },
            child: const Text(
              'Deny',
              style: TextStyle(color: AppColors.error),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref
                  .read(chatStateProvider.notifier)
                  .resolveConfirmation(true);
            },
            child: const Text(
              'Approve',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatStateProvider);

    ref.listen<ChatState>(chatStateProvider, (prev, next) {
      if (next.isConfirming && !(prev?.isConfirming ?? false)) {
        final confirmStep = next.agentSteps
            .where((s) => s.type == 'confirmation_required')
            .lastOrNull;
        if (confirmStep != null) {
          _showConfirmationDialog(context, confirmStep);
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const SessionDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(
              Icons.menu,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          chatState.currentConversationTitle,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_comment_outlined,
              color: AppColors.textSecondary,
            ),
            tooltip: '\uC0C8 \uB300\uD654',
            onPressed: () =>
                ref.read(chatStateProvider.notifier).createNewChat(),
          ),
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
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: chatState.serviceState == ServiceState.loadingModel
          ? const _ModelLoadingView()
          : Column(
              children: [
                if (chatState.errorMessage != null)
                  _ErrorBar(
                    message: UserMessageMapper.map(
                      chatState.errorMessage!,
                    ),
                  ),
                Expanded(
                  child: chatState.messages.isEmpty &&
                          !chatState.isGenerating
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
                          agentMaxIterations:
                              settings.agentMaxIterations,
                        );
                  },
                  onStop: () {
                    ref
                        .read(chatStateProvider.notifier)
                        .stopGeneration();
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
      decoration: const BoxDecoration(
        color: AppColors.surfaceModal,
        border: Border(
          left: BorderSide(color: AppColors.error, width: 4),
        ),
      ),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 40,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'AIOS',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.02,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your on-device AI assistant',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
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
  bool _showScrollFab = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final show = !_scrollController.hasClients ||
        _scrollController.position.maxScrollExtent -
                _scrollController.offset >
            200;
    if (show != _showScrollFab) {
      setState(() => _showScrollFab = show);
    }
  }

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
          duration: const Duration(milliseconds: 100),
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
    final agentSteps = widget.chatState.agentSteps;

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: messages.length +
              agentSteps.length +
              (widget.chatState.isThinking ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < messages.length) {
              return MessageBubble(message: messages[index]);
            }

            final stepIndex = index - messages.length;
            if (stepIndex < agentSteps.length) {
              return _SystemAnnotation(step: agentSteps[stepIndex]);
            }

            return const _ThinkingIndicator();
          },
        ),
        if (_showScrollFab && messages.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 16,
            child: Semantics(
              label: 'scroll_to_bottom_button',
              child: FloatingActionButton.small(
                onPressed: _scrollToBottom,
                backgroundColor: AppColors.surfaceModal,
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SystemAnnotation extends StatelessWidget {
  const _SystemAnnotation({required this.step});

  final AgentStep step;

  static const _hiddenTypes = {
    'thought',
    'thinking_start',
    'thinking_end',
  };

  bool get _isHidden => _hiddenTypes.contains(step.type);

  @override
  Widget build(BuildContext context) {
    if (_isHidden) return const SizedBox.shrink();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _annotationText,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (step.type) {
        'phase0_classifying' => Icons.search,
        'phase0_result' => Icons.check_circle_outline,
        'phase0_retry' => Icons.refresh,
        'phase1_retry' => Icons.refresh,
        'phase_answer' => Icons.chat_bubble_outline,
        'phase_answer_retry' => Icons.refresh,
        'action' => Icons.build_outlined,
        'observation' => Icons.check_circle_outline,
        'confirmation_required' => Icons.shield_outlined,
        _ => Icons.circle,
      };

  String get _annotationText {
    switch (step.type) {
      case 'phase0_classifying':
        return '\uC758\uB3C4 \uBD84\uC11D \uC911...';
      case 'phase0_result':
        return step.content;
      case 'phase0_retry':
        return '\uC758\uB3C4 \uBD84\uC11D \uC7AC\uC2DC\uB3C4... '
            '(${step.retryAttempt}/${step.maxRetries})';
      case 'phase1_retry':
        return '\uC791\uC5C5 \uBD84\uC11D \uC7AC\uC2DC\uB3C4... '
            '(${step.retryAttempt}/${step.maxRetries})';
      case 'phase_answer':
        return '\uC751\uB2F5 \uC0DD\uC131 \uC911...';
      case 'phase_answer_retry':
        return '\uC751\uB2F5 \uC7AC\uC2DC\uB3C4... '
            '(${step.retryAttempt}/${step.maxRetries})';
      case 'action':
        final name = step.toolName.isNotEmpty
            ? step.toolName
            : 'tool';
        return '$name \uC2E4\uD589 \uC911...';
      case 'observation':
        final result = step.toolResult;
        if (result.isEmpty) return '\uACB0\uACFC: (empty)';
        final summary = result.length > 50
            ? '${result.substring(0, 50)}...'
            : result;
        final isError = summary.trimLeft().startsWith('Error:');
        return isError
            ? '\uC2E4\uD328: $summary'
            : '\uACB0\uACFC: $summary';
      case 'confirmation_required':
        return '\uC0AC\uC6A9\uC790 \uD655\uC778 \uB300\uAE30 \uC911...';
      default:
        return step.content;
    }
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Thinking...',
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelLoadingView extends StatelessWidget {
  const _ModelLoadingView();

  @override
  Widget build(BuildContext context) {
    return const LoadingIndicator(phase: LoadingPhase.loadingModel);
  }
}
