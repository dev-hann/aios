import 'package:aios/domain/entities/update_info.dart';
import 'package:aios/domain/repositories/update_repository.dart';
import 'package:aios/presentation/providers/update_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier(this._updateRepository, this._currentVersion)
    : super(const UpdateState());
  static const String _tag = 'AIOS-Update';

  final UpdateRepository _updateRepository;
  final String _currentVersion;

  Future<void> checkForUpdate() async {
    state = state.copyWith(status: UpdateStatus.checking, errorMessage: null);
    print('[$_tag] Checking for update (current: $_currentVersion)...');

    final result = await _updateRepository.checkForUpdate();
    result.when(
      success: (info) {
        print('[$_tag] Update available: ${info.latestVersion}');
        state = state.copyWith(
          status: UpdateStatus.available,
          updateInfo: info,
        );
      },
      notAvailable: () {
        print('[$_tag] No update available');
        state = state.copyWith(status: UpdateStatus.notAvailable);
      },
      error: (msg) {
        print('[$_tag] ERROR: checkForUpdate failed: $msg');
        state = state.copyWith(status: UpdateStatus.error, errorMessage: msg);
      },
    );
  }

  Future<void> downloadApk() async {
    if (state.updateInfo == null) return;
    state = state.copyWith(
      status: UpdateStatus.downloading,
      downloadProgress: 0,
    );
    print('[$_tag] Downloading APK...');

    final file = await _updateRepository.downloadApk(
      state.updateInfo!.downloadUrl,
      'aios-update.apk',
      onProgress: (p) => state = state.copyWith(downloadProgress: p),
    );

    if (file != null) {
      print('[$_tag] Download complete');
      state = state.copyWith(
        status: UpdateStatus.downloaded,
        downloadedFilePath: file,
      );
    } else {
      print('[$_tag] ERROR: Download failed');
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: '다운로드 실패',
      );
    }
  }

  Future<void> installApk() async {
    if (state.downloadedFilePath == null) return;
    state = state.copyWith(status: UpdateStatus.installing);
    print('[$_tag] Installing APK...');

    final installStatus = await Permission.requestInstallPackages.status;
    if (!installStatus.isGranted) {
      print('[$_tag] Requesting install packages permission');
      final result = await Permission.requestInstallPackages.request();
      if (!result.isGranted) {
        print('[$_tag] ERROR: Install permission denied');
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage:
              '설치 권한이 필요합니다. 설정 > 앱 > 특수 앱 접근 > 출처를 알 수 없는 앱에서 허용해주세요.',
        );
        return;
      }
    }

    final success = await _updateRepository.installApk(
      state.downloadedFilePath!,
    );
    if (success) {
      print('[$_tag] Install intent launched');
      state = state.copyWith(status: UpdateStatus.installed);
    } else {
      print('[$_tag] ERROR: Install failed');
      state = state.copyWith(status: UpdateStatus.error, errorMessage: '설치 실패');
    }
  }

  void reset() {
    state = const UpdateState();
  }
}
