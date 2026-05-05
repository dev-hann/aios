import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aios/data/datasources/remote/github_api.dart';

class _FakeAdapter implements HttpClientAdapter {
  final int statusCode;
  final Map<String, dynamic> body;
  Object? error;

  _FakeAdapter({
    this.statusCode = 200,
    required this.body,
    this.error,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (error != null) {
      throw error!;
    }
    final bytes = utf8.encode(jsonEncode(body));
    return ResponseBody(
      Stream.fromIterable([bytes]),
      statusCode,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('GitHubApi', () {
    late Dio dio;
    late GitHubApi api;

    test('getLatestRelease_returnsRelease', () async {
      dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(body: {
        'tag_name': 'v2.1.0',
        'name': 'AIOS v2.1.0',
        'body': 'Bug fixes',
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url':
                'https://github.com/example/aios/releases/download/v2.1.0/app-release.apk',
            'size': 50000000,
          }
        ],
        'published_at': '2026-05-01T00:00:00Z',
      });
      api = GitHubApi(repo: 'example/aios', dio: dio);

      final release = await api.getLatestRelease();

      expect(release.tagName, 'v2.1.0');
      expect(release.name, 'AIOS v2.1.0');
      expect(release.body, 'Bug fixes');
      expect(release.publishedAt, '2026-05-01T00:00:00Z');
    });

    test('getLatestRelease_parsesAssets', () async {
      dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(body: {
        'tag_name': 'v2.1.0',
        'name': 'AIOS v2.1.0',
        'body': 'Bug fixes',
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url':
                'https://github.com/example/aios/releases/download/v2.1.0/app-release.apk',
            'size': 50000000,
          },
          {
            'name': 'app-debug.apk',
            'browser_download_url':
                'https://github.com/example/aios/releases/download/v2.1.0/app-debug.apk',
            'size': 60000000,
          },
        ],
        'published_at': '2026-05-01T00:00:00Z',
      });
      api = GitHubApi(repo: 'example/aios', dio: dio);

      final release = await api.getLatestRelease();

      expect(release.assets.length, 2);
      expect(release.assets[0].name, 'app-release.apk');
      expect(release.assets[0].size, 50000000);
      expect(release.assets[1].name, 'app-debug.apk');
      expect(release.assets[1].browserDownloadUrl,
          'https://github.com/example/aios/releases/download/v2.1.0/app-debug.apk');
    });

    test('getLatestRelease_throwsOn404', () async {
      dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        statusCode: 404,
        body: {'message': 'Not Found'},
      );
      api = GitHubApi(repo: 'example/aios', dio: dio);

      expect(
        () => api.getLatestRelease(),
        throwsA(isA<DioException>()),
      );
    });

    test('getLatestRelease_handlesNetworkError', () async {
      dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        body: {},
        error: DioException.connectionError(
          requestOptions: RequestOptions(),
          reason: 'Connection refused',
        ),
      );
      api = GitHubApi(repo: 'example/aios', dio: dio);

      expect(
        () => api.getLatestRelease(),
        throwsA(isA<DioException>()),
      );
    });
  });
}
