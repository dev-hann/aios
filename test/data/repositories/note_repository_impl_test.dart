import 'dart:ffi';

import 'package:aios/data/datasources/local/database.dart';
import 'package:aios/data/repositories/note_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

AppDatabase createTestDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

DynamicLibrary _openOnLinux() {
  return DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0');
}

void main() {
  open.overrideFor(OperatingSystem.linux, _openOnLinux);

  group('NoteRepositoryImpl', () {
    late AppDatabase db;
    late NoteRepositoryImpl repository;

    setUp(() {
      db = createTestDatabase();
      repository = NoteRepositoryImpl(db);
    });

    tearDown(() async {
      await db.deleteAllData();
      await db.close();
    });

    group('save_and_get', () {
      test('save_storesNote_getRetrievesIt', () async {
        await repository.save('test', 'hello');
        final value = await repository.get('test');
        expect(value, 'hello');
      });

      test('save_overwritesExisting', () async {
        await repository.save('test', 'old');
        await repository.save('test', 'new');
        final value = await repository.get('test');
        expect(value, 'new');
      });

      test('get_nonExistent_returnsNull', () async {
        final value = await repository.get('missing');
        expect(value, isNull);
      });
    });

    group('getAll', () {
      test('getAll_empty_returnsEmptyMap', () async {
        final notes = await repository.getAll();
        expect(notes, isEmpty);
      });

      test('getAll_returnsAllNotes', () async {
        await repository.save('a', 'alpha');
        await repository.save('b', 'beta');
        final notes = await repository.getAll();
        expect(notes, {'a': 'alpha', 'b': 'beta'});
      });
    });

    group('delete', () {
      test('delete_existing_returnsTrue', () async {
        await repository.save('test', 'hello');
        final result = await repository.delete('test');
        expect(result, isTrue);
        final value = await repository.get('test');
        expect(value, isNull);
      });

      test('delete_nonExistent_returnsFalse', () async {
        final result = await repository.delete('missing');
        expect(result, isFalse);
      });
    });

    group('persistence', () {
      test('notes_surviveAcrossInstances', () async {
        await repository.save('persist', 'value');
        final repo2 = NoteRepositoryImpl(db);
        final value = await repo2.get('persist');
        expect(value, 'value');
      });
    });
  });
}
