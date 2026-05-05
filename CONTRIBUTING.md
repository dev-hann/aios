# AIOS 기여 가이드

AIOS 프로젝트에 기여해주셔서 감사합니다! 이 문서는 개발 환경 설정부터 PR 제출까지의 워크플로우를 안내합니다.

---

## 1. 개발 환경 설정

### 필수 도구

- **Flutter SDK** 3.41+ (`flutter --version` 확인)
- **Android Studio** (최신 안정 버전) 또는 **VS Code** + Flutter 확장
- **Android SDK**: compileSdk 35, minSdk 26
- **Git**

### Clone & Setup

```bash
git clone https://github.com/hann/aios.git
cd aios
flutter pub get
```

### llama_cpp_dart AAR 설정

온디바이스 LLM 추론을 위해 네이티브 라이브러리가 필요합니다:

1. [GitHub Releases](https://github.com/hann/aios/releases)에서 최신 `llama-cpp-dart.aar` 다운로드
2. `android/app/libs/llama-cpp-dart.aar` 에 배치

```bash
mkdir -p android/app/libs
# 다운로드한 AAR 파일을 android/app/libs/ 에 복사
```

### 서명 키

릴리즈 빌드를 위해 `android/aios-release.jks` 가 필요합니다. 별도로 관리되므로 담당자에게 요청하세요.

---

## 2. 빌드 명령어

```bash
flutter pub get                  # 의존성 설치
flutter run                      # Debug 실행 (연결된 디바이스)
flutter build apk                # Release APK
flutter build appbundle          # Release AAB (Play Store용)
flutter test                     # 단위 + 위젯 테스트
flutter test integration_test/   # 통합 테스트 (디바이스 필요)
dart run build_runner build      # 코드 생성 (freezed, drift, mockito)
dart run build_runner watch      # 코드 생성 감시 (개발 중)
dart format .                    # 코드 포맷팅
flutter analyze                  # 정적 분석
```

### Clean Build

```bash
flutter clean
flutter pub get
```

---

## 3. 코드 생성

freezed 모델, drift 데이터베이스, mockito mock 등 코드 생성이 필요한 경우:

```bash
# 전체 생성 (충돌 출력 삭제)
dart run build_runner build --delete-conflicting-outputs

# 변경 감시 모드 (개발 중)
dart run build_runner watch --delete-conflicting-outputs
```

코드 생성이 필요한 경우:
- `@freezed` 어노테이션이 있는 모델 클래스
- `@DriftDatabase`, `@Table` 어노테이션이 있는 DB 클래스
- `@GenerateNiceMocks` 어노테이션이 있는 테스트 파일

---

## 4. 프로젝트 구조

```
lib/
├── domain/         # 비즈니스 로직 (외부 의존성 없음)
│   ├── models/     # 도메인 모델 (freezed)
│   ├── repositories/  # Repository 인터페이스
│   └── agent/      # 에이전트 전략, ResponseParser, RiskClassifier
├── data/           # Repository 구현체, 외부 API
│   ├── repositories/
│   ├── database/   # Drift DB
│   └── local/
├── presentation/   # UI 계층
│   ├── screens/    # 화면 단위 위젯
│   ├── widgets/    # 재사용 위젯
│   └── providers/  # Riverpod providers
├── core/           # 공통 유틸, 테마, 상수
└── main.dart
```

자세한 아키텍처 설명은 [AGENTS.md](AGENTS.md)를 참고하세요.

---

## 5. 개발 워크플로우

### 브랜치 생성

```bash
git checkout -b feature/your-feature-name
# 또는
git checkout -b fix/your-bug-fix
```

### 코드 작성

- 기존 코드 스타일과 컨벤션 준수 (AGENTS.md 참고)
- 변경사항은 집중적이고 원자적으로 유지
- 가능하면 실기기에서 테스트

### 커밋 메시지

```
type: short description

Optional longer description
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`

### Pull Request

- PR 템플릿 작성
- 관련 이슈 참조
- 빌드 및 테스트 통과 확인
- 단일 관심사에 집중

---

## 6. PR 규칙

모든 PR은 다음 기준을 충족해야 합니다:

| 항목 | 명령어 | 기준 |
|------|--------|------|
| 테스트 | `flutter test` | 전체 통과 필수 |
| 정적 분석 | `flutter analyze` | 경고 없어야 함 |
| 포맷팅 | `dart format . --set-exit-if-changed` | 변경 없어야 함 |
| 코드 생성 | `dart run build_runner build` | 충돌 없이 성공 |
| 아키텍처 | — | AGENTS.md 패키지 구조 준수 |
| TDD | — | 테스트 먼저 작성 |

---

## 7. 릴리즈 프로세스

### 버전 업데이트

`pubspec.yaml` 의 `version` 필드를 업데이트:

```yaml
version: MAJOR.MINOR.PATCH+BUILD_NUMBER
```

### 빌드 & 배포

```bash
# Release APK 빌드
flutter build apk --release

# Release AAB 빌드 (Play Store)
flutter build appbundle --release
```

### GitHub Release

1. 버전 태그 생성: `git tag vMAJOR.MINOR.PATCH`
2. 태그 푸시: `git push origin vMAJOR.MINOR.PATCH`
3. GitHub Release 생성 후 APK 업로드
4. 자동 업데이트는 GitHub Releases 기반으로 동작

---

## 8. Agent Tool 개발

새로운 Tool 추가 방법은 [AGENTS.md](AGENTS.md)의 "Tool 개발" 섹션을 참고하세요.

---

## 9. 이슈 리포트

- 버그: GitHub Issue 템플릿 사용
- 기능 요청: Feature request 템플릿 사용
- 기기 정보, Android 버전, 모델 정보 포함 필수

---

## 라이선스

기여함으로써, 귀하의 기여물이 [MIT License](LICENSE) 하에 라이선스됨에 동의하는 것으로 간주합니다.
