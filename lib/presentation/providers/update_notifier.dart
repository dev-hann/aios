import 'dart:developer' as developer;
import 'dart:io';

import 'package:aios/domain/entities/update_info.dart';
import 'package:aios/domain/repositories/update_repository.dart';
import 'package:aios/presentation/providers/update_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateNotifier extends StateNotifier<UpdateState> {
  static const String _tag = 'AIOS-Update';

  UpdateNotifier(this._updateRepository, this._currentVersion)
      : super(const UpdateState());

  final UpdateRepository _updateRepository;
  final String _currentVersion;

  Future<void> checkForUpdate() async {
    state = state.copyWith(status: UpdateStatus.checking, errorMessage: null);
    developer.log(
      'Checking for update (current: $_currentVersion)...',
      name: _tag,
    );

    final result = await _updateRepository.checkForUpdate();
    result.when(
      success: (info) {
        developer.log(
          'Update available: ${info.latestVersion}',
          name: _tag,
        );
        state = state.copyWith(
          status: UpdateStatus.available,
          updateInfo: info,
        );
      },
      notAvailable: () {
        developer.log('No update available', name: _tag);
        state = state.copyWith(status: UpdateStatus.notAvailable);
      },
      error: (msg) {
        developer.log(
          'checkForUpdate failed: $msg',
          name: _tag,
          level: 1000,
        );
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: msg,
        );
      },
    );
  }

  Future<void> downloadApk() async {
    if (state.updateInfo == null) return;
    state = state.copyWith(
      status: UpdateStatus.downloading,
      downloadProgress: 0,
    );
    developer.log('Downloading APK...', name: _tag);

    final file = await _updateRepository.downloadApk(
      state.updateInfo!.downloadUrl,
      'aios-update.apk',
      onProgress: (p) => state = state.copyWith(downloadProgress: p),
    );

    if (file != null) {
      developer.log('Download complete', name: _tag);
      state = state.copyWith(
        status: UpdateStatus.downloaded,
        downloadedFilePath: file.path,
      );
    } else {
      developer.log('Download failed', name: _tag, level: 1000);
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Download failed',
      );
    }
  }

  Future<void> installApk() async {
    if (state.downloadedFilePath == null) return;
    state = state.copyWith(status: UpdateStatus.installing);
    developer.log('Installing APK...', name: _tag);

    final installStatus = await Permission.requestInstallPackages.status;
    if (!installStatus.isGranted) {
      developer.log('Requesting install packages permission', name: _tag);
      final result = await Permission.requestInstallPackages.request();
      if (!result.isGranted) {
        developer.log(
          'Install permission denied',
          name: _tag,
          level: 1000,
        );
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage:
              '설치 권한이 필요합니다. 설정 > 앱 > 특수 앱 접근 > 출처를 알 수 없는 앱에서 허용해주세요.',
        );
        return;
      }
    }

    final file = File(state.downloadedFilePath!);
    final success = await _updateRepository.installApk(file);
    if (success) {
      developer.log('Install intent launched', name: _tag);
      state = state.copyWith(status: UpdateStatus.installed);
    } else {
      developer.log('Install failed', name: _tag, level: 1000);
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Install failed',
      );
    }
  }

  void reset() {
    state = const UpdateState();
  }
}
