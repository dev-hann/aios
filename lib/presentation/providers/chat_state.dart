import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_state.freezed.dart';
part 'chat_state.g.dart';

@freezed
class ChatState with _$ChatState {
  const ChatState._();

  const factory ChatState({
    @Default([]) List<ChatMessage> messages,
    @Default('') String currentResponse,
    @Default(ServiceState.idle) ServiceState serviceState,
    String? errorMessage,
    @Default([]) List<AgentStep> agentSteps,
    @Default(false) bool isConfirming,
    String? currentConversationId,
    @Default('새 대화') String currentConversationTitle,
  }) = _ChatState;

  bool get isGenerating => agentSteps.isNotEmpty;

  bool get isThinking =>
      agentSteps.isNotEmpty &&
      !agentSteps.any((s) => !_hiddenTypes.contains(s.type));

  static const _hiddenTypes = {
    'thought',
    'thinking_start',
    'thinking_end',
  };

  factory ChatState.fromJson(Map<String, dynamic> json) =>
      _$ChatStateFromJson(json);
}
