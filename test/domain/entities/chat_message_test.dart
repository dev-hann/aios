import 'package:aios/domain/entities/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMessage', () {
    final fixedDate = DateTime(2026, 1, 15, 10, 30, 0);

    test('should create with required fields', () {
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

    test('should default optional fields to null', () {
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

    test('should create with optional fields', () {
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

    test('should support copyWith', () {
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

    test('should serialize to json', () {
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

    test('should deserialize from json', () {
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

    test('should handle equality', () {
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
