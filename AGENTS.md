# AIOS - AGENTS.md

## 0. 자율 개발 프로세스 (AUTONOMOUS DEV LOOP)

AI는 기기가 연결되면 사용자 개입 없이 아래 루프를 반복한다:

```
코드 수정 → ./scripts/test.sh → flutter build apk --debug →
adb 설치 → 스모크 테스트 → logcat 확인 → 문제 파악 → 수정 → 반복
```

### 테스트 의무

- 코드 변경 후 **반드시 `./scripts/test.sh` 실행** (일부만 실행 금지)
- `./scripts/test.sh`는 `flutter test` + `flutter test integration_test/`(기기 있을 때)를 순차 실행한다
- 기기가 연결되지 않으면 통합 테스트는 스킵되고 단위/위젯 테스트만 실행된다
- **모든 테스트가 통과해야** 다음 단계(빌드/커밋)로 진행
- 에러 케이스는 **모두 해결** (테스트 삭제/건너뛰기/`// ignore` 금지)
- 기기 테스트 시 **TESTING_DEVICE.md** 스모크 테스트 전부 수행

### 기기 명령어

| 동작 | 명령어 |
|------|--------|
| 연결 확인 | `adb devices` |
| 스크린샷 | `adb -s {DEVICE} shell screencap -p /sdcard/screen.png && adb -s {DEVICE} pull /sdcard/screen.png /tmp/screen.png` |
| 스크린샷 읽기 | `read` 도구로 `/tmp/screen.png` 열기 |
| 로그 수집 | `adb -s {DEVICE} logcat -d \| grep "\[AIOS-"` |
| 로그 초기화 | `adb -s {DEVICE} logcat -c` |
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

- **Android AI 에이전트** (Flutter/Dart + Remote OpenAI-compatible API)
- **단일 루프 ReAct** 에이전트: tool-calling 기반 추론 → 실행 → 관측 반복
- Remote LLM: OpenAI-compatible API (glm-4.5-air via z.ai) + 온디바이스 접근성 서비스
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
| Service | `data/services/` |
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
| `app_launcher` | ExtendedTool | `agent/tools/app_launcher_tool.dart` | **활성** - 단일 `open` 액션, 퍼지 매칭 |
| `screen_action` | ExtendedTool | `agent/tools/screen_action_tool.dart` | **활성** |
| `screen_reader` | ExtendedTool | `agent/tools/screen_reader_tool.dart` | **활성** |
| `screen_find` | ExtendedTool | `agent/tools/screen_reader_tool.dart` | **활성** |
| `notification_reader` | ExtendedTool | `agent/tools/notification_tool.dart` | **활성** |
| `sms_sender` | ExtendedTool | `agent/tools/sms_sender_tool.dart` | **활성** |
| `phone_caller` | ExtendedTool | `agent/tools/phone_caller_tool.dart` | **활성** |
| `contact_search` | ExtendedTool | `agent/tools/contact_search_tool.dart` | **활성** |
| `calculator` | BasicTool | `agent/tools/calculator_tool.dart` | **활성** |
| `notepad` | BasicTool | `agent/tools/notepad_tool.dart` | **활성** |
| `timer` | BasicTool | `agent/tools/timer_tool.dart` | **활성** |
| `device_info` | ExtendedTool | `agent/tools/device_info_tool.dart` | **활성** |

### 비활성 Tool (보존, 추후 재활성화)

(없음)

### Native Tool-Calling Agent 구조

