import 'dart:developer' as developer;
import 'dart:io';

import 'package:aios/domain/entities/model_info.dart';
import 'package:aios/domain/repositories/model_repository.dart';

class ModelRepositoryImpl implements ModelRepository {
  const ModelRepositoryImpl({
    required this.modelsDir,
    required this.downloadsDir,
  });

  final String modelsDir;
  final String downloadsDir;

  @override
  List<ModelInfo> scanModels() {
    final dir = Directory(modelsDir);
    if (!dir.existsSync()) {
      return [];
    }

    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.gguf'))
        .map((f) => ModelInfo(
              name: f.path.split(Platform.pathSeparator).last,
              size: f.lengthSync(),
              path: f.path,
            ))
        .toList();
  }

  @override
  List<ModelInfo> scanExternalDirs() {
    final externalDirs = [
      '/sdcard/Download',
      '/storage/emulated/0/Download',
    ];
    final seen = <String>{};
    final results = <ModelInfo>[];

    for (final dirPath in externalDirs) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      try {
        for (final f in dir.listSync().whereType<File>()) {
          if (!f.path.toLowerCase().endsWith('.gguf')) continue;
          final name = f.path.split(Platform.pathSeparator).last;
          if (seen.contains(name)) continue;
          seen.add(name);
          results.add(ModelInfo(
            name: f.path.split(Platform.pathSeparator).last,
            size: f.lengthSync(),
            path: f.path,
          ));
        }
      } on Object catch (e) {
        developer.log(
          'scanExternalDirs failed for $dirPath: $e',
          name: 'AIOS-ModelRepo',
          level: 900,
        );
      }
    }

    return results;
  }

  @override
  bool restoreModel(String name) {
    final source = File('$downloadsDir${Platform.pathSeparator}$name');
    if (!source.existsSync()) {
      return false;
    }

    final dest = File('$modelsDir${Platform.pathSeparator}$name');
    source.copySync(dest.path);
    return true;
  }

  @override
  Future<bool> importModelFromUri(String sourcePath, String fileName) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      return false;
    }

    final dir = Directory(modelsDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final dest = File('$modelsDir${Platform.pathSeparator}$fileName');
    await source.copy(dest.path);
    return true;
  }
}
