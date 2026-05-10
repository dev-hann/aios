import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/domain/agent/tool_permission_mapper.dart';
import 'package:aios/domain/agent/user_message_mapper.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/presentation/providers/chat_providers.dart';
import 'package:aios/presentation/providers/chat_state.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/widgets/connection_status_badge.dart';
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
      ref.read(chatStateProvider.notifier).initializeSession();
    });
  }

  void _showConfirmationDialog(BuildContext context, AgentStep step) {
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
              step.riskLevel == 'critical' ? Icons.warning : Icons.shield,
              color: step.riskLevel == 'critical'
                  ? AppColors.error
                  : AppColors.warning,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(Strings.chat.confirmAction),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${Strings.chat.tool}: ${step.toolName}',
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
                  .resolveConfirmation(approved: false);
            },
            child: Text(
              Strings.chat.deny,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref
                  .read(chatStateProvider.notifier)
                  .resolveConfirmation(approved: true);
            },
            child: Text(
              Strings.chat.approve,
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatStateProvider);
    final settingsState = ref.watch(settingsProvider);

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
          builder: (context) => Semantics(
            label: 'drawer_open_menu',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textPrimary),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                chatState.currentConversationTitle,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ConnectionStatusBadge(
              config: settingsState.providerConfig,
              onTap: () => context.push('/settings/provider'),
            ),
          ],
        ),
        actions: [
          Semantics(
            label: 'new_conversation_button',
            button: true,
            child: IconButton(
              icon: const Icon(
                Icons.add_comment_outlined,
                color: AppColors.textSecondary,
              ),
              tooltip: Strings.chat.newConversation,
              onPressed: () =>
                  ref.read(chatStateProvider.notifier).createNewChat(),
            ),
          ),
        ],
      ),
      body: chatState.serviceState == ServiceState.loadingModel
          ? const _ModelLoadingView()
          : Column(
              children: [
                if (chatState.errorMessage != null)
                  _ErrorBar(
                    message: UserMessageMapper.map(chatState.errorMessage!),
                  ),
                Expanded(
                  child: chatState.messages.isEmpty && !chatState.isGenerating
                      ? _WelcomeView(
                          hasProvider: settingsState.providerConfig != null,
                        )
                      : _MessageList(chatState: chatState),
                ),
                InputBar(
                  onSubmitted: (text) {
                    if (text.isEmpty) return;
                    final settings = ref.read(settingsProvider);
                    ref
                        .read(chatStateProvider.notifier)
                        .sendMessage(
                          text,
                          temperature: settings.temperature,
                          maxTokens: settings.maxTokens,
                          topP: settings.topP,
                          agentMaxIterations: settings.agentMaxIterations,
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
      decoration: const BoxDecoration(
        color: AppColors.surfaceModal,
        border: Border(left: BorderSide(color: AppColors.error, width: 4)),
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
  const _WelcomeView({required this.hasProvider});

  final bool hasProvider;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
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
                size: 36,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              Strings.appName,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.02,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasProvider ? Strings.chat.whatCanHelp : Strings.appSubtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            if (!hasProvider) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.push('/settings/provider'),
                icon: const Icon(Icons.cloud_outlined, size: 18),
                label: Text(Strings.chat.setupAi),
              ),
            ],
            if (hasProvider) ...[
              const SizedBox(height: 28),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _SuggestionChip(text: Strings.suggestion.weather),
                  _SuggestionChip(text: Strings.suggestion.calculator),
                  _SuggestionChip(text: Strings.suggestion.memo),
                  _SuggestionChip(text: Strings.suggestion.timer),
                  _SuggestionChip(text: Strings.suggestion.screenshot),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      backgroundColor: AppColors.surfaceElevated,
      side: const BorderSide(color: AppColors.divider),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      onPressed: () {
        final chatNotifier = ProviderScope.containerOf(
          context,
        ).read(chatStateProvider.notifier);
        final settings = ProviderScope.containerOf(
          context,
        ).read(settingsProvider);
        chatNotifier.sendMessage(
          text,
          temperature: settings.temperature,
          maxTokens: settings.maxTokens,
          topP: settings.topP,
          agentMaxIterations: settings.agentMaxIterations,
        );
      },
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount:
          messages.length +
          agentSteps.length +
          (widget.chatState.isThinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < messages.length) {
          return MessageBubble(message: messages[index]);
        }

        final stepIndex = index - messages.length;
        if (stepIndex < agentSteps.length) {
          final step = agentSteps[stepIndex];
          if (step.type == 'permission_required') {
            return _PermissionCard(step: step);
          }
          return _SystemAnnotation(step: step);
        }

        return const _ThinkingIndicator();
      },
    );
  }
}

class _SystemAnnotation extends StatelessWidget {
  const _SystemAnnotation({required this.step});

  final AgentStep step;

  static const _hiddenTypes = {'thought', 'thinking_start', 'thinking_end'};

  bool get _isHidden => _hiddenTypes.contains(step.type);

  @override
  Widget build(BuildContext context) {
    if (_isHidden) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      child: Row(
        children: [
          Icon(_icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Expanded(
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
    'permission_required' => Icons.lock_outline,
    _ => Icons.circle,
  };

  String get _annotationText {
    switch (step.type) {
      case 'phase0_classifying':
        return Strings.annotation.analyzing;
      case 'phase0_result':
        return step.content;
      case 'phase0_retry':
        return Strings.annotation.analyzingRetry(
          step.retryAttempt,
          step.maxRetries,
        );
      case 'phase1_retry':
        return Strings.annotation.taskRetry(step.retryAttempt, step.maxRetries);
      case 'phase_answer':
        return Strings.annotation.generatingAnswer;
      case 'phase_answer_retry':
        return Strings.annotation.answerRetry(
          step.retryAttempt,
          step.maxRetries,
        );
      case 'action':
        final name = step.toolName.isNotEmpty ? step.toolName : 'tool';
        return Strings.annotation.running(name);
      case 'observation':
        final result = step.toolResult;
        if (result.isEmpty) return Strings.annotation.emptyResult;
        final summary = result.length > 50
            ? '${result.substring(0, 50)}...'
            : result;
        final isError = summary.trimLeft().startsWith('Error:');
        return isError
            ? Strings.annotation.failed(summary)
            : Strings.annotation.result(summary);
      case 'confirmation_required':
        return Strings.annotation.waitingConfirmation;
      case 'permission_required':
        return step.content;
      default:
        return step.content;
    }
  }
}

class _PermissionCard extends ConsumerWidget {
  const _PermissionCard({required this.step});

  final AgentStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perm = ToolPermissionMapper.getByKey(step.permission);
    final isService = perm?.isService ?? false;
    final displayName = perm?.displayName ?? step.content;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceModal,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Strings.permissionCard.needsPermission(displayName),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    ref
                        .read(chatStateProvider.notifier)
                        .resolvePermission(userTappedGrant: false);
                  },
                  child: const Text(
                    '나중에',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    ref
                        .read(chatStateProvider.notifier)
                        .resolvePermission(userTappedGrant: true);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  child: Text(
                    isService
                        ? Strings.permissionCard.goToSettings
                        : Strings.permissionCard.grant,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Strings.chat.thinking,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.7),
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
