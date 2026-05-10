import 'package:aios/domain/entities/llm_provider_config.dart';

class _ChatStrings {
  const _ChatStrings();
  String get inputHint => '메시지를 입력하세요...';
  String get generating => '생성 중...';
  String get send => '전송';
  String get stop => '정지';
  String get thinking => '생각 중...';
  String get clearChat => '대화 지우기';
  String get clearChatConfirm => '모든 메시지를 삭제하시겠습니까?';
  String get cancel => '취소';
  String get clear => '지우기';
  String get confirmAction => '실행 확인';
  String get deny => '거부';
  String get approve => '승인';
  String get tool => '도구';
  String get newConversation => '새 대화';
  String get settingsNeeded => 'AI 설정이 필요합니다';
  String get setupAi => 'AI 설정하기';
  String get whatCanHelp => '무엇을 도와드릴까요?';
  String get retry => '다시 시도';
}

class _DrawerStrings {
  const _DrawerStrings();
  String get noConversations => '대화가 없습니다';
  String get deleteConversation => '대화 삭제';
  String deleteConfirm(String title) => '"$title" 대화를 삭제하시겠습니까?';
  String get delete => '삭제';
  String get settings => '설정';
  String get errorLoadConversations => '대화 목록을 불러올 수 없습니다';
}

class _SettingsStrings {
  const _SettingsStrings();
  String get title => '설정';
  String get provider => 'AI 제공자';
  String get providerSettings => '제공자 설정';
  String get setupProvider => 'AI 설정하기';
  String get connected => '연결됨';
  String get notConnected => '연결 안 됨';
  String get connecting => '연결 중...';
  String get noProvider => 'AI 제공자가 설정되지 않았습니다';
  String get needSetup => 'AI를 사용하려면 설정이 필요합니다';
  String get inference => '추론 설정';
  String get permissions => '권한 관리';
  String get managePermissions => '앱 권한 관리';
  String get appInfo => '앱 정보';
  String get version => '버전';
  String get checkUpdates => '업데이트 확인';
  String get checkingUpdates => '확인 중...';
  String get updateAvailable => '업데이트 가능';
  String get download => '다운로드';
  String get downloading => '다운로드 중...';
  String get installUpdate => '업데이트 설치';
  String get installing => '설치 중...';
  String get updateInstalled => '업데이트 완료 — 앱이 재시작됩니다';
  String get upToDate => '최신 버전입니다';
  String get checkAgain => '다시 확인';
}

class _ProviderStrings {
  const _ProviderStrings();
  String get title => 'AI 제공자 설정';
  String get selectProvider => '제공자 선택';
  String get zai => 'Z.AI (GLM)';
  String get zaiCoding => 'Z.AI (Coding)';
  String get openai => 'OpenAI';
  String get anthropic => 'Anthropic';
  String get custom => 'Custom (OpenAI 호환)';
  String nameForType(LlmProviderType type) => switch (type) {
    LlmProviderType.zai => zai,
    LlmProviderType.zaiCoding => zaiCoding,
    LlmProviderType.openai => openai,
    LlmProviderType.anthropic => anthropic,
    LlmProviderType.custom => custom,
  };
  String get comingSoon => '준비 중';
  String get apiKey => 'API 키';
  String get enterApiKey => 'API 키를 입력하세요';
  String get baseUrl => 'Base URL';
  String get baseUrlHint => 'https://api.example.com/v1';
  String get testConnection => '연결 테스트';
  String get testing => '테스트 중...';
  String get connectionSuccess => '연결 성공!';
  String get connectionFailed => '연결 실패';
  String get model => '모델';
  String get enterApiKeyToLoad => 'API 키를 입력하면 모델을 불러옵니다';
  String get saveConnect => '저장 및 연결';
  String get connectedNotif => '연결되었습니다!';
  String get connectFailed => '연결에 실패했습니다';
  String get requiredFields => 'API 키와 모델을 선택해주세요';
  String get disconnect => '연결 끊기';
}

class _InferenceStrings {
  const _InferenceStrings();
  String get title => '추론 설정';
  String get sampling => '샘플링';
  String get temperature => 'Temperature';
  String get temperatureDesc => '무작위성 제어 (0.0 - 1.0)';
  String get topP => 'Top-P';
  String get topPDesc => '핵 샘플링 임계값';
  String get output => '출력';
  String get maxTokens => '최대 토큰 수';
  String get maxTokensDesc => '응답당 최대 출력 토큰';
  String get agent => '에이전트';
  String get maxIterations => '최대 반복 횟수';
  String get maxIterationsDesc => '에이전트 최대 추론 루프';
  String get resetDefaults => '기본값으로 초기화';
  String get enterValue => '값 입력';
  String get apply => '적용';
}

