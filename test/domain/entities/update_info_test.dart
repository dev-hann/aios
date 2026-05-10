import 'package:aios/domain/entities/update_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateStatus', () {
    test('values_containsAllExpectedStatuses', () {
      const statuses = UpdateStatus.values;

      expect(statuses, contains(UpdateStatus.idle));
      expect(statuses, contains(UpdateStatus.checking));
      expect(statuses, contains(UpdateStatus.available));
      expect(statuses, contains(UpdateStatus.notAvailable));
      expect(statuses, contains(UpdateStatus.downloading));
      expect(statuses, contains(UpdateStatus.downloaded));
      expect(statuses, contains(UpdateStatus.installing));
      expect(statuses, contains(UpdateStatus.installed));
      expect(statuses, contains(UpdateStatus.error));
      expect(statuses.length, 9);
    });
  });

  group('UpdateInfo', () {
    final fixedDate = DateTime(2026, 3, 1, 12, 0, 0);

    test('constructor_withAllFields_createsSuccessfully', () {
      final info = UpdateInfo(
        currentVersion: '2.0.0',
        latestVersion: '2.1.0',
        downloadUrl: 'https://github.com/example/aios/releases/v2.1.0',
        fileSize: 50000000,
        releaseNotes: 'Bug fixes and improvements',
        publishedAt: fixedDate,
      );

      expect(info.currentVersion, '2.0.0');
      expect(info.latestVersion, '2.1.0');
      expect(
        info.downloadUrl,
        'https://github.com/example/aios/releases/v2.1.0',
      );
      expect(info.fileSize, 50000000);
      expect(info.releaseNotes, 'Bug fixes and improvements');
      expect(info.publishedAt, fixedDate);
    });

    test('toJson_returnsCorrectMap', () {
      final info = UpdateInfo(
        currentVersion: '2.0.0',
        latestVersion: '2.1.0',
        downloadUrl: 'https://github.com/example/aios/releases/v2.1.0',
        fileSize: 50000000,
        releaseNotes: 'Bug fixes',
        publishedAt: fixedDate,
      );

      final json = info.toJson();

      expect(json['currentVersion'], '2.0.0');
      expect(json['latestVersion'], '2.1.0');
      expect(
        json['downloadUrl'],
        'https://github.com/example/aios/releases/v2.1.0',
      );
      expect(json['fileSize'], 50000000);
      expect(json['releaseNotes'], 'Bug fixes');
    });
  });

  group('UpdateResult', () {
    test('updateResult_success_returnsSuccess', () {
      final info = UpdateInfo(
        currentVersion: '2.0.0',
        latestVersion: '2.1.0',
        downloadUrl: 'https://example.com/app.apk',
        fileSize: 50000000,
        releaseNotes: 'New features',
        publishedAt: DateTime(2026, 3, 1),
      );
      final result = UpdateResult.success(info);

      result.when(
        success: (i) {
          expect(i.latestVersion, '2.1.0');
          expect(i.currentVersion, '2.0.0');
        },
        notAvailable: () => fail('Expected success'),
        error: (_) => fail('Expected success'),
      );
    });

    test('updateResult_notAvailable_returnsNotAvailable', () {
      const result = UpdateResult.notAvailable();

      result.when(
        success: (_) => fail('Expected notAvailable'),
        notAvailable: () {},
        error: (_) => fail('Expected notAvailable'),
      );
    });

    test('updateResult_error_returnsError', () {
      const result = UpdateResult.error('Network error');

      result.when(
        success: (_) => fail('Expected error'),
        notAvailable: () => fail('Expected error'),
        error: (message) {
          expect(message, 'Network error');
        },
      );
    });

    test('updateResult_equality_sameVariant_areEqual', () {
      const a = UpdateResult.notAvailable();
      const b = UpdateResult.notAvailable();

      expect(a, equals(b));
    });
  });
}
