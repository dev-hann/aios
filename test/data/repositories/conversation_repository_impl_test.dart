import 'dart:ffi';

import 'package:aios/data/datasources/local/database.dart';
import 'package:aios/data/repositories/conversation_repository_impl.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

AppDatabase createTestDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

ChatMessage _makeMessage({
  required String id,
  required String role,
  required String content,
  DateTime? createdAt,
}) {
  return ChatMessage(
    id: id,
    role: role,
    content: content,
    createdAt: createdAt ?? DateTime(2026),
  );
}

DynamicLibrary _openOnLinux() {
  return DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0');
}

void main() {
  open.overrideFor(OperatingSystem.linux, _openOnLinux);

  group('ConversationRepositoryImpl', () {
    late AppDatabase db;
    late ConversationRepositoryImpl repository;

    setUp(() {
      db = createTestDatabase();
      repository = ConversationRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('load_returnsEmptyWhenNoMessages', () async {
      final loaded = await repository.load();

      expect(loaded, isEmpty);
    });

    test('save_and_load_roundTrip', () async {
      final messages = [
        _makeMessage(id: '1', role: 'user', content: 'Hello'),
        _makeMessage(id: '2', role: 'assistant', content: 'Hi there!'),
      ];

      await repository.save(messages);
      final loaded = await repository.load();

      expect(loaded.length, 2);
      expect(loaded[0].content, 'Hello');
      expect(loaded[1].content, 'Hi there!');
    });

    test('appendMessage_addsToExisting', () async {
      await repository.save([
        _makeMessage(id: '1', role: 'user', content: 'First'),
      ]);

      await repository.appendMessage(
        _makeMessage(id: '2', role: 'assistant', content: 'Second'),
      );

      final loaded = await repository.load();

      expect(loaded.length, 2);
      expect(loaded[0].content, 'First');
      expect(loaded[1].content, 'Second');
    });

    test('clear_removesAllData', () async {
      await repository.save([
        _makeMessage(id: '1', role: 'user', content: 'Hello'),
      ]);
      expect((await repository.load()).length, 1);

      await repository.clear();

      expect(await repository.load(), isEmpty);
    });

    test('save_overwritesPrevious', () async {
      await repository.save([
        _makeMessage(id: '1', role: 'user', content: 'Old'),
      ]);

      await repository.save([
        _makeMessage(id: '2', role: 'user', content: 'New'),
      ]);

      final loaded = await repository.load();

      expect(loaded.length, 1);
      expect(loaded[0].content, 'New');
    });
  });
}
