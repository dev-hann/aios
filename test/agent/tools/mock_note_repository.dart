import 'package:aios/domain/repositories/note_repository.dart';

class MockNoteRepository implements NoteRepository {
  final Map<String, String> _notes = {};

  void seed(Map<String, String> notes) {
    _notes.addAll(notes);
  }

  void setNote(String key, String value) {
    _notes[key] = value;
  }

  bool containsKey(String key) => _notes.containsKey(key);

  String? operator [](String key) => _notes[key];

  @override
  Future<void> save(String key, String value) async {
    _notes[key] = value;
  }

  @override
  Future<String?> get(String key) async {
    return _notes[key];
  }

  @override
  Future<Map<String, String>> getAll() async {
    return Map.from(_notes);
  }

  @override
  Future<bool> delete(String key) async {
    return _notes.remove(key) != null;
  }
}
