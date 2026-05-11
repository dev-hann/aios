# AIOS ROADMAP

## 최종 목표

사용자가 자연어로 Android 폰을 완전히 제어할 수 있는 AI 에이전트.
React + TypeScript (Gyo Framework) 기반 WebView 앱.

## 기능 목록

### F01: app_launcher — 앱 실행
- Gyo Bridge → PackageManager 연동 필요
- 앱 이름(한글/영문) → package_name 매칭
- URL 감지 및 브라우저 실행

### F02: screen_action — 화면 제어
- Gyo Bridge → AccessibilityService 연동 필요
- tap, long_click, type, scroll, swipe, global actions

### F03: screen_reader — 화면 읽기
- Gyo Bridge → AccessibilityService 연동 필요
- 화면 전체 텍스트, 특정 영역/버튼 텍스트

### F04: notification — 알림
- Gyo Bridge → NotificationListenerService 연동 필요
- 알림 목록/내용 읽기

### F05: sms_sender — SMS 전송
- Gyo Bridge → SmsManager 연동 필요
- 위험도 CRITICAL (사용자 승인 필수)

### F06: phone_caller — 전화
- Gyo Bridge → TelephonyManager 연동 필요
- 위험도 CRITICAL

### F07: contact_search — 연락처
- Gyo Bridge → ContactsProvider 연동 필요

### F08: calculator — 수학 계산 ✅
- **활성** (순수 TS)
- 사칙연산, 퍼센트, 제곱근

### F09: notepad — 메모 ✅
- **활성** (순수 TS)
- 메모 작성/조회/목록/삭제

### F10: timer — 타이머/알람 ✅
- **활성** (순수 TS)
- 타이머 설정/확인/취소/목록

### F11: device_info — 기기 정보
- Gyo Bridge → Build/Settings 연동 필요

### F12: multi-tool chaining ✅
- ReAct 루프에서 자동 처리
- LoopDetector로 무한 루프 방지

### F13: context awareness ✅
- ConversationContext: 최근 5턴 대화 기록
- ToolPreferenceTracker: 자주 사용하는 Tool top 3

### F14: error recovery ✅
- ErrorRecovery: 8가지 에러 타입 분류
- 복구 힌트 주입, 재시도 추적

### F15: UX polish
- 로딩 상태 표시
- 스트리밍 응답 시 토큰 단위 표시
- 다크 테마 안정화

### F16: 백그라운드 모드
- 플로팅 버튼 오버레이
- Gyo Bridge → SYSTEM_ALERT_WINDOW 필요

## 마일스톤

| 마일스톤 | 기능 | 설명 | 상태 |
|-----------|------|------|------|
| M1 | — | Gyo 마이그레이션 (React+TS+WebView) | **완성** |
| M2 | F08, F09, F10 | 순수 TS Tool 3개 | **완성** |
| M3 | F12, F13, F14 | 에이전트 지능 (ReAct 루프) | **완성** |
| M4 | F15 | UX 마무리 | **완성** |
| M5 | F01 | Gyo Bridge + app_launcher | **예정** |
| M6 | F02, F03 | Gyo Bridge + 화면 제어/읽기 | **예정** |
| M7 | F04-F07, F11 | Gyo Bridge + 커뮤니케이션/기기 | **예정** |
| M8 | F16 | 백그라운드 플로팅 어시스턴트 | **예정** |
