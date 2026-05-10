import 'package:aios/domain/entities/update_info.dart';
import 'package:aios/presentation/providers/update_notifier.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_update_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  group('UpdateNotifier', () {
    late MockUpdateRepository mockRepo;
    late UpdateNotifier notifier;

    setUp(() {
      mockRepo = MockUpdateRepository();
      notifier = UpdateNotifier(mockRepo, '1.0.0');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'checkPermissionStatus') {
              return 1;
            }
            if (methodCall.method == 'requestPermissions') {
              return {13: 1};
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, null);
    });

    test('initial_state_isIdle', () {
      expect(notifier.state.status, UpdateStatus.idle);
      expect(notifier.state.updateInfo, isNull);
      expect(notifier.state.downloadProgress, 0.0);
      expect(notifier.state.downloadedFilePath, isNull);
      expect(notifier.state.errorMessage, isNull);
    });

    test('checkForUpdate_transitionsToAvailable', () async {
      final info = UpdateInfo(
        currentVersion: '1.0.0',
        latestVersion: '2.0.0',
        downloadUrl: 'https://example.com/aios.apk',
        fileSize: 50000000,
        releaseNotes: 'Bug fixes',
        publishedAt: DateTime(2025),
      );
      mockRepo.checkResult = UpdateResult.success(info);

      await notifier.checkForUpdate();

      expect(notifier.state.status, UpdateStatus.available);
      expect(notifier.state.updateInfo, isNotNull);
      expect(notifier.state.updateInfo!.latestVersion, '2.0.0');
    });

    test('checkForUpdate_transitionsToNotAvailable', () async {
      mockRepo.checkResult = const UpdateResult.notAvailable();

      await notifier.checkForUpdate();

      expect(notifier.state.status, UpdateStatus.notAvailable);
    });

    test('checkForUpdate_transitionsToErrorOnFailure', () async {
      mockRepo.checkResult = const UpdateResult.error('Network error');

      await notifier.checkForUpdate();

      expect(notifier.state.status, UpdateStatus.error);
      expect(notifier.state.errorMessage, 'Network error');
    });

    test('checkForUpdate_clearsPreviousErrorMessage', () async {
      mockRepo.checkResult = const UpdateResult.error('Network error');
      await notifier.checkForUpdate();
      expect(notifier.state.errorMessage, 'Network error');

      mockRepo.checkResult = const UpdateResult.notAvailable();
      await notifier.checkForUpdate();
      expect(notifier.state.errorMessage, isNull);
    });

    test('downloadApk_reportsProgressAndCompletes', () async {
      mockRepo.checkResult = UpdateResult.success(
        UpdateInfo(
          currentVersion: '1.0.0',
          latestVersion: '2.0.0',
          downloadUrl: 'https://example.com/aios.apk',
          fileSize: 50000000,
          releaseNotes: 'Bug fixes',
          publishedAt: DateTime(2025),
        ),
      );
      mockRepo.downloadPath = '/tmp/test-apk.apk';

      await notifier.checkForUpdate();
      await notifier.downloadApk();

      expect(notifier.state.status, UpdateStatus.downloaded);
      expect(notifier.state.downloadedFilePath, '/tmp/test-apk.apk');
      expect(mockRepo.progressReports, [0.25, 0.5, 1.0]);
    });

    test('downloadApk_transitionsToErrorWhenDownloadFails', () async {
      mockRepo.checkResult = UpdateResult.success(
        UpdateInfo(
          currentVersion: '1.0.0',
          latestVersion: '2.0.0',
          downloadUrl: 'https://example.com/aios.apk',
          fileSize: 50000000,
          releaseNotes: 'Bug fixes',
          publishedAt: DateTime(2025),
        ),
      );
      mockRepo.downloadPath = null;

      await notifier.checkForUpdate();
      await notifier.downloadApk();

      expect(notifier.state.status, UpdateStatus.error);
      expect(notifier.state.errorMessage, '다운로드 실패');
    });

    test('downloadApk_doesNothingWhenNoUpdateInfo', () async {
      await notifier.downloadApk();

      expect(notifier.state.status, UpdateStatus.idle);
    });

    test('installApk_transitionsToInstalled', () async {
      mockRepo.checkResult = UpdateResult.success(
        UpdateInfo(
          currentVersion: '1.0.0',
          latestVersion: '2.0.0',
          downloadUrl: 'https://example.com/aios.apk',
          fileSize: 50000000,
          releaseNotes: 'Bug fixes',
          publishedAt: DateTime(2025),
        ),
      );
      mockRepo.downloadPath = '/tmp/test-apk.apk';

      await notifier.checkForUpdate();
      await notifier.downloadApk();
      await notifier.installApk();

      expect(notifier.state.status, UpdateStatus.installed);
    });

    test('installApk_transitionsToErrorWhenInstallFails', () async {
      mockRepo.checkResult = UpdateResult.success(
        UpdateInfo(
          currentVersion: '1.0.0',
          latestVersion: '2.0.0',
          downloadUrl: 'https://example.com/aios.apk',
          fileSize: 50000000,
          releaseNotes: 'Bug fixes',
          publishedAt: DateTime(2025),
        ),
      );
      mockRepo.downloadPath = '/tmp/test-apk.apk';
      mockRepo.installResult = false;

      await notifier.checkForUpdate();
      await notifier.downloadApk();
      await notifier.installApk();

      expect(notifier.state.status, UpdateStatus.error);
      expect(notifier.state.errorMessage, '설치 실패');
    });

    test('installApk_doesNothingWhenNoDownloadedFile', () async {
      await notifier.installApk();

      expect(notifier.state.status, UpdateStatus.idle);
    });

    test('installApk_transitionsToErrorWhenPermissionDenied', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'checkPermissionStatus') {
              return 0;
            }
            if (methodCall.method == 'requestPermissions') {
              return {13: 0};
            }
            return null;
          });

      mockRepo.checkResult = UpdateResult.success(
        UpdateInfo(
          currentVersion: '1.0.0',
          latestVersion: '2.0.0',
          downloadUrl: 'https://example.com/aios.apk',
          fileSize: 50000000,
          releaseNotes: 'Bug fixes',
          publishedAt: DateTime(2025),
        ),
      );
      mockRepo.downloadPath = '/tmp/test-apk.apk';

      await notifier.checkForUpdate();
      await notifier.downloadApk();
      await notifier.installApk();

      expect(notifier.state.status, UpdateStatus.error);
      expect(notifier.state.errorMessage, contains('설치 권한'));
    });

    test('reset_returnsToIdle', () async {
      mockRepo.checkResult = const UpdateResult.error('fail');
      await notifier.checkForUpdate();
      expect(notifier.state.status, UpdateStatus.error);

      notifier.reset();

      expect(notifier.state.status, UpdateStatus.idle);
      expect(notifier.state.errorMessage, isNull);
    });
  });
}
