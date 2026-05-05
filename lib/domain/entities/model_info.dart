import 'package:freezed_annotation/freezed_annotation.dart';

part 'model_info.g.dart';
part 'model_info.freezed.dart';

@freezed
class ModelInfo with _$ModelInfo {
  const factory ModelInfo({
    required String name,
    required int size,
    required String path,
  }) = _ModelInfo;

  factory ModelInfo.fromJson(Map<String, dynamic> json) =>
      _$ModelInfoFromJson(json);
}