class _PermissionStrings {
  const _PermissionStrings();
  String get title => '권한';
  String get allGranted => '모든 권한이 허용되었습니다';
  String grantPrompt(int granted, int total) =>
      '모든 기능을 사용하려면 권한을 허용해주세요 ($granted/$total)';
  String get grant => '허용';
  String get storage => '저장소';
  String get storageDesc => '모델 파일 및 데이터 접근';
  String get notifications => '알림';
  String get notificationsDesc => '알림 수신';
  String get contacts => '연락처';
  String get contactsDesc => '연락처 검색';
  String get phone => '전화';
  String get phoneDesc => '전화 걸기';
  String get sms => 'SMS';
  String get smsDesc => '문자 메시지 전송';
  String get accessibility => '접근성';
  String get accessibilityDesc => '에이전트 도구 화면 조작';
  String get couldNotOpenSettings => '설정을 열 수 없습니다';
}

class _LoadingStrings {
  const _LoadingStrings();
  String get initializing => 'AI 엔진 초기화 중...';
  String get loadingModel => 'AI 모델 로딩 중...';
  String get preparing => '작업 공간 준비 중...';
  String get ready => '준비 완료!';
  String get connecting => '서버에 연결 중...';
}

class _SuggestionStrings {
  const _SuggestionStrings();
  String get weather => '오늘 날씨 어때?';
  String get calculator => '123 × 456 계산해줘';
  String get memo => '메모해줘: 내일 회의 2시';
  String get timer => '타이머 5분 설정해줘';
  String get screenshot => '지금 화면 읽어줘';
}

class _AnnotationStrings {
  const _AnnotationStrings();
  String get analyzing => '의도 분석 중...';
  String analyzingRetry(int attempt, int max) => '의도 분석 재시도... ($attempt/$max)';
  String taskRetry(int attempt, int max) => '작업 분석 재시도... ($attempt/$max)';
  String get generatingAnswer => '응답 생성 중...';
  String answerRetry(int attempt, int max) => '응답 재시도... ($attempt/$max)';
  String running(String tool) => '$tool 실행 중...';
  String result(String text) => '결과: $text';
  String failed(String text) => '실패: $text';
  String get emptyResult => '결과: (없음)';
  String get waitingConfirmation => '사용자 확인 대기 중...';
}

class _OverlayStrings {
  const _OverlayStrings();
  String get launchingApp => '앱 실행 중...';
  String get readingScreen => '화면 읽는 중...';
  String get findingOnScreen => '화면에서 요소 찾는 중...';
  String get calculating => '계산 중...';
  String get writingNote => '메모 작성 중...';
  String get settingTimer => '타이머 설정 중...';
  String get smsTask => '문자 관련 작업 중...';
  String get phoneTask => '전화 관련 작업 중...';
  String get searchingContacts => '연락처 검색 중...';
  String get checkingNotifications => '알림 확인 중...';
  String get checkingDeviceInfo => '기기 정보 확인 중...';
  String workingOn(String tool) => '작업 중: $tool';
  String get tappingScreen => '화면 터치 중...';
  String get typingText => '텍스트 입력 중...';
  String get longPressing => '길게 누르는 중...';
  String get scrolling => '스크롤 중...';
  String get swiping => '스와이프 중...';
  String get pressingEnter => 'Enter 키 누르는 중...';
  String get goingBack => '뒤로 가는 중...';
  String get goingHome => '홈으로 이동 중...';
  String get systemAction => '시스템 동작 중...';
  String get manipulatingScreen => '화면 조작 중...';
  String get appLaunched => '앱 실행 완료';
  String get screenDone => '화면 조작 완료';
  String get processingPrevious => '이전 요청을 처리 중입니다. 잠시 후 다시 시도해주세요.';
  String get failedToProcess => '요청을 처리하지 못했습니다.';
  String errorOccurred(String error) => '오류가 발생했습니다: $error';
}

class _StateStrings {
  const _StateStrings();
  String get idle => '대기 중';
  String get connecting => '연결 중...';
  String get ready => '준비 완료';
  String get generating => '생성 중...';
  String get error => '오류';
  String get unknown => '알 수 없음';
}

class _PermissionCardStrings {
  const _PermissionCardStrings();
  String needsPermission(String name) => '$name 권한이 필요합니다';
  String get later => '나중에';
  String get goToSettings => '설정으로 이동';
  String get grant => '허용하기';
}

class _UpdateStrings {
  const _UpdateStrings();
  String get downloadFailed => '다운로드 실패';
  String get installFailed => '설치 실패';
  String get installPermissionRequired =>
      '설치 권한이 필요합니다. 설정 > 앱 > 특수 앱 접근 > '
      '출처를 알 수 없는 앱에서 허용해주세요.';
}

class _InferenceNavStrings {
  const _InferenceNavStrings();
  String summary(double temperature, int maxTokens) =>
      '온도 ${temperature.toStringAsFixed(1)} · 최대토큰 $maxTokens';
}

class _AppInfoStrings {
  const _AppInfoStrings();
  String get loading => '로딩 중...';
  String get unknownError => '알 수 없는 오류';
}

