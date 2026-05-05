import 'package:aios/domain/entities/model_info.dart';

abstract class ModelRepository {
  List<ModelInfo> scanModels();
  List<ModelInfo> scanExternalDirs();
  bool restoreModel(String name);
  Future<bool> importModelFromUri(String sourcePath, String fileName);
}
