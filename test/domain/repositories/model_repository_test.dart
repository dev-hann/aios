import 'package:aios/domain/entities/model_info.dart';
import 'package:aios/domain/repositories/model_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockModelRepository implements ModelRepository {
  final List<ModelInfo> _models = [];

  void addTestModel(ModelInfo model) {
    _models.add(model);
  }

  @override
  List<ModelInfo> scanModels() {
    return List.unmodifiable(_models);
  }

  @override
  bool restoreModel(String name) {
    return _models.any((m) => m.name == name);
  }

  @override
  Future<bool> importModelFromUri(String sourcePath, String fileName) async {
    _models.add(ModelInfo(
      name: fileName,
      size: 1024,
      path: sourcePath,
    ));
    return true;
  }

  @override
  List<ModelInfo> scanExternalDirs() => [];
}

void main() {
  group('ModelRepository', () {
    late _MockModelRepository repository;

    setUp(() {
      repository = _MockModelRepository();
    });

    test('scanModels_returnsEmptyList_whenNoModels', () {
      final models = repository.scanModels();

      expect(models.isEmpty, isTrue);
    });

    test('scanModels_returnsImportedModels', () async {
      await repository.importModelFromUri('/path/a.gguf', 'a.gguf');
      await repository.importModelFromUri('/path/b.gguf', 'b.gguf');

      final models = repository.scanModels();

      expect(models.length, 2);
      expect(models[0].name, 'a.gguf');
      expect(models[1].name, 'b.gguf');
    });

    test('importModelFromUri_returnsTrue', () async {
      final result = await repository.importModelFromUri(
        '/path/model.gguf',
        'model.gguf',
      );

      expect(result, isTrue);
    });

    test('restoreModel_returnsTrue_whenModelExists', () async {
      await repository.importModelFromUri('/path/model.gguf', 'model.gguf');

      final result = repository.restoreModel('model.gguf');

      expect(result, isTrue);
    });

    test('restoreModel_returnsFalse_whenModelNotFound', () {
      final result = repository.restoreModel('nonexistent.gguf');

      expect(result, isFalse);
    });
  });
}
