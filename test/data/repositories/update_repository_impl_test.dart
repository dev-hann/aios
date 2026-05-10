import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_file/open_file.dart';

import 'package:aios/data/datasources/remote/github_api.dart';
import 'package:aios/data/repositories/update_repository_impl.dart';
import 'package:aios/domain/entities/update_info.dart';

class _FakeGitHubApi extends GitHubApi {
  GitHubRelease? _releaseToReturn;
  Object? _errorToThrow;

  _FakeGitHubApi() : super(repo: 'test/test');

  @override
  Future<GitHubRelease> getLatestRelease() async {
    if (_errorToThrow != null) {
      throw _errorToThrow!;
    }
    if (_releaseToReturn != null) {
      return _releaseToReturn!;
    }
    throw StateError('No release configured');
  }
}

class _FakeDownloadAdapter implements HttpClientAdapter {
  final Uint8List _bytes;

  _FakeDownloadAdapter(List<int> bytes) : _bytes = Uint8List.fromList(bytes);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody(
      Stream.fromIterable([_bytes]),
      200,
      headers: {
        'content-length': [_bytes.length.toString()],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ErrorDownloadAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }

  @override
  void close({bool force = false}) {}
}

GitHubRelease _release({
  String tag = 'v2.1.0',
  String name = 'AIOS v2.1.0',
  String body = 'Bug fixes',
}) {
  return GitHubRelease(
    tagName: tag,
    name: name,
    body: body,
    assets: [
      GitHubAsset(
        name: 'app-release.apk',
        browserDownloadUrl:
            'https://github.com/example/aios/releases/download/$tag/app-release.apk',
        size: 50000000,
      ),
    ],
    publishedAt: '2026-05-01T00:00:00Z',
  );
}

void main() {
  group('UpdateRepositoryImpl', () {
    late _FakeGitHubApi api;
    late Directory tempDir;

    setUp(() async {
      api = _FakeGitHubApi();
      tempDir = await Directory.systemTemp.createTemp('aios_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    UpdateRepositoryImpl _repo({
      Future<OpenResult> Function(String)? openFile,
    }) {
      return UpdateRepositoryImpl(
        api: api,
        currentVersion: '2.0.0',
        dio: Dio(),
        getCachePath: () async => tempDir.path,
        openFile: openFile,
      );
    }

    test('checkForUpdate_returnsSuccess_whenNewerVersion', () async {
      api._releaseToReturn = _release(tag: 'v2.1.0');
      final repo = _repo();

      final result = await repo.checkForUpdate();

      expect(result, isA<UpdateSuccess>());
      result.when(
        success: (info) {
          expect(info.latestVersion, '2.1.0');
          expect(info.currentVersion, '2.0.0');
          expect(info.downloadUrl, contains('app-release.apk'));
          expect(info.fileSize, 50000000);
          expect(info.releaseNotes, 'Bug fixes');
        },
        notAvailable: () => fail('Expected UpdateSuccess'),
        error: (_) => fail('Expected UpdateSuccess'),
      );
    });

    test('checkForUpdate_returnsNotAvailable_whenSameVersion', () async {
      api._releaseToReturn = _release(tag: 'v2.0.0');
      final repo = _repo();

      final result = await repo.checkForUpdate();

      expect(result, isA<UpdateNotAvailable>());
    });

    test('checkForUpdate_returnsError_whenApiFails', () async {
      api._errorToThrow = DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      );
      final repo = _repo();

      final result = await repo.checkForUpdate();

      expect(result, isA<UpdateError>());
      result.when(
        success: (_) => fail('Expected UpdateError'),
        notAvailable: () => fail('Expected UpdateError'),
        error: (msg) => expect(msg, isNotEmpty),
      );
    });

    test('downloadApk_returnsFile', () async {
      final fakeBytes = [1, 2, 3, 4, 5];
      final dio = Dio();
      dio.httpClientAdapter = _FakeDownloadAdapter(fakeBytes);
      final repo = UpdateRepositoryImpl(
        api: api,
        currentVersion: '2.0.0',
        dio: dio,
        getCachePath: () async => tempDir.path,
      );

      final result = await repo.downloadApk(
        'https://example.com/app.apk',
        'app.apk',
      );

      expect(result, isNotNull);
      expect(await File(result!).exists(), isTrue);
      expect(await File(result).readAsBytes(), fakeBytes);
    });

    test('downloadApk_reportsProgress', () async {
      final fakeBytes = List.generate(100, (i) => i);
      final dio = Dio();
      dio.httpClientAdapter = _FakeDownloadAdapter(fakeBytes);
      final repo = UpdateRepositoryImpl(
        api: api,
        currentVersion: '2.0.0',
        dio: dio,
        getCachePath: () async => tempDir.path,
      );

      final progressCalls = <double>[];
      final result = await repo.downloadApk(
        'https://example.com/app.apk',
        'app.apk',
        onProgress: progressCalls.add,
      );

      expect(result, isNotNull);
      expect(progressCalls, isNotEmpty);
      expect(progressCalls.last, greaterThanOrEqualTo(0.0));
    });

    test('installApk_existingFile_returnsTrue', () async {
      final file = File('${tempDir.path}/test.apk');
      await file.writeAsBytes([1, 2, 3]);

      final repo = _repo(
        openFile: (path) async => OpenResult(type: ResultType.done),
      );

      expect(await repo.installApk(file.path), isTrue);
    });

    test('installApk_nonExistentFile_returnsFalse', () async {
      final file = File('${tempDir.path}/nonexistent.apk');
      final repo = _repo();

      expect(await repo.installApk(file.path), isFalse);
    });

    test('installApk_returnsFalse_whenOpenFileFails', () async {
      final file = File('${tempDir.path}/test.apk');
      await file.writeAsBytes([1, 2, 3]);

      final repo = _repo(
        openFile: (path) async =>
            OpenResult(type: ResultType.error, message: 'denied'),
      );

      expect(await repo.installApk(file.path), isFalse);
    });

    test('installApk_returnsFalse_onException', () async {
      final file = File('${tempDir.path}/test.apk');
      await file.writeAsBytes([1, 2, 3]);

      final repo = _repo(openFile: (path) async => throw Exception('boom'));

      expect(await repo.installApk(file.path), isFalse);
    });

    test('checkForUpdate_noApkAsset_returnsError', () async {
      api._releaseToReturn = GitHubRelease(
        tagName: 'v2.1.0',
        name: 'AIOS v2.1.0',
        body: 'Release',
        assets: [
          GitHubAsset(
            name: 'readme.txt',
            browserDownloadUrl: 'https://example.com/readme.txt',
            size: 100,
          ),
        ],
        publishedAt: '2026-05-01T00:00:00Z',
      );
      final repo = _repo();

      final result = await repo.checkForUpdate();

      expect(result, isA<UpdateError>());
      result.when(
        success: (_) => fail('Expected UpdateError'),
        notAvailable: () => fail('Expected UpdateError'),
        error: (msg) => expect(msg, contains('No APK')),
      );
    });

    test('downloadApk_error_returnsNull', () async {
      final dio = Dio();
      dio.httpClientAdapter = _ErrorDownloadAdapter();
      final repo = UpdateRepositoryImpl(
        api: api,
        currentVersion: '2.0.0',
        dio: dio,
        getCachePath: () async => tempDir.path,
      );

      final result = await repo.downloadApk(
        'https://example.com/bad.apk',
        'bad.apk',
      );

      expect(result, isNull);
    });
  });
}
