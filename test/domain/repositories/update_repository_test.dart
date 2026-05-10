import 'package:aios/domain/entities/update_info.dart';
import 'package:aios/domain/repositories/update_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockUpdateRepository implements UpdateRepository {
  UpdateResult _nextResult = const UpdateResult.notAvailable();
  String? _downloadedFile;
  bool _installResult = true;

  @override
  Future<UpdateResult> checkForUpdate() async {
    return _nextResult;
  }

  @override
  Future<String?> downloadApk(
    String url,
    String fileName, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);
    onProgress?.call(1.0);
    return _downloadedFile;
  }

  @override
  Future<bool> installApk(String apkPath) async => _installResult;
}

void main() {
  group('UpdateRepository', () {
    late _MockUpdateRepository repository;

    setUp(() {
      repository = _MockUpdateRepository();
    });

    test('checkForUpdate_returnsNotAvailable_byDefault', () async {
      final result = await repository.checkForUpdate();

      expect(result, isA<UpdateNotAvailable>());
    });

    test('checkForUpdate_returnsSuccess_whenUpdateAvailable', () async {
      repository._nextResult = UpdateResult.success(
        UpdateInfo(
          currentVersion: '2.0.0',
          latestVersion: '2.1.0',
          downloadUrl: 'https://example.com/app.apk',
          fileSize: 50000000,
          releaseNotes: 'Bug fixes',
          publishedAt: DateTime(2026, 5, 1),
        ),
      );

      final result = await repository.checkForUpdate();

      expect(result, isA<UpdateSuccess>());
      result.when(
        success: (info) {
          expect(info.latestVersion, '2.1.0');
          expect(info.downloadUrl, 'https://example.com/app.apk');
          expect(info.releaseNotes, 'Bug fixes');
        },
        notAvailable: () => fail('Expected UpdateSuccess'),
        error: (_) => fail('Expected UpdateSuccess'),
      );
    });

    test('checkForUpdate_returnsError_onFailure', () async {
      repository._nextResult = const UpdateResult.error('Network error');

      final result = await repository.checkForUpdate();

      expect(result, isA<UpdateError>());
      result.when(
        success: (_) => fail('Expected UpdateError'),
        notAvailable: () => fail('Expected UpdateError'),
        error: (msg) => expect(msg, 'Network error'),
      );
    });

    test('downloadApk_callsProgress_and_returnsFile', () async {
      final progressCalls = <double>[];
      repository._downloadedFile = '/tmp/test.apk';

      final result = await repository.downloadApk(
        'https://example.com/app.apk',
        'app.apk',
        onProgress: progressCalls.add,
      );

      expect(result, isNotNull);
      expect(progressCalls, [0.5, 1.0]);
    });

    test('downloadApk_returnsNull_whenNoFile', () async {
      final result = await repository.downloadApk(
        'https://example.com/app.apk',
        'app.apk',
      );

      expect(result, isNull);
    });

    test('installApk_returnsTrue_byDefault', () async {
      final result = await repository.installApk('/tmp/test.apk');

      expect(result, isTrue);
    });

    test('installApk_returnsFalse_whenSet', () async {
      repository._installResult = false;

      final result = await repository.installApk('/tmp/test.apk');

      expect(result, isFalse);
    });
  });
}
