import 'package:dio/dio.dart';

class GitHubRelease {
  final String tagName;
  final String name;
  final String body;
  final List<GitHubAsset> assets;
  final String publishedAt;

  GitHubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.assets,
    required this.publishedAt,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) => GitHubRelease(
        tagName: json['tag_name'] as String,
        name: json['name'] as String,
        body: json['body'] as String,
        assets: (json['assets'] as List)
            .map((a) => GitHubAsset.fromJson(a as Map<String, dynamic>))
            .toList(),
        publishedAt: json['published_at'] as String,
      );
}

class GitHubAsset {
  final String name;
  final String browserDownloadUrl;
  final int size;

  GitHubAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.size,
  });

  factory GitHubAsset.fromJson(Map<String, dynamic> json) => GitHubAsset(
        name: json['name'] as String,
        browserDownloadUrl: json['browser_download_url'] as String,
        size: json['size'] as int,
      );
}

class GitHubApi {
  final Dio _dio;
  final String _repo;

  GitHubApi({required String repo, Dio? dio})
      : _repo = repo,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.github.com',
              headers: {'Accept': 'application/vnd.github.v3+json'},
            ));

  Future<GitHubRelease> getLatestRelease() async {
    final response =
        await _dio.get<dynamic>('/repos/$_repo/releases/latest');
    return GitHubRelease.fromJson(response.data as Map<String, dynamic>);
  }
}