abstract class Strings {
  const Strings._();

  static const appName = 'AIOS';
  static const appSubtitle = 'AI 어시스턴트';
  static const newConversationTitle = '새 대화';

  static const chat = _ChatStrings();
  static const drawer = _DrawerStrings();
  static const settings = _SettingsStrings();
  static const provider = _ProviderStrings();
  static const inference = _InferenceStrings();
  static const permission = _PermissionStrings();
  static const loading = _LoadingStrings();
  static const suggestion = _SuggestionStrings();
  static const annotation = _AnnotationStrings();
  static const overlay = _OverlayStrings();
  static const state = _StateStrings();
  static const permissionCard = _PermissionCardStrings();
  static const update = _UpdateStrings();
  static const inferenceNav = _InferenceNavStrings();
  static const appInfo = _AppInfoStrings();
  static const agentAnswers = _AgentAnswerStrings();
  static const errorRecovery = _ErrorRecoveryStrings();
  static const userMessages = _UserMessageStrings();
  static const permDisplay = _PermDisplayStrings();
  static const agent = _AgentStrings();

  static String daysAgo(int days) => '$days일 전';
}

class _AgentAnswerStrings {
  const _AgentAnswerStrings();
  String get failedToProcess => '요청을 처리하지 못했습니다.';
  String get loopDetected => '작업이 반복 감지로 중단되었습니다.';
  String get incomplete => '작업을 완료하지 못했습니다.';
  String errorOccurred(String error) => '오류가 발생했습니다: $error';
}

class _ErrorRecoveryStrings {
  const _ErrorRecoveryStrings();
  String get toolNotFound => '요청한 도구를 찾을 수 없습니다.';
  String get appNotInstalled => '해당 앱이 설치되어 있지 않습니다.';
  String get serviceUnavailable => '필요한 서비스가 활성화되지 않았습니다.\n설정에서 활성화해주세요.';
  String get permissionDenied => '권한이 거부되었습니다.\n설정에서 권한을 허용해주세요.';
  String get invalidAction => '잘못된 명령입니다.\n올바른 형식으로 다시 시도해주세요.';
  String get missingParameter => '필수 항목이 누락되었습니다.';
  String get cancelled => '사용자가 작업을 취소했습니다.';
  String get generic => '오류가 발생했습니다. 다시 시도해주세요.';
}

class _UserMessageStrings {
  const _UserMessageStrings();
  String get modelNotFound => 'AI 모델을 찾을 수 없습니다. 설정에서 모델을 가져오세요.';
  String get modelNotLoaded => 'AI 모델이 로드되지 않았습니다. 설정에서 모델을 로드하세요.';
  String get modelLoadFailed => 'AI 모델 로드에 실패했습니다. 다른 모델 파일을 시도해보세요.';
  String get contextExceeded => '응답이 너무 깁니다. 최대 토큰 수를 줄이거나 새 대화를 시작하세요.';
  String get smsFailed => 'SMS를 보낼 수 없습니다. 신호와 권한을 확인하세요.';
  String get callFailed => '전화를 걸 수 없습니다. 권한을 확인하세요.';
  String get appNotInstalled => '해당 앱이 설치되어 있지 않습니다.';
  String get accessibilityNotEnabled =>
      '접근성 서비스가 활성화되지 않았습니다. 설정 > 접근성에서 활성화하세요.';
  String get serviceNotEnabled => '필수 서비스가 활성화되지 않았습니다. 설정을 확인하세요.';
  String get storagePermission => '저장소 권한이 필요합니다. 설정 > 앱 > AIOS > 권한에서 허용하세요.';
  String get permissionRequired => '권한이 필요합니다. 설정 > 앱 > AIOS > 권한에서 허용하세요.';
  String get networkError => '네트워크 연결 오류입니다. 인터넷 연결을 확인하세요.';
  String get timeout => '요청 시간이 초과되었습니다. 다시 시도해주세요.';
  String get cancelled => '작업이 취소되었습니다.';
  String get unexpected => '예상치 못한 오류가 발생했습니다. 다시 시도해주세요.';
}

class _PermDisplayStrings {
  const _PermDisplayStrings();
  String get contacts => '연락처';
  String get phone => '전화';
  String get sms => 'SMS';
  String get accessibilityService => '접근성 서비스';
  String get notificationAccess => '알림 접근';
}

class _AgentStrings {
  const _AgentStrings();
  String get setupRequired => 'API 설정을 먼저 완료해주세요.';
  String appNotFound(String input) => "'$input' 앱을 찾을 수 없습니다.";
  String multipleAppsMatch(String input, String candidates) =>
      "'$input'과(와) 일치하는 앱이 여러 개입니다:\n$candidates\n\n"
      '사용자에게 어느 앱을 원하는지 물어보세요.';
  String permissionRequired(String displayName) => '$displayName 권한이 필요합니다';
  String permissionDenied(String displayName) =>
      'Error: $displayName 권한이 거부되었습니다';
}
