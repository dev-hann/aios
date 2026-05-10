import 'package:aios/domain/entities/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Conversation', () {
    final fixedDate = DateTime(2026, 1, 15, 10, 30);

    test('constructor_withRequiredFields_createsSuccessfully', () {
      const conv = Conversation(id: 'conv-1');

      expect(conv.id, 'conv-1');
      expect(conv.title, '새 대화');
      expect(conv.createdAt, isNull);
      expect(conv.updatedAt, isNull);
    });

    test('constructor_withAllFields_createsSuccessfully', () {
      final conv = Conversation(
        id: 'conv-2',
        title: 'Test Chat',
        createdAt: fixedDate,
        updatedAt: fixedDate,
      );

      expect(conv.id, 'conv-2');
      expect(conv.title, 'Test Chat');
      expect(conv.createdAt, fixedDate);
      expect(conv.updatedAt, fixedDate);
    });

    test('copyWith_returnsUpdatedCopy', () {
      final original = Conversation(
        id: 'conv-1',
        title: 'Old Title',
        createdAt: fixedDate,
      );

      final copied = original.copyWith(title: 'New Title');

      expect(copied.id, 'conv-1');
      expect(copied.title, 'New Title');
      expect(original.title, 'Old Title');
    });

    test('toJson_returnsCorrectMap', () {
      final conv = Conversation(
        id: 'conv-1',
        title: 'Chat',
        createdAt: fixedDate,
      );

      final json = conv.toJson();

      expect(json['id'], 'conv-1');
      expect(json['title'], 'Chat');
    });

    test('fromJson_returnsCorrectInstance', () {
      final json = {
        'id': 'conv-1',
        'title': 'My Chat',
        'createdAt': fixedDate.toIso8601String(),
        'updatedAt': null,
      };

      final conv = Conversation.fromJson(json);

      expect(conv.id, 'conv-1');
      expect(conv.title, 'My Chat');
      expect(conv.updatedAt, isNull);
    });

    test('equality_sameValues_areEqual', () {
      final a = Conversation(id: 'conv-1', title: 'Chat', createdAt: fixedDate);
      final b = Conversation(id: 'conv-1', title: 'Chat', createdAt: fixedDate);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality_differentValues_areNotEqual', () {
      const a = Conversation(id: 'conv-1', title: 'A');
      const b = Conversation(id: 'conv-1', title: 'B');

      expect(a, isNot(equals(b)));
    });
  });
}
