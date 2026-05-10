import 'package:aios/domain/entities/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMessage', () {
    final fixedDate = DateTime(2026, 1, 15, 10, 30);

    test('constructor_withRequiredFields_createsSuccessfully', () {
      final message = ChatMessage(
        id: 'msg-1',
        role: 'user',
        content: 'Hello',
        createdAt: fixedDate,
      );

      expect(message.id, 'msg-1');
      expect(message.role, 'user');
      expect(message.content, 'Hello');
      expect(message.createdAt, fixedDate);
    });

    test('constructor_defaultOptionalFields_areNull', () {
      final message = ChatMessage(
        id: 'msg-1',
        role: 'user',
        content: 'Hello',
        createdAt: fixedDate,
      );

      expect(message.toolName, isNull);
      expect(message.toolArgs, isNull);
      expect(message.toolResult, isNull);
    });

    test('constructor_withOptionalFields_createsSuccessfully', () {
      final message = ChatMessage(
        id: 'msg-2',
        role: 'assistant',
        content: 'Calling tool',
        createdAt: fixedDate,
        toolName: 'screen_action',
        toolArgs: '{"action": "tap", "x": 100, "y": 200}',
        toolResult: 'success',
      );

      expect(message.toolName, 'screen_action');
      expect(message.toolArgs, '{"action": "tap", "x": 100, "y": 200}');
      expect(message.toolResult, 'success');
    });

    test('copyWith_returnsUpdatedCopy', () {
      final original = ChatMessage(
        id: 'msg-1',
        role: 'user',
        content: 'Hello',
        createdAt: fixedDate,
      );

      final copied = original.copyWith(
        content: 'Updated',
        toolName: 'app_launcher',
      );

      expect(copied.id, 'msg-1');
      expect(copied.role, 'user');
      expect(copied.content, 'Updated');
      expect(copied.toolName, 'app_launcher');
      expect(original.content, 'Hello');
    });

    test('toJson_returnsCorrectMap', () {
      final message = ChatMessage(
        id: 'msg-1',
        role: 'user',
        content: 'Hello',
        createdAt: fixedDate,
      );

      final json = message.toJson();

      expect(json['id'], 'msg-1');
      expect(json['role'], 'user');
      expect(json['content'], 'Hello');
      expect(json['toolName'], isNull);
      expect(json['toolArgs'], isNull);
      expect(json['toolResult'], isNull);
    });

    test('fromJson_returnsCorrectInstance', () {
      final json = {
        'id': 'msg-1',
        'role': 'assistant',
        'content': 'Response',
        'createdAt': fixedDate.toIso8601String(),
        'toolName': 'screen_action',
        'toolArgs': null,
        'toolResult': null,
      };

      final message = ChatMessage.fromJson(json);

      expect(message.id, 'msg-1');
      expect(message.role, 'assistant');
      expect(message.content, 'Response');
      expect(message.toolName, 'screen_action');
    });

    test('equality_sameValues_areEqual', () {
      final a = ChatMessage(
        id: 'msg-1',
        role: 'user',
        content: 'Hello',
        createdAt: fixedDate,
      );
      final b = ChatMessage(
        id: 'msg-1',
        role: 'user',
        content: 'Hello',
        createdAt: fixedDate,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
