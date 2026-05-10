class UserMessageMapper {
  const UserMessageMapper._();

  static String map(String error) {
    final lower = error.toLowerCase();

    if (lower.contains('model') && lower.contains('not found')) {
      return 'AI 모델을 찾을 수 없습니다. 설정에서 모델을 가져오세요.';
    }
    if (lower.contains('model') && lower.contains('not loaded')) {
      return 'AI 모델이 로드되지 않았습니다. 설정에서 모델을 로드하세요.';
    }
    if (lower.contains('model') &&
        (lower.contains('load') || lower.contains('corrupt'))) {
      return 'AI 모델 로드에 실패했습니다. 다른 모델 파일을 시도해보세요.';
    }
    if (lower.contains('context') && lower.contains('exceeded')) {
      return '응답이 너무 깁니다. 최대 토큰 수를 줄이거나 새 대화를 시작하세요.';
    }
    if (lower.contains('sms') || lower.contains('message')) {
      return 'SMS를 보낼 수 없습니다. 신호와 권한을 확인하세요.';
    }
    if (lower.contains('call') || lower.contains('phone')) {
      return '전화를 걸 수 없습니다. 권한을 확인하세요.';
    }
    if (lower.contains('app') && lower.contains('not installed')) {
      return '해당 앱이 설치되어 있지 않습니다.';
    }
    if (lower.contains('accessibility') && lower.contains('service')) {
      return '접근성 서비스가 활성화되지 않았습니다. 설정 > 접근성에서 활성화하세요.';
    }
    if (lower.contains('service') && lower.contains('not enabled')) {
      return '필수 서비스가 활성화되지 않았습니다. 설정을 확인하세요.';
    }
    if (lower.contains('permission') && lower.contains('storage')) {
      return '저장소 권한이 필요합니다. 설정 > 앱 > AIOS > 권한에서 허용하세요.';
    }
    if (lower.contains('permission')) {
      return '권한이 필요합니다. 설정 > 앱 > AIOS > 권한에서 허용하세요.';
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return '네트워크 연결 오류입니다. 인터넷 연결을 확인하세요.';
    }
    if (lower.contains('timeout')) {
      return '요청 시간이 초과되었습니다. 다시 시도해주세요.';
    }
    if (lower.contains('cancel')) {
      return '작업이 취소되었습니다.';
    }

    return '예상치 못한 오류가 발생했습니다. 다시 시도해주세요.';
  }
}