```
User Input → ReactStrategy.execute()
  ├─ LlmChatSession 재사용: _ensureSession()으로 세션 캐시
  │   → LlmRemoteSession이 OpenAI 메시지 히스토리 유지
  │   → Tool schemas도 캐시 (_cachedToolSchemas)
  │
  ├─ DB Fire-and-Forget: sendMessage()에서 appendMessage/updateTitle 비동기
  │   → agent 실행 전 DB 대기 제거
  │
  ├─ System Prompt
  │   → 기본: "AIOS on-device assistant" + 응답 규칙
  │   → ConversationContext 주입: 최근 5턴 대화 기록 (있을 때만)
  │   → ToolPreferenceTracker 주입: 자주 사용하는 Tool top 3 (있을 때만)

  ├─ 단일 루프 (최대 8회, 타임아웃 120초)
  │   → LLM에 12개 Tool schema (LlmToolSchema) 전달
  │   → OpenAI API가 streaming SSE로 LlmToolCallDelta 수신
  │   → _ToolCallAccumulator가 chunk를 누적하여 완전한 tool call 구성
  │   │
  │   ├─ LLM 응답이 tool_calls인 경우:
  │   │   1. RiskClassifier → 위험도 분류 (LOW/MEDIUM/HIGH/CRITICAL)
  │   │   2. Tool.validate() → args 유효성 검증
  │   │   3. ConfirmationGate → HIGH/CRITICAL 시 사용자 승인 요청
  │   │   4. Tool.execute() → 실제 실행
  │   │   5. AuditLog → 실행 기록
  │   │   6. ErrorRecovery → 실패 시 에러 분류 + 복구 넛지
  │   │   7. LoopDetector → 반복 감지 시 강제 종료
  │   │   8. session.addToolResult() → 결과를 대화에 추가
  │   │   9. 다음 iteration 계속 (userParts = [])
  │   │
  │   ├─ LLM 응답이 text인 경우 (tool_calls 없음):
  │   │   → Answer 반환 (루프 종료)
  │   │
  │   └─ LLM 응답이 비어있는 경우:
  │       → "Please use a tool or provide a direct answer" 넛지
  │       → 최대 2회 재시도 (phase1_retry step type)
  │
  ├─ 빈 args 추론: _inferToolArgs()로 calculator/notepad/timer에 한해 heuristic 추론
  ├─ Error Recovery
  │   → ErrorRecovery.analyze()로 에러 분류 (8가지 타입)
  │   → 재시도 가능: invalidAction, missingParameter, appNotInstalled, generic
  │   → 복구 힌트를 프롬프트에 주입
  │   → 실행 간 초기화, 툴별 최대 1회 재시도
  │
  └─ _recordTurn() → ConversationContext에 대화 기록 (다음 실행 시 system prompt에 반영)
```

### System Annotation (채팅 UI)

```
_SystemAnnotation (presentation/screens/chat/chat_screen.dart)
  → 각 Phase/Step을 간략한 주석 형태로 채팅 내 표시
  → 회색 12sp 이탤릭, 가운데 정렬, 아이콘 포함
  → 숨김 처리: thought, thinking_start, thinking_end
  → 표시: phase1_retry, action, observation, confirmation_required

SessionDrawer (presentation/widgets/session_drawer.dart)
  → 왼쪽 Drawer로 세션 관리
  → 새 대화 생성, 세션 목록, 세션 전환/삭제
  → 실시간 업데이트 (watchAllConversations Stream)

AppBar
  → 세션 제목 표시 (currentConversationTitle)
  → 햄버거 메뉴 (Drawer 열기), 새 대화, 설정 버튼
```

### Context Awareness

```
ConversationContext (domain/agent/conversation_context.dart)
  → 최근 5턴 대화 기록 유지 (user Q + assistant A + tool used)
  → 응답 길이 제한 (200자)으로 컨텍스트 윈도우 절약
  → execute() 완료 시 자동 기록

ToolPreferenceTracker (domain/agent/tool_preference_tracker.dart)
  → Tool 사용 빈도 추적 (top 3)
  → Routing 프롬프트에 "FREQUENTLY USED TOOLS" 섹션 추가
  → 자주 쓰는 tool 우선 라우팅 유도
```

### 세션 관리 (Session Management)

```
ChatScreen
  ├─ AppBar: 세션 제목 (자동 생성, 첫 메시지 기반 20자)
  ├─ Drawer (SessionDrawer)
  │   ├─ 새 대화 생성 버튼
  │   ├─ 세션 목록 (watchAllConversations Stream, updatedAt DESC)
  │   │   ├─ 세션 선택 → switchConversation()
  │   │   └─ 세션 삭제 → deleteConversation() (자동으로 다음 세션으로 전환)
  │   └─ 설정 버튼
  └─ 세션 초기화: initializeSession() → 기존 세션 없으면 createConversation()

ConversationRepository (다중 세션 지원)
  ├─ createConversation() → 새 세션 생성
  ├─ getAllConversations() → 전체 세션 목록
  ├─ loadConversation(id) → 특정 세션 메시지 로드
  ├─ deleteConversation(id) → 세션 + 메시지 삭제
  ├─ updateConversationTitle(id, title) → 세션 제목 업데이트
  └─ watchAllConversations() → 실시간 세션 목록 Stream

ChatState
  ├─ currentConversationId: 현재 활성 세션 ID
  └─ currentConversationTitle: 현재 세션 제목 (AppBar에 표시)
```

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
- **[TESTING.md](TESTING.md)** — 단위 테스트 원칙, 스코프, TDD 워크플로우
- **[TESTING_DEVICE.md](TESTING_DEVICE.md)** — 기기 테스트: 스모크/기능/심화 테스트 + adb 패턴
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — 빌드/개발 명령어, 환경 설정, PR 규칙, 릴리즈
- **[ROADMAP.md](ROADMAP.md)** — 기능 목록, 마일스톤, 프로젝트 목표
- **[.opencode/skills/aios-dev/SKILL.md](.opencode/skills/aios-dev/SKILL.md)** — 자율 개발 스킬 정의
