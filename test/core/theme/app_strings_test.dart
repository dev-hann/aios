import 'package:aios/core/theme/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Strings.state', () {
    test('idle_returnsKoreanString', () {
      expect(Strings.state.idle, '대기 중');
    });

    test('connecting_returnsKoreanString', () {
      expect(Strings.state.connecting, '연결 중...');
    });

    test('ready_returnsKoreanString', () {
      expect(Strings.state.ready, '준비 완료');
    });

    test('generating_returnsKoreanString', () {
      expect(Strings.state.generating, '생성 중...');
    });

    test('error_returnsKoreanString', () {
      expect(Strings.state.error, '오류');
    });

    test('unknown_returnsKoreanString', () {
      expect(Strings.state.unknown, '알 수 없음');
    });
  });

  group('Strings.permissionCard', () {
    test('needsPermission_containsName', () {
      expect(Strings.permissionCard.needsPermission('연락처'), '연락처 권한이 필요합니다');
    });

    test('later_returnsKoreanString', () {
      expect(Strings.permissionCard.later, '나중에');
    });

    test('goToSettings_returnsKoreanString', () {
      expect(Strings.permissionCard.goToSettings, '설정으로 이동');
    });

    test('grant_returnsKoreanString', () {
      expect(Strings.permissionCard.grant, '허용하기');
    });
  });

  group('Strings.update', () {
    test('downloadFailed_returnsKoreanString', () {
      expect(Strings.update.downloadFailed, '다운로드 실패');
    });

    test('installFailed_returnsKoreanString', () {
      expect(Strings.update.installFailed, '설치 실패');
    });

    test('installPermissionRequired_containsSettingsPath', () {
      expect(
        Strings.update.installPermissionRequired,
        contains('설치 권한이 필요합니다'),
      );
    });
  });

  group('Strings.overlay', () {
    test('processingPrevious_returnsKoreanString', () {
      expect(
        Strings.overlay.processingPrevious,
        '이전 요청을 처리 중입니다. 잠시 후 다시 시도해주세요.',
      );
    });

    test('failedToProcess_returnsKoreanString', () {
      expect(Strings.overlay.failedToProcess, '요청을 처리하지 못했습니다.');
    });

    test('errorOccurred_containsErrorText', () {
      expect(
        Strings.overlay.errorOccurred('test error'),
        '오류가 발생했습니다: test error',
      );
    });
  });

  group('Strings.inferenceNav', () {
    test('summary_formatsTemperatureAndMaxTokens', () {
      expect(Strings.inferenceNav.summary(0.7, 512), '온도 0.7 · 최대토큰 512');
    });
  });

  group('Strings.appInfo', () {
    test('loading_returnsKoreanString', () {
      expect(Strings.appInfo.loading, '로딩 중...');
    });

    test('unknownError_returnsKoreanString', () {
      expect(Strings.appInfo.unknownError, '알 수 없는 오류');
    });
  });

  group('Strings.newConversationTitle', () {
    test('newConversationTitle_isKorean', () {
      expect(Strings.newConversationTitle, '새 대화');
    });
  });

  group('Strings.agentAnswers', () {
    test('failedToProcess_returnsKorean', () {
      expect(Strings.agentAnswers.failedToProcess, '요청을 처리하지 못했습니다.');
    });

    test('loopDetected_returnsKorean', () {
      expect(Strings.agentAnswers.loopDetected, '작업이 반복 감지로 중단되었습니다.');
    });

    test('incomplete_returnsKorean', () {
      expect(Strings.agentAnswers.incomplete, '작업을 완료하지 못했습니다.');
    });

    test('errorOccurred_includesMessage', () {
      expect(Strings.agentAnswers.errorOccurred('test'), '오류가 발생했습니다: test');
    });
  });

  group('Strings.errorRecovery', () {
    test('toolNotFound_returnsKorean', () {
      expect(Strings.errorRecovery.toolNotFound, '요청한 도구를 찾을 수 없습니다.');
    });

    test('appNotInstalled_returnsKorean', () {
      expect(Strings.errorRecovery.appNotInstalled, '해당 앱이 설치되어 있지 않습니다.');
    });

    test('serviceUnavailable_containsSettings', () {
      expect(Strings.errorRecovery.serviceUnavailable, contains('설정'));
    });

    test('permissionDenied_containsSettings', () {
      expect(Strings.errorRecovery.permissionDenied, contains('설정'));
    });

    test('invalidAction_containsRetry', () {
      expect(Strings.errorRecovery.invalidAction, contains('다시 시도'));
    });

    test('missingParameter_returnsKorean', () {
      expect(Strings.errorRecovery.missingParameter, '필수 항목이 누락되었습니다.');
    });

    test('cancelled_returnsKorean', () {
      expect(Strings.errorRecovery.cancelled, '사용자가 작업을 취소했습니다.');
    });

    test('generic_returnsKorean', () {
      expect(Strings.errorRecovery.generic, '오류가 발생했습니다. 다시 시도해주세요.');
    });
  });

  group('Strings.userMessages', () {
    test('modelNotFound_containsModel', () {
      expect(Strings.userMessages.modelNotFound, contains('AI 모델'));
    });

    test('modelNotLoaded_containsModel', () {
      expect(Strings.userMessages.modelNotLoaded, contains('AI 모델'));
    });

    test('modelLoadFailed_containsModel', () {
      expect(Strings.userMessages.modelLoadFailed, contains('AI 모델'));
    });

    test('contextExceeded_containsToken', () {
      expect(Strings.userMessages.contextExceeded, contains('토큰'));
    });

    test('smsFailed_containsSms', () {
      expect(Strings.userMessages.smsFailed, contains('SMS'));
    });

    test('callFailed_containsCall', () {
      expect(Strings.userMessages.callFailed, contains('전화'));
    });

    test('appNotInstalled_returnsKorean', () {
      expect(Strings.userMessages.appNotInstalled, '해당 앱이 설치되어 있지 않습니다.');
    });

    test('accessibilityNotEnabled_containsAccessibility', () {
      expect(Strings.userMessages.accessibilityNotEnabled, contains('접근성'));
    });

    test('serviceNotEnabled_returnsKorean', () {
      expect(Strings.userMessages.serviceNotEnabled, contains('서비스'));
    });

    test('storagePermission_containsStorage', () {
      expect(Strings.userMessages.storagePermission, contains('저장소'));
    });

    test('permissionRequired_containsPermission', () {
      expect(Strings.userMessages.permissionRequired, contains('권한'));
    });

    test('networkError_containsNetwork', () {
      expect(Strings.userMessages.networkError, contains('네트워크'));
    });

    test('timeout_returnsKorean', () {
      expect(Strings.userMessages.timeout, '요청 시간이 초과되었습니다. 다시 시도해주세요.');
    });

    test('cancelled_returnsKorean', () {
      expect(Strings.userMessages.cancelled, '작업이 취소되었습니다.');
    });

    test('unexpected_returnsKorean', () {
      expect(Strings.userMessages.unexpected, '예상치 못한 오류가 발생했습니다. 다시 시도해주세요.');
    });
  });

  group('Strings.permDisplay', () {
    test('contacts_returnsKorean', () {
      expect(Strings.permDisplay.contacts, '연락처');
    });

    test('phone_returnsKorean', () {
      expect(Strings.permDisplay.phone, '전화');
    });

    test('sms_returnsSms', () {
      expect(Strings.permDisplay.sms, 'SMS');
    });

    test('accessibilityService_returnsKorean', () {
      expect(Strings.permDisplay.accessibilityService, '접근성 서비스');
    });

    test('notificationAccess_returnsKorean', () {
      expect(Strings.permDisplay.notificationAccess, '알림 접근');
    });
  });

  group('Strings.provider', () {
    test('baseUrlHint_isValidUrl', () {
      expect(Strings.provider.baseUrlHint, 'https://api.example.com/v1');
      expect(Strings.provider.baseUrlHint, startsWith('https://'));
    });
  });
}
