import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:aios/data/datasources/remote/github_api.dart';
import 'package:aios/domain/entities/update_info.dart';
import 'package:aios/domain/repositories/update_repository.dart';

class UpdateRepositoryImpl implements UpdateRepository {
  final GitHubApi _api;
  final String _currentVersion;
  final Dio _dio;
  final Future<String> Function() _getCachePath;

  UpdateRepositoryImpl({
    required GitHubApi api,
    required String currentVersion,
    required Dio dio,
    Future<String> Function()? getCachePath,
  })  : _api = api,
        _currentVersion = currentVersion,
        _dio = dio,
        _getCachePath = getCachePath ?? _defaultCachePath;

  static Future<String> _defaultCachePath() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  @override
  Future<UpdateResult> checkForUpdate() async {
    try {
      final release = await _api.getLatestRelease();
      final latestVersion = _stripVersionPrefix(release.tagName);
      final currentVersion = _stripVersionPrefix(_currentVersion);

      if (_compareVersions(latestVersion, currentVersion) <= 0) {
        return const UpdateResult.notAvailable();
      }

      final apkAsset = release.assets.firstWhere(
        (a) => a.name.endsWith('.apk'),
        orElse: () => release.assets.first,
      );

      return UpdateResult.success(UpdateInfo(
        currentVersion: _currentVersion,
        latestVersion: latestVersion,
        downloadUrl: apkAsset.browserDownloadUrl,
        fileSize: apkAsset.size,
        releaseNotes: release.body,
        publishedAt: DateTime.parse(release.publishedAt),
      ));
    } catch (e) {
      developer.log(
        'checkForUpdate failed: $e',
        name: 'AIOS-UpdateRepo',
        level: 1000,
      );
      return UpdateResult.error(e.toString());
    }
  }

  @override
  Future<File?> downloadApk(
    String url,
    String fileName, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final cachePath = await _getCachePath();
      final savePath = '$cachePath/$fileName';

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      final file = File(savePath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      developer.log(
        'downloadApk failed: $e',
        name: 'AIOS-UpdateRepo',
        level: 1000,
      );
      return null;
    }
  }

  @override
  bool canInstallApk() {
    return true;
  }

  @override
  bool installApk(File apkFile) {
    return apkFile.existsSync();
  }

  String _stripVersionPrefix(String version) {
    if (version.startsWith('v')) {
      return version.substring(1);
    }
    return version;
  }

  int _compareVersions(String a, String b) {
    final partsA = a.split('.').map(int.parse).toList();
    final partsB = b.split('.').map(int.parse).toList();

    for (var i = 0; i < partsA.length || i < partsB.length; i++) {
      final valA = i < partsA.length ? partsA[i] : 0;
      final valB = i < partsB.length ? partsB[i] : 0;
      if (valA != valB) {
        return valA.compareTo(valB);
      }
    }
    return 0;
  }
}
