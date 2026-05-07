# AIOS - AGENTS.md

## 0. 자율 개발 프로세스 (AUTONOMOUS DEV LOOP)

AI는 기기가 연결되면 사용자 개입 없이 아래 루프를 반복한다:

```
코드 수정 → flutter test → flutter build apk --debug →
adb 설치 → 스크린샷 확인 → logcat 확인 → 문제 파악 → 수정 → 반복
```

### 기기 명령어

| 동작 | 명령어 |
|------|--------|
| 연결 확인 | `adb devices` |
| 스크린샷 | `adb -s {DEVICE} shell screencap -p /sdcard/screen.png && adb -s {DEVICE} pull /sdcard/screen.png /tmp/screen.png` |
| 스크린샷 읽기 | `read` 도구로 `/tmp/screen.png` 열기 |
| 로그 수집 | `adb -s {DEVICE} logcat -d \| grep "\[AIOS-"` |
| 로그 초기화 | `adb -s {DEVICE} logcat -c` |
| 텍스트 입력 | `adb -s {DEVICE} shell input text "message"` |
| 탭 | `adb -s {DEVICE} shell input tap X Y` |
| 엔터 | `adb -s {DEVICE} shell input keyevent 66` |
| APK 설치 | `adb -s {DEVICE} uninstall com.agent.aios && adb -s {DEVICE} install build/app/outputs/flutter-apk/app-debug.apk` |
| 앱 실행 | `adb -s {DEVICE} shell am start -n com.agent.aios/.MainActivity` |

### 기기 연결 규칙

- 기기가 연결되지 않으면 **사용자에게 알리고** 기기 관련 스텝(설치, 스크린샷, logcat)을 **건너뛴다**
- 코드 수정, 테스트, 빌드는 기기 없이도 진행한다
- 기기 연결 복구 후 중단된 스텝부터 재개한다

### 병렬 실행 규칙

- **독립적인 작업은 반드시 동시에 실행** (순차 실행 금지)
- 예: 코드 수정 + 테스트는 순차, but 파일 읽기 여러 개는 병렬

---

## 1. 프로젝트 개요

- **Android 온디바이스 AI 에이전트** (Flutter/Dart + llama_cpp_dart)
- **2-Phase ReAct** 에이전트: Phase 1 (routing) → Phase 2 (tool-specific execution)
- Privacy-first: 모든 LLM 추론은 온디바이스 (네트워크 호출 없음)
- GitHub Releases 기반 in-app 자동 업데이트
- **Riverpod** DI + **Clean Architecture** + Flutter Widgets

---

## 2. 핵심 코딩 규약 (MUST FOLLOW)

### 2.1 필수 프레임워크

| 규칙 | 사용 | 금지 |
|------|------|------|
| 상태관리 | **Riverpod** | GetX, Bloc, Provider |
| 라우팅 | **GoRouter** | Navigator 1.0 |
| 불변 모델 | **Freezed** (`@freezed` + `const factory`) | 수동 immutable 클래스 |
| DI | `@Riverpod(keepAlive: true)` (싱글톤), `@riverpod` (화면 스코프) | 수동 Singleton |
| 패키지 구조 | `domain/`, `data/`, `presentation/`, `core/` | 기능별 구조 |
| Dart 스타일 | 2-space 들여쓰기, 최대 80자 | |

### 2.2 에러 처리

- **Tool 에러**: 반드시 `"Error: ..."` **문자열 반환** (예외 throw 금지)
- **Repository 에러**: try-catch + `print()` + 상태 업데이트
- **빈 catch 금지**: `catch (_) {}` 최소한 `print()` 출력 필요
- **action 비교**: 항상 `.toLowerCase()` 사용

### 2.3 로깅

```dart
print('[AIOS-{Component}] message');
print('[AIOS-{Component}] WARN: message');
print('[AIOS-{Component}] ERROR: message - $e');
```

- `developer.log` 사용 금지 (logcat에 출력 안 됨)
- TAG 형식: `AIOS-{Component}` (예: AIOS-React, AIOS-AppLauncher)

### 2.4 네이밍

| 대상 | 규칙 | 예시 |
|------|------|------|
| Class | PascalCase | `ReactStrategy`, `ScreenActionTool` |
| Function | camelCase | `executeTool()`, `sendMessage()` |
| Variable | camelCase | `currentStrategy`, `toolContext` |
| Constant | lowerCamelCase | `maxRetries`, `channelId` |
| Tool name | snake_case | `screen_action`, `app_launcher` |
| File name | snake_case | `react_strategy.dart` |
| Test file | `{name}_test.dart` | `react_strategy_test.dart` |
| Test function | `{method}_{scenario}_expectedResult` | `parseResponse_actionWithArgs()` |
| Widget | PascalCase | `ChatScreen()`, `_TopBar()` (private) |
| Provider | camelCase | `llmRepositoryProvider` |

### 2.5 파일 배치

| 생성 대상 | 위치 |
|-----------|------|
| Repository 인터페이스 | `domain/repositories/` |
| Repository 구현 | `data/repositories/` |
| Domain entity | `domain/entities/` |
| Agent 전략/로직 | `domain/agent/` |
| Tool | `agent/tools/` |
| Screen | `presentation/screens/` |
| Widget | `presentation/widgets/` |
| Provider | `presentation/providers/` |
| DataSource | `data/datasources/` |
| Engine Provider | `data/providers/` |
| Theme | `core/theme/` |

---

## 3. 절대 금지 (NEVER)

