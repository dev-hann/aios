import 'package:aios/domain/agent/user_message_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserMessageMapper', () {
    test('map_modelNotFound_returnsModelNotFound', () {
      final result = UserMessageMapper.map(
        'Exception: Model not found at path',
      );
      expect(result, 'AI 모델을 찾을 수 없습니다. 설정에서 모델을 가져오세요.');
    });

    test('map_modelLoadFailure_returnsModelLoadFailure', () {
      final result = UserMessageMapper.map(
        'Failed to load model: corrupted file',
      );
      expect(result, 'AI 모델 로드에 실패했습니다. 다른 모델 파일을 시도해보세요.');
    });

    test('map_permissionDenied_returnsPermissionDenied', () {
      final result = UserMessageMapper.map(
        'Permission denied for accessibility',
      );
      expect(result, '권한이 필요합니다. 설정 > 앱 > AIOS > 권한에서 허용하세요.');
    });

    test('map_networkError_returnsNetworkError', () {
      final result = UserMessageMapper.map('Network connection failed');
      expect(result, '네트워크 연결 오류입니다. 인터넷 연결을 확인하세요.');
    });

    test('map_timeout_returnsTimeout', () {
      final result = UserMessageMapper.map('Request timeout after 30s');
      expect(result, '요청 시간이 초과되었습니다. 다시 시도해주세요.');
    });

    test('map_cancelled_returnsCancelled', () {
      final result = UserMessageMapper.map('Operation was cancelled by user');
      expect(result, '작업이 취소되었습니다.');
    });

    test('map_storageError_returnsStorageError', () {
      final result = UserMessageMapper.map('Storage permission denied');
      expect(result, '저장소 권한이 필요합니다. 설정 > 앱 > AIOS > 권한에서 허용하세요.');
    });

    test('map_appNotFound_returnsAppNotFound', () {
      final result = UserMessageMapper.map(
        'Error: app not installed: com.youtube',
      );
      expect(result, '해당 앱이 설치되어 있지 않습니다.');
    });

    test('map_serviceUnavailable_returnsServiceUnavailable', () {
      final result = UserMessageMapper.map(
        'Accessibility service is not enabled',
      );
      expect(result, '접근성 서비스가 활성화되지 않았습니다. 설정 > 접근성에서 활성화하세요.');
    });

    test('map_unknownError_returnsGenericMessage', () {
      final result = UserMessageMapper.map('Something weird happened');
      expect(result, '예상치 못한 오류가 발생했습니다. 다시 시도해주세요.');
    });

    test('map_emptyString_returnsGenericMessage', () {
      final result = UserMessageMapper.map('');
      expect(result, '예상치 못한 오류가 발생했습니다. 다시 시도해주세요.');
    });

    test('map_noModelLoaded_returnsModelMessage', () {
      final result = UserMessageMapper.map(
        'No model loaded. Please load a model first.',
      );
      expect(result, 'AI 모델 로드에 실패했습니다. 다른 모델 파일을 시도해보세요.');
    });

    test('map_contextOverflow_returnsContextMessage', () {
      final result = UserMessageMapper.map(
        'Context window exceeded maximum tokens',
      );
      expect(result, '응답이 너무 깁니다. 최대 토큰 수를 줄이거나 새 대화를 시작하세요.');
    });

    test('map_smsError_returnsSmsMessage', () {
      final result = UserMessageMapper.map('Error: Failed to send SMS');
      expect(result, 'SMS를 보낼 수 없습니다. 신호와 권한을 확인하세요.');
    });

    test('map_callError_returnsCallMessage', () {
      final result = UserMessageMapper.map('Error: Failed to make phone call');
      expect(result, '전화를 걸 수 없습니다. 권한을 확인하세요.');
    });
  });
}
