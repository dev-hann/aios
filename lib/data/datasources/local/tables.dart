import 'package:drift/drift.dart';

class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant('New Chat'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Notes extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id)();
  TextColumn get role => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get toolName => text().nullable()();
  TextColumn get toolArgs => text().nullable()();
  TextColumn get toolResult => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