| # | 항목 | 이유 |
|---|------|------|
| 1 | Tool에서 예외 throw | `"Error: ..."` 문자열 반환해야 함 |
| 2 | 빈 catch 블록 | 최소한 `print()` 출력 필요 |
| 3 | 테스트 삭제해서 통과시키기 | 근본 원인 해결 |
| 4 | Riverpod 외 상태관리 사용 | GetX, Bloc 등 금지 |
| 5 | 타입체크 없는 `as` 캐스트 | `is` 체크 후 캐스트 |
| 6 | `// ignore:` 경고 숨기기 | 근본 원인 해결 |
| 7 | `pubspec.yaml` 없는 의존성 | 의존성 추가 전 반드시 확인 |
| 8 | `developer.log` 사용 | `print()` 사용 (logcat 가시성) |

---

## 4. 현재 상태 (CURRENT STATUS)

### 활성 Tool

| Tool | 타입 | 파일 | 상태 |
|------|------|------|------|
| `app_launcher` | ExtendedTool | `agent/tools/app_launcher_tool.dart` | **활성** |
| `screen_action` | ExtendedTool | `agent/tools/screen_action_tool.dart` | **활성** |
| `screen_reader` | ExtendedTool | `agent/tools/screen_reader_tool.dart` | **활성** |
| `screen_find` | ExtendedTool | `agent/tools/screen_reader_tool.dart` | **활성** |
| `notification_reader` | ExtendedTool | `agent/tools/notification_tool.dart` | **활성** |

### 비활성 Tool (보존, 추후 재활성화)

| Tool | 타입 | 파일 |
|------|------|------|
| `calculator` | BasicTool | `agent/tools/calculator_tool.dart` |
| `contact_search` | BasicTool | `agent/tools/contact_search_tool.dart` |
| `device_info` | BasicTool | `agent/tools/device_info_tool.dart` |
| `notepad` | BasicTool | `agent/tools/notepad_tool.dart` |
| `timer` | BasicTool | `agent/tools/timer_tool.dart` |
| `phone_caller` | ExtendedTool | `agent/tools/phone_caller_tool.dart` |
| `sms_sender` | ExtendedTool | `agent/tools/sms_sender_tool.dart` |

### 2-Phase ReAct 구조

```
User Input → ReactStrategy.execute()
  ├─ Phase 1: Routing (최소 프롬프트, ~80 토큰)
  │   → LLM이 "Action: tool_name" 또는 "Answer: text" 응답
  │   → ParseEmpty 시 포맷 넛지와 함께 재시도
  ├─ Phase 2: Tool-specific execution (args가 비어있을 때만)
  │   → toolPrompt + phaseContext(app 리스트 등)로 LLM이 args 포맷팅
  │   → 응답에서 Action + Args 파싱하여 tool 실행
  └─ Tool 실행 → Observation → 루프 반복 (최대 8회) 또는 Answer 반환
```

### 테스트

- **714 테스트** 전체 통과
- 알려진 타임아웃: `model_test.dart`, `agent_integration_test.dart` (GGUF 모델 필요)

### Tool 추가 시 체크리스트

1. Tool 클래스 구현 (`AgentTool` 또는 `ExtendedTool`)
2. `agent_provider.dart`의 tools 맵에 등록
3. `RiskClassifier.classify()`에 위험도 분류 추가
4. 테스트 작성
5. AGENTS.md §4 활성 Tool 테이블 업데이트

---

## 5. 커밋 전 문서 업데이트 (MANDATORY)

코드 변경 후 커밋하기 전, 변경 내용이 관련 문서에 영향을 주는지 확인하고
필요시 업데이트한다:

| 변경 유형 | 업데이트할 문서 | 체크 항목 |
|-----------|----------------|-----------|
| Tool 추가/제거/수정 | AGENTS.md §4, architecture.md | 활성 Tool 목록, Tool Categories |
| 아키텍처 변경 | architecture.md | Data Flow, Layers, Design Decisions |
| 테스트 추가/삭제/수정 | TESTING.md | 테스트 수, 커버리지, 알려진 실패 |
| 새 파일 생성 | AGENTS.md §2.5 | 디렉토리 구조 테이블 |
| 새 의존성 추가 | CONTRIBUTING.md | 패키지 목록 |
| Agent 로직 변경 | AGENTS.md §4, architecture.md | Phase 구조, 프롬프트, 파서 |
| 빌드/CI/배포 변경 | CONTRIBUTING.md | 명령어, 환경 설정 |
| 코딩 규약 변경 | AGENTS.md §2, §3 | 규약, 금지사항 |

### 체크 방법

1. `git diff --stat` 으로 변경 파일 목록 확인
2. 위 테이블에서 해당하는 문서 식별
3. 문서 읽기 → 변경 내용 반영 → 저장
4. 문서 업데이트를 커밋에 포함

---

## 참고 문서

- **[docs/architecture.md](docs/architecture.md)** — 시스템 아키텍처, 모듈 구조, 데이터 흐름, 상세 설계
- **[TESTING.md](TESTING.md)** — TDD 워크플로우, 테스트 범위, 커버리지 요구사항
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — 빌드/개발 명령어, 환경 설정, PR 규칙, 릴리즈
- **[ROADMAP.md](ROADMAP.md)** — 기능 목록, 마일스톤, 프로젝트 목표
- **[.opencode/skills/aios-dev/SKILL.md](.opencode/skills/aios-dev/SKILL.md)** — 자율 개발 스킬 정의
