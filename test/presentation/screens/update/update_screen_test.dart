import 'dart:async';
import 'dart:io';

import 'package:aios/domain/entities/update_info.dart';
import 'package:aios/domain/repositories/update_repository.dart';
import 'package:aios/presentation/providers/update_notifier.dart';
import 'package:aios/presentation/providers/update_provider.dart';

import 'package:aios/presentation/screens/update/update_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockUpdateRepository implements UpdateRepository {
  UpdateResult _checkResult = const UpdateResult.notAvailable();
  File? _downloadResult;
  bool _installResult = true;
  Completer<UpdateResult>? _checkCompleter;
  Completer<File?>? _downloadCompleter;

  void setCheckResult(UpdateResult result) => _checkResult = result;
  void setDownloadResult(File? file) => _downloadResult = file;
  void setInstallResult(bool success) => _installResult = success;

  void useCheckCompleter() {
    _checkCompleter = Completer<UpdateResult>();
  }

  void completeCheck() {
    _checkCompleter!.complete(_checkResult);
  }

  void useDownloadCompleter() {
    _downloadCompleter = Completer<File?>();
  }

  void completeDownload() {
    _downloadCompleter!.complete(_downloadResult);
  }

  @override
  Future<UpdateResult> checkForUpdate() async {
    if (_checkCompleter != null) {
      return _checkCompleter!.future;
    }
    return _checkResult;
  }

  @override
  Future<File?> downloadApk(
    String url,
    String fileName, {
    void Function(double progress)? onProgress,
  }) async {
    if (_downloadCompleter != null) {
      if (onProgress != null) {
        onProgress(0.5);
      }
      return _downloadCompleter!.future;
    }
    if (onProgress != null) {
      onProgress(1.0);
    }
    return _downloadResult;
  }

  @override
  Future<bool> installApk(File apkFile) async => _installResult;
}

Widget _createTestWidget({
  required _MockUpdateRepository mockRepo,
}) {
  return ProviderScope(
    overrides: [
      updateRepositoryProvider.overrideWithValue(mockRepo),
      currentVersionProvider.overrideWithValue('1.0.0'),
      updateProvider.overrideWith(
        (ref) => UpdateNotifier(mockRepo, '1.0.0'),
      ),
    ],
    child: const MaterialApp(
      home: UpdateScreen(),
    ),
  );
}

UpdateInfo _testUpdateInfo() => UpdateInfo(
      currentVersion: '1.0.0',
      latestVersion: '2.0.0',
      downloadUrl: 'https://example.com/aios.apk',
      fileSize: 50000000,
      releaseNotes: 'Bug fixes',
      publishedAt: DateTime(2025, 1, 1),
    );

void main() {
  group('UpdateScreen', () {
    testWidgets('shows_checkButton_whenIdle', (tester) async {
      final mockRepo = _MockUpdateRepository();
      await tester.pumpWidget(_createTestWidget(mockRepo: mockRepo));

      expect(find.text('Check for Update'), findsOneWidget);
      expect(find.text('v1.0.0'), findsOneWidget);
    });

    testWidgets('shows_progressIndicator_whenChecking', (tester) async {
      final mockRepo = _MockUpdateRepository();
      mockRepo.useCheckCompleter();
      mockRepo.setCheckResult(const UpdateResult.notAvailable());
      await tester.pumpWidget(_createTestWidget(mockRepo: mockRepo));

      await tester.tap(find.text('Check for Update'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      mockRepo.completeCheck();
      await tester.pumpAndSettle();
    });

    testWidgets('shows_downloadButton_whenAvailable', (tester) async {
      final mockRepo = _MockUpdateRepository();
      mockRepo.setCheckResult(UpdateResult.success(_testUpdateInfo()));

      await tester.pumpWidget(_createTestWidget(mockRepo: mockRepo));

      await tester.tap(find.text('Check for Update'));
      await tester.pumpAndSettle();

      expect(find.text('Download'), findsOneWidget);
      expect(find.text('v2.0.0'), findsOneWidget);
    });

    testWidgets('shows_linearProgress_whenDownloading', (tester) async {
      final mockRepo = _MockUpdateRepository();
      mockRepo.setCheckResult(UpdateResult.success(_testUpdateInfo()));
      mockRepo.useDownloadCompleter();
      mockRepo.setDownloadResult(File('/tmp/test.apk'));

      await tester.pumpWidget(_createTestWidget(mockRepo: mockRepo));

      await tester.tap(find.text('Check for Update'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Download'));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      mockRepo.completeDownload();
      await tester.pumpAndSettle();
    });

    testWidgets('shows_installButton_whenDownloaded', (tester) async {
      final mockRepo = _MockUpdateRepository();
      mockRepo.setCheckResult(UpdateResult.success(_testUpdateInfo()));
      mockRepo.setDownloadResult(File('/tmp/test.apk'));

      await tester.pumpWidget(_createTestWidget(mockRepo: mockRepo));

      await tester.tap(find.text('Check for Update'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();

      expect(find.text('Install'), findsOneWidget);
    });

    testWidgets('shows_upToDate_whenNotAvailable', (tester) async {
      final mockRepo = _MockUpdateRepository();
      mockRepo.setCheckResult(const UpdateResult.notAvailable());

      await tester.pumpWidget(_createTestWidget(mockRepo: mockRepo));

      await tester.tap(find.text('Check for Update'));
      await tester.pumpAndSettle();

      expect(find.text('Already up to date'), findsOneWidget);
    });

    testWidgets('shows_errorMessage_onFailure', (tester) async {
      final mockRepo = _MockUpdateRepository();
      mockRepo.setCheckResult(const UpdateResult.error('Network error'));

      await tester.pumpWidget(_createTestWidget(mockRepo: mockRepo));

      await tester.tap(find.text('Check for Update'));
      await tester.pumpAndSettle();

      expect(find.text('Network error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
