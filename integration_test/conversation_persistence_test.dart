import 'package:aios/data/datasources/local/database.dart';
import 'package:aios/data/repositories/conversation_repository_impl.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationRepository integration', () {
    late AppDatabase db;
    late ConversationRepositoryImpl repo;

    setUp(() async {
      db = AppDatabase();
      repo = ConversationRepositoryImpl(db);
    });

    tearDown(() async {
      await db.deleteAllData();
      await db.close();
    });

    group('load', () {
      testWidgets('load empty returns empty list', (tester) async {
        final messages = await repo.load();
        expect(messages, isEmpty);
      });

      testWidgets('load creates default conversation if missing', (
        tester,
      ) async {
        await repo.load();

        final conversations = await db.getAllConversations();
        expect(conversations.any((c) => c.id == 'default'), isTrue);
      });
    });

    group('save and load round trip', () {
      testWidgets('save then load returns same messages', (tester) async {
        final now = DateTime.now();
        final messages = [
          ChatMessage(
            id: 'msg-1',
            role: 'user',
            content: 'Hello',
            createdAt: now,
          ),
          ChatMessage(
            id: 'msg-2',
            role: 'assistant',
            content: 'Hi there!',
            createdAt: now,
          ),
        ];

        await repo.save(messages);
        final loaded = await repo.load();

        expect(loaded, hasLength(2));
        expect(loaded[0].id, 'msg-1');
        expect(loaded[0].role, 'user');
        expect(loaded[0].content, 'Hello');
        expect(loaded[1].id, 'msg-2');
        expect(loaded[1].role, 'assistant');
        expect(loaded[1].content, 'Hi there!');
      });

      testWidgets('save with tool fields preserved', (tester) async {
        final now = DateTime.now();
        final messages = [
          ChatMessage(
            id: 'msg-tool',
            role: 'assistant',
            content: 'Calculated',
            createdAt: now,
            toolName: 'calculator',
            toolArgs: '{"expression": "42*2"}',
            toolResult: '84.0000',
          ),
        ];

        await repo.save(messages);
        final loaded = await repo.load();

        expect(loaded, hasLength(1));
        expect(loaded.first.toolName, 'calculator');
        expect(loaded.first.toolArgs, '{"expression": "42*2"}');
        expect(loaded.first.toolResult, '84.0000');
      });

      testWidgets('save overwrites previous messages', (tester) async {
        final now = DateTime.now();
        await repo.save([
          ChatMessage(
            id: 'old-1',
            role: 'user',
            content: 'Old message',
            createdAt: now,
          ),
        ]);

        await repo.save([
          ChatMessage(
            id: 'new-1',
            role: 'user',
            content: 'New message',
            createdAt: now,
          ),
        ]);

        final loaded = await repo.load();
        expect(loaded, hasLength(1));
        expect(loaded.first.content, 'New message');
      });
    });

    group('appendMessage', () {
      testWidgets('append adds to existing messages', (tester) async {
        final now = DateTime.now();
        await repo.save([
          ChatMessage(
            id: 'msg-1',
            role: 'user',
            content: 'First',
            createdAt: now,
          ),
        ]);

        await repo.appendMessage(
          ChatMessage(
            id: 'msg-2',
            role: 'assistant',
            content: 'Response',
            createdAt: now,
          ),
        );

        final loaded = await repo.load();
        expect(loaded, hasLength(2));
        expect(loaded.last.content, 'Response');
      });

      testWidgets('append to empty creates conversation', (tester) async {
        await repo.appendMessage(
          ChatMessage(
            id: 'msg-1',
            role: 'user',
            content: 'First ever',
            createdAt: DateTime.now(),
          ),
        );

        final loaded = await repo.load();
        expect(loaded, hasLength(1));
        expect(loaded.first.content, 'First ever');
      });

      testWidgets('append multiple messages in sequence', (tester) async {
        final now = DateTime.now();
        for (var i = 0; i < 5; i++) {
          await repo.appendMessage(
            ChatMessage(
              id: 'msg-$i',
              role: i % 2 == 0 ? 'user' : 'assistant',
              content: 'Message $i',
              createdAt: now,
            ),
          );
        }

        final loaded = await repo.load();
        expect(loaded, hasLength(5));
      });
    });

    group('clear', () {
      testWidgets('clear removes all messages', (tester) async {
        final now = DateTime.now();
        await repo.save([
          ChatMessage(
            id: 'msg-1',
            role: 'user',
            content: 'To be cleared',
            createdAt: now,
          ),
        ]);

        await repo.clear();

        final loaded = await repo.load();
        expect(loaded, isEmpty);
      });

      testWidgets('clear then save works fresh', (tester) async {
        final now = DateTime.now();
        await repo.save([
          ChatMessage(id: 'old', role: 'user', content: 'Old', createdAt: now),
        ]);
        await repo.clear();
        await repo.save([
          ChatMessage(id: 'new', role: 'user', content: 'New', createdAt: now),
        ]);

        final loaded = await repo.load();
        expect(loaded, hasLength(1));
        expect(loaded.first.content, 'New');
      });
    });
  });
}
