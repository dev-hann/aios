import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import 'package:aios/data/datasources/remote/github_api.dart';
import 'package:aios/domain/entities/update_info.dart';
import 'package:aios/domain/repositories/update_repository.dart';

class UpdateRepositoryImpl implements UpdateRepository {
  final GitHubApi _api;
  final String _currentVersion;
  final Dio _dio;
  final Future<String> Function() _getCachePath;
  final Future<OpenResult> Function(String path) _openFile;

  UpdateRepositoryImpl({
    required GitHubApi api,
    required String currentVersion,
    required Dio dio,
    Future<String> Function()? getCachePath,
    Future<OpenResult> Function(String path)? openFile,
  }) : _api = api,
       _currentVersion = currentVersion,
       _dio = dio,
       _getCachePath = getCachePath ?? _defaultCachePath,
       _openFile = openFile ?? _defaultOpenFile;

  static Future<String> _defaultCachePath() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  static Future<OpenResult> _defaultOpenFile(String path) {
    return OpenFile.open(path);
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

      final apkAsset = release.assets
          .where((a) => a.name.endsWith('.apk'))
          .firstOrNull;

      if (apkAsset == null) {
        return const UpdateResult.error('No APK asset found in release');
      }

      return UpdateResult.success(
        UpdateInfo(
          currentVersion: _currentVersion,
          latestVersion: latestVersion,
          downloadUrl: apkAsset.browserDownloadUrl,
          fileSize: apkAsset.size,
          releaseNotes: release.body,
          publishedAt: DateTime.parse(release.publishedAt),
        ),
      );
    } catch (e) {
      print('[AIOS-UpdateRepo] ERROR: checkForUpdate failed: $e');
      return UpdateResult.error(e.toString());
    }
  }

  @override
  Future<String?> downloadApk(
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
        return savePath;
      }
      return null;
    } catch (e) {
      print('[AIOS-UpdateRepo] ERROR: downloadApk failed: $e');
      return null;
    }
  }

  @override
  Future<bool> installApk(String apkPath) async {
    final file = File(apkPath);
    if (!await file.exists()) return false;
    try {
      final result = await _openFile(apkPath);
      print('[AIOS-UpdateRepo] open_file result: ${result.type}');
      return result.type == ResultType.done;
    } catch (e) {
      print('[AIOS-UpdateRepo] ERROR: installApk failed: $e');
      return false;
    }
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
