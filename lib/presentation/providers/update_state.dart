import 'package:aios/domain/entities/update_info.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_state.freezed.dart';

@freezed
class UpdateState with _$UpdateState {
  const factory UpdateState({
    @Default(UpdateStatus.idle) UpdateStatus status,
    UpdateInfo? updateInfo,
    @Default(0.0) double downloadProgress,
    String? downloadedFilePath,
    String? errorMessage,
  }) = _UpdateState;
}
