# AIOS 기여 가이드

개발 환경 설정부터 PR 제출까지의 워크플로우를 안내합니다.

---

## 1. 개발 환경 설정

### 필수 도구

- **Node.js** 18.0+ (`node --version` 확인)
- **npm** 9.0+ (`npm --version` 확인)
- **Android Studio** 또는 **Android SDK**: API 24+, buildTools 34+
- **JDK** 11+
- **Git**

### Clone & Setup

```bash
git clone https://github.com/dev-hann/aios.git
cd aios
cd lib && npm install
```

### Gyo CLI 설치

```bash
# 방법 1: npm 글로벌 설치
npm install -g @gyo-framework/cli

# 방법 2: 로컬 CLI 경유
node /path/to/gyo/cli/dist/index.js run
```

### 환경 변수

LLM API 키는 앱 내 설정 화면에서 입력합니다. 개발/테스트용 환경변수:

```bash
# .env.local (lib/ 디렉토리, git 추적 제외)
VITE_API_KEY=your-api-key
VITE_MODEL=glm-4-flash
VITE_BASE_URL=https://open.bigmodel.cn/api/paas
```

---

## 2. 빌드 명령어

```bash
# 웹 앱 (lib/ 디렉토리에서)
cd lib
npm run dev              # Vite 개발 서버 (http://localhost:3000)
npm run build            # 프로덕션 빌드 (dist/)
npm run type-check       # TypeScript 타입 체크
npm run test             # Vitest 테스트
npm run verify           # type-check + test + build

# Android APK
bash /tmp/gyo build android  # 또는 gyo build android
# APK 위치: android/app/build/outputs/apk/

# 수동 Android 빌드 (Gradle 직접)
cd android && ./gradlew assembleDebug
```

### Clean Build

```bash
cd lib && rm -rf node_modules dist && npm install
cd android && ./gradlew clean
```

---

## 3. 프로젝트 구조

```
lib/src/
├── agent/         # ReactStrategy, ErrorRecovery, LoopDetector, etc.
├── components/    # React UI (ChatScreen, MessageBubble, etc.)
├── llm/           # OpenAI-compatible client (fetch + SSE)
├── services/      # IndexedDB, ConversationDB
├── stores/        # Zustand stores
├── styles/        # theme.css (CSS Custom Properties)
├── tools/         # Agent tools (calculator, notepad, timer)
└── types/         # TypeScript type definitions

android/           # Gyo WebView shell (Kotlin + Gradle)
gyo.config.json    # Gyo project configuration
```

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

- 관련 이슈 참조
- `npm run verify` 통과 확인
- 단일 관심사에 집중

---

## 5. PR 규칙

| 항목 | 명령어 | 기준 |
|------|--------|------|
| 타입 체크 | `npm run type-check` | 에러 없어야 함 |
| 테스트 | `npm run test` | 전체 통과 필수 |
| 빌드 | `npm run build` | 성공 |
| 통합 검증 | `npm run verify` | type-check + test + build 전부 통과 |
| 아키텍처 | — | [AGENTS.md](AGENTS.md) 코딩 규약 준수 |
| TDD | — | 테스트 먼저 작성 → [TESTING.md](TESTING.md) |

---

## 6. 릴리즈 프로세스

### 버전 업데이트

`lib/package.json`의 `version` 필드를 업데이트.

### 빌드 & 배포

```bash
cd lib && npm run build
# dist/ 에 프로덕션 에셋 생성
# 원격 서버에 배포 (gyo.config.json의 production serverUrl)
```

### Android APK

```bash
bash /tmp/gyo build android --release
```

### GitHub Release

1. 버전 태그 생성: `git tag vMAJOR.MINOR.PATCH`
2. 태그 푸시: `git push origin vMAJOR.MINOR.PATCH`
3. GitHub Release 생성 후 APK 업로드

---

## 7. 의존성 관리

### 현재 의존성 (lib/package.json)

| 패키지 | 용도 |
|--------|------|
| react, react-dom | UI 프레임워크 |
| zustand | 상태관리 |
| idb | IndexedDB Promise 래퍼 |
| vite | 빌드 도구 |
| typescript | 타입 체크 |

### 의존성 추가 시 체크

1. `package.json`에 존재하는지 확인
2. 번들 사이즈 영향 검토
3. AGENTS.md §5 문서 업데이트

---

## 8. 이슈 리포트

- 버그: GitHub Issue 템플릿 사용
- 기능 요청: Feature request 템플릿 사용
- 기기 정보, Android 버전, Node.js 버전 포함 필수

---

## 참고 문서

- **[AGENTS.md](AGENTS.md)** — 자율 개발 프로세스, 코딩 규약, 금지사항
- **[docs/architecture.md](docs/architecture.md)** — 시스템 아키텍처, ReAct 구조, 데이터 흐름
- **[docs/build-guide.md](docs/build-guide.md)** — 빌드 가이드 (Gyo CLI, Vite, APK)
- **[TESTING.md](TESTING.md)** — TDD 워크플로우, 테스트 범위, 커버리지
