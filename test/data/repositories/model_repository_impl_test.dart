import 'dart:io';

import 'package:aios/data/repositories/model_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelRepositoryImpl', () {
    late Directory modelsDir;
    late Directory downloadsDir;
    late ModelRepositoryImpl repository;

    setUp(() async {
      modelsDir = await Directory.systemTemp.createTemp('aios_models_');
      downloadsDir = await Directory.systemTemp.createTemp('aios_downloads_');
      repository = ModelRepositoryImpl(
        modelsDir: modelsDir.path,
        downloadsDir: downloadsDir.path,
      );
    });

    tearDown(() async {
      if (modelsDir.existsSync()) {
        await modelsDir.delete(recursive: true);
      }
      if (downloadsDir.existsSync()) {
        await downloadsDir.delete(recursive: true);
      }
    });

    test('scanModels_returnsEmptyWhenNoModels', () {
      final models = repository.scanModels();

      expect(models, isEmpty);
    });

    test('scanModels_findsGgufFiles', () async {
      await File('${modelsDir.path}/model1.gguf').writeAsString('fake');
      await File('${modelsDir.path}/model2.gguf').writeAsString('fake');
      await File('${modelsDir.path}/readme.txt').writeAsString('ignore');

      final models = repository.scanModels();

      expect(models.length, 2);
      final names = models.map((m) => m.name).toList();
      expect(names, containsAll(['model1.gguf', 'model2.gguf']));
    });

    test('importModel_copiesFile', () async {
      final sourceFile = await File('${downloadsDir.path}/new_model.gguf')
          .writeAsString('model data');

      final result = await repository.importModelFromUri(
        sourceFile.path,
        'new_model.gguf',
      );

      expect(result, isTrue);
      expect(
        File('${modelsDir.path}/new_model.gguf').existsSync(),
        isTrue,
      );
    });

    test('restoreModel_movesFromDownloads', () async {
      await File('${downloadsDir.path}/backup.gguf').writeAsString('data');
      await File('${modelsDir.path}/backup.gguf').writeAsString('old');

      final result = repository.restoreModel('backup.gguf');

      expect(result, isTrue);
      expect(
        File('${modelsDir.path}/backup.gguf').existsSync(),
        isTrue,
      );
    });
  });
}
