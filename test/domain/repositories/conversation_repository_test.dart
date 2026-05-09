import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/conversation.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockConversationRepository implements ConversationRepository {
  final List<ChatMessage> _messages = [];

  @override
  Future<void> save(List<ChatMessage> messages) async {
    _messages
      ..clear()
      ..addAll(messages);
  }

  @override
  Future<List<ChatMessage>> load() async {
    return List.unmodifiable(_messages);
  }

  @override
  Future<void> clear() async {
    _messages.clear();
  }

  @override
  Future<void> appendMessage(ChatMessage message) async {
    _messages.add(message);
  }

  @override
  Future<Conversation> createConversation({String? title}) async {
    return Conversation(
      id: 'test_conv',
      title: title ?? '새 대화',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Conversation>> getAllConversations() async => [];

  @override
  Future<List<ChatMessage>> loadConversation(String id) async =>
      List.unmodifiable(_messages);

  @override
  Future<void> deleteConversation(String id) async {}

  @override
  Future<void> updateConversationTitle(String id, String title) async {}

  @override
  Stream<List<Conversation>> watchAllConversations() => Stream.value([]);

  @override
  void setActiveConversationId(String id) {}
}

ChatMessage _makeMessage({
  required String role,
  required String content,
}) {
  return ChatMessage(
    id: '${role}_${content.hashCode}',
    role: role,
    content: content,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('ConversationRepository', () {
    late _MockConversationRepository repository;

    setUp(() {
      repository = _MockConversationRepository();
    });

    test('save_and_load_roundTrip', () async {
      final messages = [
        _makeMessage(role: 'user', content: 'Hello'),
        _makeMessage(role: 'assistant', content: 'Hi there!'),
      ];

      await repository.save(messages);
      final loaded = await repository.load();

      expect(loaded.length, 2);
      expect(loaded[0].content, 'Hello');
      expect(loaded[1].content, 'Hi there!');
    });

    test('append_message_addsToExistingMessages', () async {
      await repository.save([
        _makeMessage(role: 'user', content: 'First'),
      ]);
      await repository.appendMessage(
        _makeMessage(role: 'assistant', content: 'Second'),
      );

      final loaded = await repository.load();

      expect(loaded.length, 2);
      expect(loaded[0].content, 'First');
      expect(loaded[1].content, 'Second');
    });

    test('clear_removesAllMessages', () async {
      await repository.save([
        _makeMessage(role: 'user', content: 'Hello'),
      ]);
      expect((await repository.load()).length, 1);

      await repository.clear();

      expect((await repository.load()).isEmpty, isTrue);
    });

    test('load_returnsEmptyList_whenNoMessages', () async {
      final loaded = await repository.load();

      expect(loaded.isEmpty, isTrue);
    });

    test('save_overwritesPreviousMessages', () async {
      await repository.save([
        _makeMessage(role: 'user', content: 'Old'),
      ]);
      await repository.save([
        _makeMessage(role: 'user', content: 'New'),
      ]);

      final loaded = await repository.load();

      expect(loaded.length, 1);
      expect(loaded[0].content, 'New');
    });
  });
}
