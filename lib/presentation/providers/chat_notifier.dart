import 'dart:async';
import 'dart:convert';

import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/data/services/overlay_service.dart';
import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/agent/tool_permission_mapper.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/presentation/providers/chat_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(
    this._llmRepository,
    this._conversationRepository,
    this._agent,
    this._overlayService,
  ) : super(const ChatState()) {
    _listenToStateChanges();
  }

  final LlmRepository _llmRepository;
  final ConversationRepository _conversationRepository;
  final AgentStrategy _agent;
  final OverlayService _overlayService;
  StreamSubscription<ServiceState>? _stateSub;

  static const _tag = 'AIOS-ChatNotifier';

  void _listenToStateChanges() {
    _stateSub = _llmRepository.state.listen((serviceState) {
      if (!mounted) return;
      state = state.copyWith(serviceState: serviceState);

      if (serviceState == ServiceState.ready) {
        if (state.currentConversationId == null) {
          initializeSession();
        }
      }
    });
  }

  Future<void> sendMessage(
    String text, {
    double? temperature,
    int? maxTokens,
    double? topP,
    int? agentMaxIterations,
  }) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: text.trim(),
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      currentResponse: '',
      errorMessage: null,
      agentSteps: [const AgentStep('thinking_start', '')],
      isConfirming: false,
      isAwaitingPermission: false,
    );

    unawaited(
      _conversationRepository
          .appendMessage(userMessage)
          .catchError(
            (Object e) => print('[$_tag] WARN: appendMessage fire-forget - $e'),
          ),
    );

    if (state.currentConversationTitle == Strings.newConversationTitle &&
        state.messages.where((m) => m.role == 'user').length == 1) {
      final title = text.trim().length > 20
          ? '${text.trim().substring(0, 20)}...'
          : text.trim();
      final convId = state.currentConversationId;
      if (convId != null) {
        state = state.copyWith(currentConversationTitle: title);
        unawaited(
          _conversationRepository
              .updateConversationTitle(convId, title)
              .catchError(
                (Object e) =>
                    print('[$_tag] WARN: updateTitle fire-forget - $e'),
              ),
        );
      }
    }

    try {
      final result = await _agent.execute(
        text.trim(),
        maxIterations: agentMaxIterations ?? 8,
        maxTokens: maxTokens ?? 512,
        onStep: _handleStep,
      );

      if (!mounted) return;

      _agent.clearHistory();

      final answerStep = result.steps.where((s) => s.type == 'answer');
      if (answerStep.isNotEmpty) {
        final assistantMessage = ChatMessage(
          id: 'assistant_${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          content: answerStep.last.content,
          createdAt: DateTime.now(),
        );
        state = state.copyWith(messages: [...state.messages, assistantMessage]);
        await _conversationRepository.appendMessage(assistantMessage);
      }

      state = state.copyWith(
        agentSteps: [],
        isConfirming: false,
        isAwaitingPermission: false,
      );
    } on Object catch (e) {
      print('[$_tag] ERROR: sendMessage failed - $e');
      if (!mounted) return;
      state = state.copyWith(agentSteps: [], errorMessage: e.toString());
    }
  }

  void _handleStep(AgentStep step) {
    if (!mounted) return;

    _updateStatusOverlay(step);

    state = state.copyWith(
      agentSteps: [...state.agentSteps, step],
      isConfirming: step.type == 'confirmation_required' || state.isConfirming,
      isAwaitingPermission:
          step.type == 'permission_required' || state.isAwaitingPermission,
    );
  }

  void _updateStatusOverlay(AgentStep step) {
    final statusText = _stepToStatusText(step);
    if (statusText != null) {
      _overlayService.showStatus(statusText);
    }
    if (step.type == 'answer') {
      _overlayService.hideStatus();
    }
  }

  String? _stepToStatusText(AgentStep step) {
    return switch (step.type) {
      'action' => _actionToStatus(step),
      'observation' => _observationToStatus(step),
      'answer' => null,
      _ => null,
    };
  }

  String? _actionToStatus(AgentStep step) {
    final toolName = step.toolName;
    if (toolName.isEmpty) return null;
    return switch (toolName) {
      'app_launcher' => Strings.overlay.launchingApp,
      'screen_action' => _screenActionStatus(step.toolArgs),
      'screen_reader' => Strings.overlay.readingScreen,
      'screen_find' => Strings.overlay.findingOnScreen,
      'calculator' => Strings.overlay.calculating,
      'notepad' => Strings.overlay.writingNote,
      'timer' => Strings.overlay.settingTimer,
      'sms_sender' => Strings.overlay.smsTask,
      'phone_caller' => Strings.overlay.phoneTask,
      'contact_search' => Strings.overlay.searchingContacts,
      'notification_reader' => Strings.overlay.checkingNotifications,
      'device_info' => Strings.overlay.checkingDeviceInfo,
      _ => Strings.overlay.workingOn(toolName),
    };
  }

  String? _screenActionStatus(String argsJson) {
    try {
      final decoded = argsJson.isNotEmpty ? jsonDecode(argsJson) : null;
      final args = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      final action = args['action']?.toString() ?? '';
      return switch (action) {
        'tap' => Strings.overlay.tappingScreen,
        'type' => Strings.overlay.typingText,
        'long_click' => Strings.overlay.longPressing,
        'scroll' => Strings.overlay.scrolling,
        'swipe' => Strings.overlay.swiping,
        'global' => _globalActionStatus(args['global_action']?.toString()),
        _ => Strings.overlay.manipulatingScreen,
      };
    } on Object {
      return Strings.overlay.manipulatingScreen;
    }
  }

  String? _globalActionStatus(String? globalAction) {
    return switch (globalAction) {
      'enter' => Strings.overlay.pressingEnter,
      'back' => Strings.overlay.goingBack,
      'home' => Strings.overlay.goingHome,
      _ => Strings.overlay.systemAction,
    };
  }

  String? _observationToStatus(AgentStep step) {
    final toolName = step.toolName;
    if (toolName.isEmpty) return null;
    final result = step.toolResult;
    if (result.startsWith('Error')) return null;
    return switch (toolName) {
      'app_launcher' => Strings.overlay.appLaunched,
      'screen_action' => Strings.overlay.screenDone,
      _ => null,
    };
  }

  void resolveConfirmation({required bool approved}) {
    _agent.resolveConfirmation(approved: approved);
    state = state.copyWith(isConfirming: false);
  }

  Future<void> resolvePermission({required bool userTappedGrant}) async {
    final permStep = state.agentSteps
        .where((s) => s.type == 'permission_required')
        .lastOrNull;
    if (permStep == null) {
      _agent.resolvePermission(granted: false);
      state = state.copyWith(isAwaitingPermission: false);
      return;
    }

    if (!userTappedGrant) {
      _agent.resolvePermission(granted: false);
      state = state.copyWith(isAwaitingPermission: false);
      return;
    }

    final permKey = permStep.permission;
    final perm = ToolPermissionMapper.getByKey(permKey);

    if (perm == null) {
      _agent.resolvePermission(granted: false);
      state = state.copyWith(isAwaitingPermission: false);
      return;
    }

    var granted = false;

    if (perm.isService) {
      if (permKey == 'accessibility') {
        await _openAccessibilitySettings();
        granted = true;
      } else if (permKey == 'notification') {
        granted = await _requestNotificationPermission();
      }
    } else {
      granted = await _requestRuntimePermission(permKey);
    }

    print('[$_tag] Permission $permKey resolved: $granted');
    _agent.resolvePermission(granted: granted);
    state = state.copyWith(isAwaitingPermission: false);
  }

  Future<bool> _requestRuntimePermission(String permKey) async {
    final permission = _mapToPermission(permKey);
    if (permission == null) return false;

    try {
      final status = await permission.request();
      if (status.isGranted) return true;

      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      return false;
    } on Object catch (e) {
      print('[$_tag] ERROR: permission request - $e');
      return false;
    }
  }

  Future<bool> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } on Object catch (e) {
      print('[$_tag] ERROR: notification perm - $e');
      return false;
    }
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await openAppSettings();
    } on Object catch (e) {
      print('[$_tag] ERROR: open settings - $e');
    }
  }

  Permission? _mapToPermission(String key) {
    switch (key) {
      case 'contacts':
        return Permission.contacts;
      case 'phone':
        return Permission.phone;
      case 'sms':
        return Permission.sms;
      default:
        return null;
    }
  }

  Future<void> stopGeneration() async {
    _agent.cancel();
    await _llmRepository.stopGeneration();

    if (!mounted) return;

    final lastStep = state.agentSteps
        .where((s) => s.type == 'answer')
        .lastOrNull;
    if (lastStep != null) {
      final assistantMessage = ChatMessage(
        id: 'assistant_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: lastStep.content,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(messages: [...state.messages, assistantMessage]);
    }

    state = state.copyWith(
      isConfirming: false,
      isAwaitingPermission: false,
      agentSteps: [],
    );
  }

  Future<void> loadConversation() async {
    try {
      final messages = await _conversationRepository.load();
      if (!mounted) return;
      if (messages.isNotEmpty) {
        state = state.copyWith(messages: messages);
        print('[$_tag] Loaded ${messages.length} messages');
      }
    } on Object catch (e) {
      print('[$_tag] ERROR: loadConversation failed - $e');
    }
  }

  Future<void> initializeSession() async {
    try {
      final conversations = await _conversationRepository.getAllConversations();
      if (conversations.isEmpty) {
        final conv = await _conversationRepository.createConversation();
        if (!mounted) return;
        state = state.copyWith(
          currentConversationId: conv.id,
          currentConversationTitle: conv.title,
        );
      } else {
        final active = conversations.first;
        final messages = await _conversationRepository.loadConversation(
          active.id,
        );
        if (!mounted) return;
        state = state.copyWith(
          currentConversationId: active.id,
          currentConversationTitle: active.title,
          messages: messages,
        );
      }
      print(
        '[$_tag] Session initialized: '
        '${state.currentConversationId}',
      );
    } on Object catch (e) {
      print('[$_tag] ERROR: initializeSession failed - $e');
      await loadConversation();
    }
  }

  Future<void> createNewChat() async {
    try {
      final conv = await _conversationRepository.createConversation();
      _agent.clearHistory();
      if (!mounted) return;
      state = _resetWithConversation(conv.id, conv.title);
      print('[$_tag] Created new conversation: ${conv.id}');
    } on Object catch (e) {
      print('[$_tag] ERROR: createNewChat failed - $e');
    }
  }

  Future<void> switchConversation(String id, String title) async {
    try {
      _conversationRepository.setActiveConversationId(id);
      _agent.clearHistory();
      final messages = await _conversationRepository.loadConversation(id);
      if (!mounted) return;
      state = state.copyWith(
        messages: messages,
        currentResponse: '',
        errorMessage: null,
        agentSteps: [],
        isConfirming: false,
        isAwaitingPermission: false,
        currentConversationId: id,
        currentConversationTitle: title,
      );
      print('[$_tag] Switched to conversation: $id');
    } on Object catch (e) {
      print('[$_tag] ERROR: switchConversation failed - $e');
    }
  }

  Future<void> deleteConversation(String id) async {
    try {
      await _conversationRepository.deleteConversation(id);
      if (!mounted) return;
      if (state.currentConversationId == id) {
        final remaining = await _conversationRepository.getAllConversations();
        if (remaining.isNotEmpty) {
          final first = remaining.first;
          await switchConversation(first.id, first.title);
        } else {
          final conv = await _conversationRepository.createConversation();
          _agent.clearHistory();
          state = _resetWithConversation(conv.id, conv.title);
        }
      }
      print('[$_tag] Deleted conversation: $id');
    } on Object catch (e) {
      print('[$_tag] ERROR: deleteConversation failed - $e');
    }
  }

  Future<void> loadModel(String path, {int? contextSize}) async {
    await _llmRepository.loadModel(path, contextSize: contextSize);
  }

  Future<void> clearChat() async {
    _agent.clearHistory();
    await _conversationRepository.clear();
    state = const ChatState();
  }

  ChatState _resetWithConversation(String id, String title) {
    return state.copyWith(
      messages: [],
      currentResponse: '',
      errorMessage: null,
      agentSteps: [],
      isConfirming: false,
      isAwaitingPermission: false,
      currentConversationId: id,
      currentConversationTitle: title,
    );
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }
}
