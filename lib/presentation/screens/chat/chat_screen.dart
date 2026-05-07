import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/domain/agent/user_message_mapper.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/presentation/providers/chat_providers.dart';
import 'package:aios/presentation/providers/chat_state.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/widgets/input_bar.dart';
import 'package:aios/presentation/widgets/loading_indicator.dart';
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
    Future.microtask(() {
      ref.read(chatStateProvider.notifier).loadConversation();
      _checkOnboarding();
    });
  }

  void _checkOnboarding() {
    final settings = ref.read(settingsProvider);
    if (!settings.onboardingCompleted) {
      Future.microtask(() => context.go('/onboarding'));
    }
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
    final llmRepo = ref.watch(llmRepositoryProvider);
    final contextUsage = chatState.serviceState == ServiceState.ready
        ? llmRepo.getContextUsage()
        : null;

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
    final isGenerating = widget.chatState.isGenerating;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length +
          agentSteps.length +
          (isGenerating && agentSteps.isEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < messages.length) {
          return MessageBubble(message: messages[index]);
        }

        final stepIndex = index - messages.length;
        if (stepIndex < agentSteps.length) {
          return _AgentStepCard(step: agentSteps[stepIndex]);
        }

        return const _ThinkingIndicator();
      },
    );
  }
}

class _AgentStepCard extends StatelessWidget {
  const _AgentStepCard({required this.step});

  final AgentStep step;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.assistantBubble,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.md),
            topRight: Radius.circular(AppRadius.md),
            bottomRight: Radius.circular(AppRadius.md),
          ),
          border: _stepBorder(),
        ),
        child: _buildContent(),
      ),
    );
  }

  BoxBorder? _stepBorder() {
    if (step.type == 'action') {
      return Border.all(color: AppColors.secondary.withOpacity(0.3));
    }
    if (step.type == 'confirmation_required') {
      return Border.all(
        color: step.riskLevel == 'critical'
            ? AppColors.error.withOpacity(0.5)
            : AppColors.warning.withOpacity(0.5),
      );
    }
    return null;
  }

  Widget _buildContent() {
    return switch (step.type) {
      'thought' => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                step.content,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      'thinking_start' || 'thinking_end' => const SizedBox.shrink(),
      'action' => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.build,
                  size: 14,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 4),
                Text(
                  step.toolName,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (step.toolArgs.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                step.toolArgs,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      'confirmation_required' => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              step.riskLevel == 'critical'
                  ? Icons.warning
                  : Icons.shield,
              size: 14,
              color: step.riskLevel == 'critical'
                  ? AppColors.error
                  : AppColors.warning,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Waiting for confirmation...',
                style: TextStyle(
                  color: step.riskLevel == 'critical'
                      ? AppColors.error
                      : AppColors.warning,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      'observation' => Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.surfaceModal,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Result',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                step.content,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      _ => const SizedBox.shrink(),
    };
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
