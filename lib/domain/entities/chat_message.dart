import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message.g.dart';
part 'chat_message.freezed.dart';

@freezed
class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required String role,
    required String content,
    required DateTime createdAt,
    String? toolName,
    String? toolArgs,
    String? toolResult,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}
