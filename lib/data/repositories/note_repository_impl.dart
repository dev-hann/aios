import 'package:aios/data/datasources/local/database.dart';
import 'package:aios/domain/repositories/note_repository.dart';
import 'package:drift/drift.dart';

class NoteRepositoryImpl implements NoteRepository {
  NoteRepositoryImpl(this._db);

  final AppDatabase _db;

  static const _tag = 'AIOS-NoteRepo';

  @override
  Future<void> save(String key, String value) async {
    try {
      await _db.saveNote(
        NotesCompanion.insert(
          key: key,
          value: value,
          updatedAt: Value(DateTime.now()),
        ),
      );
    } on Object catch (e) {
      print('[$_tag] ERROR: save failed - $e');
      rethrow;
    }
  }

  @override
  Future<String?> get(String key) async {
    try {
      final note = await _db.getNote(key);
      return note?.value;
    } on Object catch (e) {
      print('[$_tag] ERROR: get failed - $e');
      return null;
    }
  }

  @override
  Future<Map<String, String>> getAll() async {
    try {
      final noteList = await _db.getAllNotes();
      return {for (final n in noteList) n.key: n.value};
    } on Object catch (e) {
      print('[$_tag] ERROR: getAll failed - $e');
      return {};
    }
  }

  @override
  Future<bool> delete(String key) async {
    try {
      return _db.deleteNote(key);
    } on Object catch (e) {
      print('[$_tag] ERROR: delete failed - $e');
      return false;
    }
  }
}
