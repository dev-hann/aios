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
}
