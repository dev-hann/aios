import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'package:aios/data/datasources/local/tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Conversations, Messages, Notes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(notes);
      }
    },
  );

  Future<List<Conversation>> getAllConversations() {
    return (select(
      conversations,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
  }

  Stream<List<Conversation>> watchAllConversations() {
    return (select(
      conversations,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();
  }

  Future<void> insertConversation(ConversationsCompanion conversation) {
    return into(conversations).insert(conversation);
  }

  Future<void> deleteConversation(String id) {
    return (delete(conversations)..where((t) => t.id.equals(id))).go();
  }

  Future<void> updateConversation(String id, {String? title}) {
    return (update(conversations)..where((t) => t.id.equals(id))).write(
      ConversationsCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<Message>> getMessages(String conversationId) {
    return (select(messages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Stream<List<Message>> watchMessages(String conversationId) {
    return (select(messages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<void> insertMessage(MessagesCompanion message) {
    return into(messages).insert(message);
  }

  Future<void> deleteMessages(String conversationId) {
    return (delete(
      messages,
    )..where((t) => t.conversationId.equals(conversationId))).go();
  }

  Future<int> getMessageCount(String conversationId) async {
    final countExpr = messages.id.count();
    final query = selectOnly(messages)
      ..where(messages.conversationId.equals(conversationId))
      ..addColumns([countExpr]);
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  Future<void> deleteAllData() {
    return transaction(() async {
      await delete(messages).go();
      await delete(conversations).go();
      await delete(notes).go();
    });
  }

  Future<List<Note>> getAllNotes() {
    return (select(notes)..orderBy([(t) => OrderingTerm.asc(t.key)])).get();
  }

  Future<Note?> getNote(String key) {
    return (select(notes)..where((t) => t.key.equals(key))).getSingleOrNull();
  }

  Future<void> saveNote(NotesCompanion note) {
    return into(notes).insertOnConflictUpdate(note);
  }

  Future<bool> deleteNote(String key) {
    return (delete(
      notes,
    )..where((t) => t.key.equals(key))).go().then((rows) => rows > 0);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    return NativeDatabase.memory();
  });
}
