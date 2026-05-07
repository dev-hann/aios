import 'package:aios/data/datasources/local/database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AppDatabase integration', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase();
    });

    tearDown(() async {
      await db.deleteAllData();
      await db.close();
    });

    group('conversation CRUD', () {
      testWidgets('insert and getAllConversations', (tester) async {
        await db.insertConversation(
          ConversationsCompanion.insert(
            id: 'conv-1',
            title: Value('Test Chat'),
          ),
        );

        final conversations = await db.getAllConversations();
        expect(conversations, hasLength(1));
        expect(conversations.first.id, 'conv-1');
        expect(conversations.first.title, 'Test Chat');
      });

      testWidgets('insert multiple and order by updatedAt desc',
          (tester) async {
        await db.insertConversation(
          ConversationsCompanion.insert(
            id: 'conv-1',
            updatedAt: Value(DateTime(2026, 1, 1)),
          ),
        );
        await db.insertConversation(
          ConversationsCompanion.insert(
            id: 'conv-2',
            updatedAt: Value(DateTime(2026, 6, 1)),
          ),
        );

        final conversations = await db.getAllConversations();
        expect(conversations, hasLength(2));
        expect(conversations.first.id, 'conv-2');
      });

      testWidgets('deleteConversation removes conversation', (tester) async {
        await db.insertConversation(
          ConversationsCompanion.insert(id: 'conv-1'),
        );
        await db.insertConversation(
          ConversationsCompanion.insert(id: 'conv-2'),
        );

        await db.deleteConversation('conv-1');

        final conversations = await db.getAllConversations();
        expect(conversations, hasLength(1));
        expect(conversations.first.id, 'conv-2');
      });

      testWidgets('deleteConversation does not cascade messages', (tester) async {
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

        final messages = await db.getMessages('conv-1');
        expect(messages, isEmpty);
        final conversations = await db.getAllConversations();
        expect(conversations.every((c) => c.id != 'conv-1'), isTrue);
      });

      testWidgets('watchAllConversations emits updates', (tester) async {
        final emitted = <List<Conversation>>[];
        db.watchAllConversations().listen(emitted.add);

        await db.insertConversation(
          ConversationsCompanion.insert(id: 'conv-1'),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));

        expect(emitted, isNotEmpty);
        expect(emitted.last, hasLength(1));
      });
    });

    group('message CRUD', () {
      const convId = 'conv-1';

      setUp(() async {
        await db.insertConversation(
          ConversationsCompanion.insert(id: convId),
        );
      });

      testWidgets('insert and getMessages', (tester) async {
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

      testWidgets('messages ordered by createdAt asc', (tester) async {
        await db.insertMessage(
          MessagesCompanion.insert(
            id: 'msg-1',
            conversationId: convId,
            role: 'user',
            content: 'First',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await db.insertMessage(
          MessagesCompanion.insert(
            id: 'msg-2',
            conversationId: convId,
            role: 'assistant',
            content: 'Second',
          ),
        );

        final messages = await db.getMessages(convId);
        expect(messages, hasLength(2));
        expect(messages.first.content, 'First');
        expect(messages.last.content, 'Second');
      });

      testWidgets('tool fields stored and retrieved', (tester) async {
        await db.insertMessage(
          MessagesCompanion.insert(
            id: 'msg-tool',
            conversationId: convId,
            role: 'assistant',
            content: 'Using calculator',
            toolName: Value('calculator'),
            toolArgs: Value('{"expression": "2+2"}'),
            toolResult: Value('4.0000'),
          ),
        );

        final messages = await db.getMessages(convId);
        expect(messages, hasLength(1));
        expect(messages.first.toolName, 'calculator');
        expect(messages.first.toolArgs, '{"expression": "2+2"}');
        expect(messages.first.toolResult, '4.0000');
      });

      testWidgets('nullable tool fields default to null', (tester) async {
        await db.insertMessage(
          MessagesCompanion.insert(
            id: 'msg-plain',
            conversationId: convId,
            role: 'user',
            content: 'Plain message',
          ),
        );

        final messages = await db.getMessages(convId);
        expect(messages.first.toolName, isNull);
        expect(messages.first.toolArgs, isNull);
        expect(messages.first.toolResult, isNull);
      });

      testWidgets('getMessageCount returns correct count', (tester) async {
        expect(await db.getMessageCount(convId), 0);

        await db.insertMessage(
          MessagesCompanion.insert(
            id: 'msg-1',
            conversationId: convId,
            role: 'user',
            content: 'A',
          ),
        );
        await db.insertMessage(
          MessagesCompanion.insert(
            id: 'msg-2',
            conversationId: convId,
            role: 'assistant',
            content: 'B',
          ),
        );

        expect(await db.getMessageCount(convId), 2);
      });

      testWidgets('deleteMessages removes all for conversation',
          (tester) async {
        await db.insertMessage(
          MessagesCompanion.insert(
            id: 'msg-1',
            conversationId: convId,
            role: 'user',
            content: 'A',
          ),
        );
        await db.insertMessage(
          MessagesCompanion.insert(
            id: 'msg-2',
            conversationId: convId,
            role: 'assistant',
            content: 'B',
          ),
        );

        await db.deleteMessages(convId);

        expect(await db.getMessageCount(convId), 0);
      });

      testWidgets('watchMessages emits updates', (tester) async {
        final emitted = <List<Message>>[];
        db.watchMessages(convId).listen(emitted.add);

        await db.insertMessage(
          MessagesCompanion.insert(
            id: 'msg-1',
            conversationId: convId,
            role: 'user',
            content: 'Live',
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));

        expect(emitted, isNotEmpty);
        expect(emitted.last.any((m) => m.content == 'Live'), isTrue);
      });
    });

    group('deleteAllData', () {
      testWidgets('removes all conversations and messages', (tester) async {
        await db.insertConversation(
          ConversationsCompanion.insert(id: 'conv-1'),
        );
        await db.insertMessage(
          MessagesCompanion.insert(
            id: 'msg-1',
            conversationId: 'conv-1',
            role: 'user',
            content: 'Test',
          ),
        );

        await db.deleteAllData();

        expect(await db.getAllConversations(), isEmpty);
        expect(await db.getMessages('conv-1'), isEmpty);
      });
    });

    group('multiple conversations', () {
      testWidgets('messages isolated per conversation', (tester) async {
        await db.insertConversation(
          ConversationsCompanion.insert(id: 'conv-1'),
        );
        await db.insertConversation(
          ConversationsCompanion.insert(id: 'conv-2'),
        );
        await db.insertMessage(
          MessagesCompanion.insert(
            id: 'msg-1',
            conversationId: 'conv-1',
            role: 'user',
            content: 'Conv 1',
          ),
        );
        await db.insertMessage(
          MessagesCompanion.insert(
            id: 'msg-2',
            conversationId: 'conv-2',
            role: 'user',
            content: 'Conv 2',
          ),
        );

        final msgs1 = await db.getMessages('conv-1');
        final msgs2 = await db.getMessages('conv-2');

        expect(msgs1, hasLength(1));
        expect(msgs1.first.content, 'Conv 1');
        expect(msgs2, hasLength(1));
        expect(msgs2.first.content, 'Conv 2');
      });
    });
  });
}
