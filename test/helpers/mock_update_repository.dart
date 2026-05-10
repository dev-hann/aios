import 'package:aios/domain/entities/update_info.dart';
import 'package:aios/domain/repositories/update_repository.dart';

class MockUpdateRepository implements UpdateRepository {
  UpdateResult checkResult;
  String? downloadPath;
  bool installResult;
  String? lastDownloadUrl;
  String? lastFileName;
  final List<double> progressReports = [];
  List<double> downloadProgressSequence;

  MockUpdateRepository({
    UpdateResult? checkResult,
    this.downloadPath,
    this.installResult = true,
    this.downloadProgressSequence = const [0.25, 0.5, 1.0],
  }) : checkResult = checkResult ?? const UpdateResult.notAvailable();

  @override
  Future<UpdateResult> checkForUpdate() async => checkResult;

  @override
  Future<String?> downloadApk(
    String url,
    String fileName, {
    void Function(double progress)? onProgress,
  }) async {
    lastDownloadUrl = url;
    lastFileName = fileName;
    if (onProgress != null) {
      for (final p in downloadProgressSequence) {
        onProgress(p);
        progressReports.add(p);
      }
    }
    return downloadPath;
  }

  @override
  Future<bool> installApk(String apkPath) async => installResult;
}
