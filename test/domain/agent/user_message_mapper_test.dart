import 'package:aios/domain/agent/user_message_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserMessageMapper', () {
    test('map_modelNotFound_returnsModelNotFound', () {
      final result = UserMessageMapper.map(
        'Exception: Model not found at path',
      );
      expect(result, contains('model'));
    });

    test('map_modelLoadFailure_returnsModelLoadFailure', () {
      final result = UserMessageMapper.map(
        'Failed to load model: corrupted file',
      );
      expect(result, contains('model'));
    });

    test('map_permissionDenied_returnsPermissionDenied', () {
      final result = UserMessageMapper.map(
        'Permission denied for accessibility',
      );
      expect(result, contains('Permission'));
    });

    test('map_networkError_returnsNetworkError', () {
      final result = UserMessageMapper.map(
        'Network connection failed',
      );
      expect(result.toLowerCase(), contains('network'));
    });

    test('map_timeout_returnsTimeout', () {
      final result = UserMessageMapper.map(
        'Request timeout after 30s',
      );
      expect(result, contains('time'));
    });

    test('map_cancelled_returnsCancelled', () {
      final result = UserMessageMapper.map(
        'Operation was cancelled by user',
      );
      expect(result, contains('cancel'));
    });

    test('map_storageError_returnsStorageError', () {
      final result = UserMessageMapper.map(
        'Storage permission denied',
      );
      expect(result, contains('Storage'));
    });

    test('map_appNotFound_returnsAppNotFound', () {
      final result = UserMessageMapper.map(
        'Error: app not installed: com.youtube',
      );
      expect(result, contains('app'));
    });

    test('map_serviceUnavailable_returnsServiceUnavailable', () {
      final result = UserMessageMapper.map(
        'Accessibility service is not enabled',
      );
      expect(result, contains('service'));
    });

    test('map_unknownError_returnsGenericMessage', () {
      final result = UserMessageMapper.map(
        'Something weird happened',
      );
      expect(result, contains('error'));
    });

    test('map_emptyString_returnsGenericMessage', () {
      final result = UserMessageMapper.map('');
      expect(result, contains('error'));
    });

    test('map_noModelLoaded_returnsModelMessage', () {
      final result = UserMessageMapper.map(
        'No model loaded. Please load a model first.',
      );
      expect(result, contains('model'));
    });

    test('map_contextOverflow_returnsContextMessage', () {
      final result = UserMessageMapper.map(
        'Context window exceeded maximum tokens',
      );
      expect(result, contains('too long'));
    });

    test('map_smsError_returnsSmsMessage', () {
      final result = UserMessageMapper.map(
        'Error: Failed to send SMS',
      );
      expect(result, contains('SMS'));
    });

    test('map_callError_returnsCallMessage', () {
      final result = UserMessageMapper.map(
        'Error: Failed to make phone call',
      );
      expect(result, contains('call'));
    });
  });
}
