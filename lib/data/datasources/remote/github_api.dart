import 'package:dio/dio.dart';

String _asString(dynamic value) {
  if (value is String) return value;
  throw FormatException('Expected String, got ${value.runtimeType}');
}

int _asInt(dynamic value) {
  if (value is int) return value;
  throw FormatException('Expected int, got ${value.runtimeType}');
}

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
  throw FormatException('Expected List, got ${value.runtimeType}');
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  throw FormatException(
    'Expected Map<String, dynamic>, got ${value.runtimeType}',
  );
}

class GitHubRelease {
  GitHubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.assets,
    required this.publishedAt,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) => GitHubRelease(
    tagName: _asString(json['tag_name']),
    name: _asString(json['name']),
    body: _asString(json['body']),
    assets: _asList(
      json['assets'],
    ).map((a) => GitHubAsset.fromJson(_asMap(a))).toList(),
    publishedAt: _asString(json['published_at']),
  );

  final String tagName;
  final String name;
  final String body;
  final List<GitHubAsset> assets;
  final String publishedAt;
}

class GitHubAsset {
  GitHubAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.size,
  });

  factory GitHubAsset.fromJson(Map<String, dynamic> json) => GitHubAsset(
    name: _asString(json['name']),
    browserDownloadUrl: _asString(json['browser_download_url']),
    size: _asInt(json['size']),
  );

  final String name;
  final String browserDownloadUrl;
  final int size;
}

class GitHubApi {
  GitHubApi({required String repo, Dio? dio})
    : _repo = repo,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.github.com',
              headers: {'Accept': 'application/vnd.github.v3+json'},
            ),
          );

  final Dio _dio;
  final String _repo;

  Future<GitHubRelease> getLatestRelease() async {
    final response = await _dio.get<dynamic>('/repos/$_repo/releases/latest');
    return GitHubRelease.fromJson(_asMap(response.data));
  }
}
