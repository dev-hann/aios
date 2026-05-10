abstract class NoteRepository {
  Future<void> save(String key, String value);
  Future<String?> get(String key);
  Future<Map<String, String>> getAll();
  Future<bool> delete(String key);
}
