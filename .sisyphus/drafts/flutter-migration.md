# AIOS Flutter 마이그레이션 - 요구사항 문서

## 1. 전환 배경 및 목표
- **이유**: 개발 생산성 향상 (Hot Reload, 단일 코드베이스)
- **목표**: Kotlin/Android 네이티브 → Flutter 완전 전환
- **기존 코드 처리**: `android/` 디렉토리를 완전히 새 Flutter 프로젝트로 교체

## 2. 아키텍처 핵심 변경

| 항목 | 기존 (Kotlin) | 신규 (Flutter) |
|------|---------------|----------------|
| UI | Jetpack Compose | Flutter Widgets |
| 상태관리 | StateFlow + Hilt DI | Riverpod |
| 라우팅 | Navigation Compose | GoRouter |
| LLM 추론 | 온디바이스 (llama.cpp JNI) | 외부 서버 API (멀티 프로바이더) |
| DI | Hilt (@Binds, @Singleton) | Riverpod (Provider) |
| 네이티브 연동 | JNI (C++) | Platform Channels (Kotlin) |
| 테스트 | JUnit + Espresso | Flutter test + widget test |

## 3. MVP 범위 (1차 구현)

### IN (포함)
- **채팅 UI**: 메시지 버블, 입력바, 스트리밍 응답
- **LLM API 연동**: 멀티 프로바이더 지원 (OpenAI, Anthropic, Google Gemini)
- **설정 화면**: API 키 설정, 프로바이더/모델 선택
- **대화 저장**: 로컬 영속성 (SQLite/Hive)
- **업데이트 시스템**: GitHub Releases 기반 자동 업데이트
- **Clean Architecture**: domain / data / presentation 엄격한 레이어 분리

### OUT (후속 구현)
- 화면 제어 Tools (ScreenAction, ScreenReader, ScreenFind)
- 통신 Tools (SmsSender, PhoneCaller, ContactSearch)
- 기타 Tools (AppLauncher, NotificationTool, SmartWait)
- Risk Classifier (위험도 분류)
- ConfirmationGate (사용자 승인 게이트)
- Overlay UI (다른 앱 위에 표시)
- NotificationListener (알림 읽기)

## 4. 기술 스택

### Flutter/Dart
- **상태관리**: Riverpod (AsyncNotifier, StateNotifier)
- **라우팅**: GoRouter (선언적 라우팅, Deep link)
- **로컬 DB**: TBD (SQLite via drift, 또는 Hive)
- **HTTP**: dio (스트리밍 SSE 지원)
- **테스트**: flutter_test (unit + widget)

### Android 네이티브 (Platform Channels)
- AIOSAccessibilityService (화면 제어 - 후순위)
- NotificationListener (알림 읽기 - 후순위)
- OverlayService (오버레이 - 후순위)
- ServiceRegistry (서비스 관리 - 후순위)

### 제거되는 것
- `native/llama.cpp` 서브모듈
- C++ JNI 코드 (native-lib.cpp, crash-handler.cpp)
- LlamaBridge.kt, LlmService.kt (Foreground Service)
- Hilt DI 모듈 전체
- Kotlin Compose UI 전체

## 5. 플랫폼 전략
- **1차**: Android만 지원
- **향후**: iOS 지원 확장 가능성 (단 Accessibility는 Android 전용)

## 6. 디렉토리 구조 (Clean Architecture)
```
lib/
├── domain/           # 비즈니스 로직, 외부 의존성 없음
│   ├── entities/     # 도메인 모델
│   ├── repositories/ # Repository 인터페이스
│   └── usecases/     # UseCase 클래스
├── data/             # Repository 구현체, 외부 API
│   ├── repositories/
│   ├── datasources/  # 로컬/리모트 데이터소스
│   ├── models/       # DTO, JSON 모델
│   └── providers/    # LLM 프로바이더 구현
├── presentation/     # UI 계층
│   ├── screens/      # 화면 (chat/, settings/, update/)
│   ├── widgets/      # 재사용 위젯
│   └── providers/    # Riverpod Provider
├── core/             # 공통 유틸, 상수, 테마
└── main.dart
```

## 7. 현재 프로젝트 현황
- Kotlin 파일: 97개
- AIOS 전용 C++: 2개
- Android 서비스: 4개
- 확장 툴: 10개
- UI 스크린: 3개 (Chat, Settings, Update)
- 테스트 파일: ~20개
- Flutter 코드: 없음 (pubspec.yaml 미존재)
