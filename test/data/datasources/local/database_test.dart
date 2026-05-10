import 'dart:ffi';

import 'package:aios/data/datasources/local/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

void main() {
  open.overrideFor(OperatingSystem.linux, _openOnLinux);

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Conversations', () {
    test('insertConversation_and_getAllConversations', () async {
      await db.insertConversation(
        ConversationsCompanion.insert(
          id: 'conv-1',
          title: const Value('Test Chat'),
        ),
      );

      final conversations = await db.getAllConversations();
      expect(conversations, hasLength(1));
      expect(conversations.first.id, 'conv-1');
      expect(conversations.first.title, 'Test Chat');
    });

    test('watchAllConversations_emitsUpdates', () async {
      final stream = db.watchAllConversations();

      final firstEmission = await stream.first;
      expect(firstEmission, isEmpty);

      await db.insertConversation(ConversationsCompanion.insert(id: 'conv-1'));

      final secondEmission = await stream.first;
      expect(secondEmission, hasLength(1));
      expect(secondEmission.first.id, 'conv-1');
    });

    test('deleteConversation_removesConversation', () async {
      await db.insertConversation(ConversationsCompanion.insert(id: 'conv-1'));
      expect(await db.getAllConversations(), hasLength(1));

      await db.deleteConversation('conv-1');
      expect(await db.getAllConversations(), isEmpty);
    });

    test('conversations_orderedByUpdatedAt_desc', () async {
      final now = DateTime.now();
      await db.insertConversation(
        ConversationsCompanion.insert(
          id: 'conv-1',
          updatedAt: Value(now.subtract(const Duration(hours: 1))),
        ),
      );
      await db.insertConversation(
        ConversationsCompanion.insert(id: 'conv-2', updatedAt: Value(now)),
      );

      final conversations = await db.getAllConversations();
      expect(conversations[0].id, 'conv-2');
      expect(conversations[1].id, 'conv-1');
    });
  });

  group('Messages', () {
    const convId = 'conv-1';

    setUp(() async {
      await db.insertConversation(ConversationsCompanion.insert(id: convId));
    });

    test('insertMessage_and_getMessages', () async {
      await db.insertMessage(
        MessagesCompanion.insert(
          id: 'msg-1',
          conversationId: convId,
          role: 'user',
          content: 'Hello',
        ),
      );

      final messages = await db.getMessages(convId);
      expect(messages, hasLength(1));
      expect(messages.first.id, 'msg-1');
      expect(messages.first.role, 'user');
      expect(messages.first.content, 'Hello');
    });

    test('watchMessages_emitsUpdates', () async {
      final stream = db.watchMessages(convId);

      final firstEmission = await stream.first;
      expect(firstEmission, isEmpty);

      await db.insertMessage(
        MessagesCompanion.insert(
          id: 'msg-1',
          conversationId: convId,
          role: 'user',
          content: 'Hello',
        ),
      );

      final secondEmission = await stream.first;
      expect(secondEmission, hasLength(1));
    });

    test('deleteMessages_removesMessages', () async {
      await db.insertMessage(
        MessagesCompanion.insert(
          id: 'msg-1',
          conversationId: convId,
          role: 'user',
          content: 'Hello',
        ),
      );
      expect(await db.getMessages(convId), hasLength(1));

      await db.deleteMessages(convId);
      expect(await db.getMessages(convId), isEmpty);
    });

    test('getMessageCount_returnsCorrectCount', () async {
      expect(await db.getMessageCount(convId), 0);

      await db.insertMessage(
        MessagesCompanion.insert(
          id: 'msg-1',
          conversationId: convId,
          role: 'user',
          content: 'Hello',
        ),
      );
      expect(await db.getMessageCount(convId), 1);

      await db.insertMessage(
        MessagesCompanion.insert(
          id: 'msg-2',
          conversationId: convId,
          role: 'assistant',
          content: 'Hi',
        ),
      );
      expect(await db.getMessageCount(convId), 2);
    });

    test('messagesOrderedByCreatedAt_asc', () async {
      final now = DateTime.now();
      await db.insertMessage(
        MessagesCompanion.insert(
          id: 'msg-1',
          conversationId: convId,
          role: 'user',
          content: 'First',
          createdAt: Value(now.subtract(const Duration(minutes: 1))),
        ),
      );
      await db.insertMessage(
        MessagesCompanion.insert(
          id: 'msg-2',
          conversationId: convId,
          role: 'assistant',
          content: 'Second',
          createdAt: Value(now),
        ),
      );

      final messages = await db.getMessages(convId);
      expect(messages[0].content, 'First');
      expect(messages[1].content, 'Second');
    });

    test('messageWithToolFields_storedCorrectly', () async {
      await db.insertMessage(
        MessagesCompanion.insert(
          id: 'msg-tool',
          conversationId: convId,
          role: 'assistant',
          content: 'Calling tool',
          toolName: const Value('screen_action'),
          toolArgs: const Value('{"action": "click"}'),
          toolResult: const Value('OK'),
        ),
      );

      final messages = await db.getMessages(convId);
      expect(messages.first.toolName, 'screen_action');
      expect(messages.first.toolArgs, '{"action": "click"}');
      expect(messages.first.toolResult, 'OK');
    });
  });

  group('deleteAllData', () {
    test('deleteAllData_clearsEverything', () async {
      await db.insertConversation(ConversationsCompanion.insert(id: 'conv-1'));
      await db.insertMessage(
        MessagesCompanion.insert(
          id: 'msg-1',
          conversationId: 'conv-1',
          role: 'user',
          content: 'Hello',
        ),
      );

      expect(await db.getAllConversations(), hasLength(1));
      expect(await db.getMessageCount('conv-1'), 1);

      await db.deleteAllData();

      expect(await db.getAllConversations(), isEmpty);
      expect(await db.getMessageCount('conv-1'), 0);
    });
  });

  group('deleteConversation_cascadesMessages', () {
    test(
      'deleteConversation_doesNotCascade_manuallyDeleteMessagesFirst',
      () async {
        await db.insertConversation(
          ConversationsCompanion.insert(id: 'conv-1'),
        );
        await db.insertMessage(
          MessagesCompanion.insert(
            id: 'msg-1',
            conversationId: 'conv-1',
            role: 'user',
            content: 'Hello',
          ),
        );

        await db.deleteMessages('conv-1');
        await db.deleteConversation('conv-1');

        expect(await db.getAllConversations(), isEmpty);
        expect(await db.getMessages('conv-1'), isEmpty);
      },
    );
  });
}

DynamicLibrary _openOnLinux() {
  return DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0');
}
