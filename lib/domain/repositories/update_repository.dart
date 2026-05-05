import 'dart:io';

import 'package:aios/domain/entities/update_info.dart';

abstract class UpdateRepository {
  Future<UpdateResult> checkForUpdate();
  Future<File?> downloadApk(
    String url,
    String fileName, {
    void Function(double progress)? onProgress,
  });
  bool canInstallApk();
  bool installApk(File apkFile);
}
