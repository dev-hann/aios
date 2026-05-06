import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_info.g.dart';
part 'update_info.freezed.dart';

enum UpdateStatus {
  idle,
  checking,
  available,
  notAvailable,
  downloading,
  downloaded,
  installing,
  installed,
  error,
}

@freezed
class UpdateInfo with _$UpdateInfo {
  const factory UpdateInfo({
    required String currentVersion,
    required String latestVersion,
    required String downloadUrl,
    required int fileSize,
    required String releaseNotes,
    required DateTime publishedAt,
  }) = _UpdateInfo;

  factory UpdateInfo.fromJson(Map<String, dynamic> json) =>
      _$UpdateInfoFromJson(json);
}

@Freezed()
sealed class UpdateResult with _$UpdateResult {
  const factory UpdateResult.success(UpdateInfo info) = UpdateSuccess;
  const factory UpdateResult.notAvailable() = UpdateNotAvailable;
  const factory UpdateResult.error(String message) = UpdateError;
}
