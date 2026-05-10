# AIOS 기여 가이드

개발 환경 설정부터 PR 제출까지의 워크플로우를 안내합니다.

---

## 1. 개발 환경 설정

### 필수 도구

- **Flutter SDK** 3.41+ (`flutter --version` 확인)
- **Android Studio** 또는 **VS Code** + Flutter 확장
- **Android SDK**: compileSdk 36, minSdk 26
- **Git**

### Clone & Setup

```bash
git clone https://github.com/dev-hann/aios.git
cd aios
flutter pub get
```

### llama_cpp_dart AAR 설정 (온디바이스 추론 시)

> **참고**: 현재 기본 구성은 Remote OpenAI-compatible API를 사용합니다.
> 온디바이스 LLM 추론을 활성화하려면 아래 AAR이 필요합니다.

1. [GitHub Releases](https://github.com/dev-hann/aios/releases)에서 최신 `llama-cpp-dart.aar` 다운로드
2. `android/app/libs/llama-cpp-dart.aar` 에 배치

```bash
mkdir -p android/app/libs
# 다운로드한 AAR 파일을 android/app/libs/ 에 복사
```

### 환경 변수 (통합 테스트)

통합 테스트 실행 시 `.env.test` 파일이 필요합니다:

```bash
# .env.test (프로젝트 루트)
TEST_API_KEY=your-api-key
TEST_MODEL=glm-4.5-air
TEST_BASE_URL=https://api.z.ai/api/coding/paas/v4
```

### 서명 키

릴리즈 빌드를 위해 `android/aios-release.jks` 가 필요합니다. 별도로 관리되므로 담당자에게 요청하세요.

---

## 2. 빌드 명령어

```bash
flutter pub get                  # 의존성 설치
flutter run                      # Debug 실행 (연결된 디바이스)
flutter build apk                # Release APK
flutter build apk --debug        # Debug APK (자율 개발 루프용)
flutter build appbundle          # Release AAB (Play Store용)
flutter test                     # 단위 + 위젯 테스트
flutter test integration_test/   # 통합 테스트 (디바이스 필요)
dart run build_runner build      # 코드 생성 (freezed, drift, mockito)
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

```bash
# 전체 생성
dart run build_runner build --delete-conflicting-outputs

# 변경 감시 모드
dart run build_runner watch --delete-conflicting-outputs
```

코드 생성이 필요한 경우:
- `@freezed` 어노테이션이 있는 모델 클래스
- `@DriftDatabase` 어노테이션이 있는 DB 클래스
- `@GenerateNiceMocks` 어노테이션이 있는 테스트 파일

---

## 4. 개발 워크플로우

### 브랜치 생성

```bash
git checkout -b feature/your-feature-name
# 또는
git checkout -b fix/your-bug-fix
```

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

## 5. PR 규칙

| 항목 | 명령어 | 기준 |
|------|--------|------|
| 테스트 | `flutter test` | 전체 통과 필수 |
| 정적 분석 | `flutter analyze` | 경고 없어야 함 |
| 포맷팅 | `dart format . --set-exit-if-changed` | 변경 없어야 함 |
| 코드 생성 | `dart run build_runner build` | 충돌 없이 성공 |
| 아키텍처 | — | [AGENTS.md](AGENTS.md) 코딩 규약 준수 |
| TDD | — | 테스트 먼저 작성 → [TESTING.md](TESTING.md) |

---

## 6. 릴리즈 프로세스

### 버전 업데이트

`pubspec.yaml` 의 `version` 필드를 업데이트:

```yaml
version: MAJOR.MINOR.PATCH+BUILD_NUMBER
```

### 빌드 & 배포

```bash
flutter build apk --release
flutter build appbundle --release
```

### GitHub Release

1. 버전 태그 생성: `git tag vMAJOR.MINOR.PATCH`
2. 태그 푸시: `git push origin vMAJOR.MINOR.PATCH`
3. GitHub Release 생성 후 APK 업로드
4. 자동 업데이트는 GitHub Releases 기반으로 동작

---

## 7. 이슈 리포트

- 버그: GitHub Issue 템플릿 사용
- 기능 요청: Feature request 템플릿 사용
- 기기 정보, Android 버전, 모델 정보 포함 필수

---

## 참고 문서

- **[AGENTS.md](AGENTS.md)** — 자율 개발 프로세스, 코딩 규약, 금지사항
- **[docs/architecture.md](docs/architecture.md)** — 시스템 아키텍처, 2-Phase ReAct, 데이터 흐름
- **[TESTING.md](TESTING.md)** — TDD 워크플로우, 테스트 범위, 커버리지

---

## 라이선스

기여함으로써, 귀하의 기여물이 [MIT License](LICENSE) 하에 라이선스됨에 동의하는 것으로 간주합니다.
