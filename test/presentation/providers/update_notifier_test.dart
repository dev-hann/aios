import 'dart:io';

import 'package:aios/domain/entities/update_info.dart';
import 'package:aios/domain/repositories/update_repository.dart';
import 'package:aios/presentation/providers/update_notifier.dart';

import 'package:flutter_test/flutter_test.dart';

class _MockUpdateRepository implements UpdateRepository {
  UpdateResult? _checkResult;
  File? _downloadResult;
  bool _installResult = true;
  final List<double> _progressReports = [];
  bool _canInstall = true;

  void setCheckResult(UpdateResult result) => _checkResult = result;
  void setDownloadResult(File? file) => _downloadResult = file;
  void setInstallResult(bool success) => _installResult = success;
  void setCanInstall(bool value) => _canInstall = value;
  List<double> get progressReports => _progressReports;

  @override
  Future<UpdateResult> checkForUpdate() async => _checkResult!;

  @override
  Future<File?> downloadApk(
    String url,
    String fileName, {
    void Function(double progress)? onProgress,
  }) async {
    if (onProgress != null) {
      onProgress(0.25);
      _progressReports.add(0.25);
      onProgress(0.5);
      _progressReports.add(0.5);
      onProgress(1.0);
      _progressReports.add(1.0);
    }
    return _downloadResult;
  }

  @override
  bool canInstallApk() => _canInstall;

  @override
  bool installApk(File apkFile) => _installResult;
}

void main() {
  group('UpdateNotifier', () {
    late _MockUpdateRepository mockRepo;
    late UpdateNotifier notifier;

    setUp(() {
      mockRepo = _MockUpdateRepository();
      notifier = UpdateNotifier(mockRepo, '1.0.0');
    });

    test('initial_state_isIdle', () {
      expect(notifier.state.status, UpdateStatus.idle);
      expect(notifier.state.updateInfo, isNull);
      expect(notifier.state.downloadProgress, 0.0);
      expect(notifier.state.downloadedFile, isNull);
      expect(notifier.state.errorMessage, isNull);
    });

    test('checkForUpdate_transitionsToAvailable', () async {
      final info = UpdateInfo(
        currentVersion: '1.0.0',
        latestVersion: '2.0.0',
        downloadUrl: 'https://example.com/aios.apk',
        fileSize: 50000000,
        releaseNotes: 'Bug fixes',
        publishedAt: DateTime(2025, 1, 1),
      );
      mockRepo.setCheckResult(UpdateResult.success(info));

      await notifier.checkForUpdate();

      expect(notifier.state.status, UpdateStatus.available);
      expect(notifier.state.updateInfo, isNotNull);
      expect(notifier.state.updateInfo!.latestVersion, '2.0.0');
    });

    test('checkForUpdate_transitionsToNotAvailable', () async {
      mockRepo.setCheckResult(const UpdateResult.notAvailable());

      await notifier.checkForUpdate();

      expect(notifier.state.status, UpdateStatus.notAvailable);
    });

    test('checkForUpdate_transitionsToErrorOnFailure', () async {
      mockRepo.setCheckResult(const UpdateResult.error('Network error'));

      await notifier.checkForUpdate();

      expect(notifier.state.status, UpdateStatus.error);
      expect(notifier.state.errorMessage, 'Network error');
    });

    test('checkForUpdate_clearsPreviousErrorMessage', () async {
      mockRepo.setCheckResult(const UpdateResult.error('Network error'));
      await notifier.checkForUpdate();
      expect(notifier.state.errorMessage, 'Network error');

      mockRepo.setCheckResult(const UpdateResult.notAvailable());
      await notifier.checkForUpdate();
      expect(notifier.state.errorMessage, isNull);
    });

    test('downloadApk_reportsProgressAndCompletes', () async {
      final tempFile = File('/tmp/test-apk.apk');
      mockRepo.setCheckResult(UpdateResult.success(UpdateInfo(
        currentVersion: '1.0.0',
        latestVersion: '2.0.0',
        downloadUrl: 'https://example.com/aios.apk',
        fileSize: 50000000,
        releaseNotes: 'Bug fixes',
        publishedAt: DateTime(2025, 1, 1),
      )));
      mockRepo.setDownloadResult(tempFile);

      await notifier.checkForUpdate();
      await notifier.downloadApk();

      expect(notifier.state.status, UpdateStatus.downloaded);
      expect(notifier.state.downloadedFile, tempFile);
      expect(mockRepo.progressReports, [0.25, 0.5, 1.0]);
    });

    test('downloadApk_transitionsToErrorWhenDownloadFails', () async {
      mockRepo.setCheckResult(UpdateResult.success(UpdateInfo(
        currentVersion: '1.0.0',
        latestVersion: '2.0.0',
        downloadUrl: 'https://example.com/aios.apk',
        fileSize: 50000000,
        releaseNotes: 'Bug fixes',
        publishedAt: DateTime(2025, 1, 1),
      )));
      mockRepo.setDownloadResult(null);

      await notifier.checkForUpdate();
      await notifier.downloadApk();

      expect(notifier.state.status, UpdateStatus.error);
      expect(notifier.state.errorMessage, 'Download failed');
    });

    test('downloadApk_doesNothingWhenNoUpdateInfo', () async {
      await notifier.downloadApk();

      expect(notifier.state.status, UpdateStatus.idle);
    });

    test('installApk_triggersInstall', () async {
      final tempFile = File('/tmp/test-apk.apk');
      mockRepo.setCheckResult(UpdateResult.success(UpdateInfo(
        currentVersion: '1.0.0',
        latestVersion: '2.0.0',
        downloadUrl: 'https://example.com/aios.apk',
        fileSize: 50000000,
        releaseNotes: 'Bug fixes',
        publishedAt: DateTime(2025, 1, 1),
      )));
      mockRepo.setDownloadResult(tempFile);

      await notifier.checkForUpdate();
      await notifier.downloadApk();
      await notifier.installApk();

      expect(notifier.state.status, UpdateStatus.installing);
    });

    test('installApk_transitionsToErrorWhenInstallFails', () async {
      final tempFile = File('/tmp/test-apk.apk');
      mockRepo.setCheckResult(UpdateResult.success(UpdateInfo(
        currentVersion: '1.0.0',
        latestVersion: '2.0.0',
        downloadUrl: 'https://example.com/aios.apk',
        fileSize: 50000000,
        releaseNotes: 'Bug fixes',
        publishedAt: DateTime(2025, 1, 1),
      )));
      mockRepo.setDownloadResult(tempFile);
      mockRepo.setInstallResult(false);

      await notifier.checkForUpdate();
      await notifier.downloadApk();
      await notifier.installApk();

      expect(notifier.state.status, UpdateStatus.error);
      expect(notifier.state.errorMessage, 'Install failed');
    });

    test('installApk_doesNothingWhenNoDownloadedFile', () async {
      await notifier.installApk();

      expect(notifier.state.status, UpdateStatus.idle);
    });

    test('reset_returnsToIdle', () async {
      mockRepo.setCheckResult(const UpdateResult.error('fail'));
      await notifier.checkForUpdate();
      expect(notifier.state.status, UpdateStatus.error);

      notifier.reset();

      expect(notifier.state.status, UpdateStatus.idle);
      expect(notifier.state.errorMessage, isNull);
    });
  });
}
