# AIOS - AGENTS.md

## 0. 자율 개발 프로세스 (AUTONOMOUS DEV LOOP)

AI는 기기가 연결되면 사용자 개입 없이 아래 루프를 반복한다:

```
코드 수정 → npm run type-check → npm run build →
flutter build apk --debug → adb 설치 → 스모크 테스트 → logcat 확인 → 문제 파악 → 수정 → 반복
```

### 테스트 의무

- 코드 변경 후 **반드시 `npm run verify` 실행** (lib/ 디렉토리에서)
- `npm run verify`는 `type-check` + `test` + `build`를 순차 실행한다
- 기기가 연결되지 않으면 기기 테스트는 스킵된다
- **모든 테스트가 통과해야** 다음 단계(빌드/커밋)로 진행
- 에러 케이스는 **모두 해결** (테스트 삭제/건너뛰기 금지)
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

- **Android AI 에이전트** (Gyo Framework: React + TypeScript + WebView + Remote LLM API)
- **단일 루프 ReAct** 에이전트: tool-calling 기반 추론 → 실행 → 관측 반복
- Remote LLM: OpenAI-compatible API (glm-4-flash via z.ai) + Gyo Bridge (네이티브 접근성)
- **Zustand** 상태관리 + **IndexedDB** 저장 + React Components

---

## 2. 핵심 코딩 규약 (MUST FOLLOW)

### 2.1 필수 프레임워크

| 규칙 | 사용 | 금지 |
|------|------|------|
| 상태관리 | **Zustand** | Redux, MobX, Riverpod |
| UI | **React** (함수형 컴포넌트 + hooks) | Class 컴포넌트 |
| 타입 | **TypeScript** (strict mode) | any, `as` without type guard |
| 스타일 | **CSS Custom Properties** (theme.css) | CSS-in-JS, styled-components |
| 저장소 | **IndexedDB** (idb 라이브러리) | localStorage (대화 데이터) |
| 패키지 구조 | `src/agent/`, `src/llm/`, `src/tools/`, `src/stores/`, `src/components/`, `src/services/`, `src/types/` | 기능별 구조 |
| TS 스타일 | 2-space 들여쓰기, 세미콜론 있음, 최대 100자 | |

### 2.2 에러 처리

- **Tool 에러**: 반드시 `"Error: ..."` **문자열 반환** (예외 throw 금지)
- **Repository 에러**: try-catch + `console.error()` + 상태 업데이트
- **빈 catch 금지**: `catch (e) {}` 최소한 `console.error(e)` 출력 필요
- **action 비교**: 항상 `.toLowerCase()` 사용

### 2.3 로깅

```typescript
console.log('[AIOS-{Component}] message');
console.warn('[AIOS-{Component}] WARN: message');
console.error('[AIOS-{Component}] ERROR: message -', e);
```

- TAG 형식: `AIOS-{Component}` (예: AIOS-React, AIOS-OpenAi)

### 2.4 네이밍

| 대상 | 규칙 | 예시 |
|------|------|------|
| Class | PascalCase | `ReactStrategy`, `OpenAiClient` |
| Function | camelCase | `executeTool()`, `sendMessage()` |
| Variable | camelCase | `currentStrategy`, `toolContext` |
| Constant | lowerCamelCase | `maxRetries`, `defaultModel` |
| Tool name | snake_case | `screen_action`, `app_launcher` |
| File name | kebab-case | `react-strategy.ts`, `chat-store.ts` |
| React component file | PascalCase | `ChatScreen.tsx`, `MessageBubble.tsx` |
| Test file | `{name}.test.ts` | `react-strategy.test.ts` |
| Test function | `{method}_{scenario}_expectedResult` | `parseResponse_actionWithArgs()` |
| Hook | use + PascalCase | `useChatStore` |
| Store | camelCase + `-store.ts` | `chat-store.ts` |

### 2.5 파일 배치

| 생성 대상 | 위치 |
|-----------|------|
| Agent 전략/로직 | `src/agent/` |
| LLM 클라이언트 | `src/llm/` |
| Tool | `src/tools/` |
| Zustand Store | `src/stores/` |
| React Component | `src/components/` |
| Service (DB 등) | `src/services/` |
| Type 정의 | `src/types/` |
| 상수 (Provider 목록 등) | `src/constants/` |
| 스타일 | `src/styles/` |

---

## 3. 절대 금지 (NEVER)

| # | 항목 | 이유 |
|---|------|------|
| 1 | Tool에서 예외 throw | `"Error: ..."` 문자열 반환해야 함 |
| 2 | 빈 catch 블록 | 최소한 `console.error()` 출력 필요 |
| 3 | 테스트 삭제해서 통과시키기 | 근본 원인 해결 |
| 4 | Zustand 외 상태관리 사용 | Redux, MobX 등 금지 |
| 5 | 타입체크 없는 `as` 캐스트 | `is` / type guard 후 캐스트 |
| 6 | `// @ts-ignore` / `// @ts-expect-error` | 근본 원인 해결 |
| 7 | `package.json` 없는 의존성 | 의존성 추가 전 반드시 확인 |
| 8 | `any` 타입 사용 | 구체적 타입 또는 `unknown` 사용 |

---

## 4. 현재 상태 (CURRENT STATUS)

### 활성 Tool (순수 TS)

| Tool | 타입 | 파일 | 상태 |
|------|------|------|------|
| `calculator` | AgentTool | `src/tools/calculator.ts` | **활성** - 사칙연산, 퍼센트, 제곱근, validate |
| `notepad` | AgentTool | `src/tools/notepad.ts` | **활성** - 메모 작성/조회/목록/삭제, validate |
| `timer` | AgentTool | `src/tools/timer.ts` | **활성** - 타이머 설정/확인/취소/목록, validate |
| `app_launcher` | AgentTool | `src/tools/app-launcher.ts` | **활성** - 앱 목록/실행/URL열기/검색, validate, `@gyo-framework/app-launcher` bridge |

### 비활성 Tool (Gyo Bridge 필요, 추후 구현)

| Tool | 타입 | 네이티브 필요 | 상태 |
|------|------|---------------|------|
| `screen_action` | ExtendedTool | AccessibilityService | **비활성** - Gyo Bridge 필요 |
| `screen_reader` | ExtendedTool | AccessibilityService | **비활성** - Gyo Bridge 필요 |
| `screen_find` | ExtendedTool | AccessibilityService | **비활성** - Gyo Bridge 필요 |
| `notification_reader` | ExtendedTool | NotificationListenerService | **비활성** - Gyo Bridge 필요 |
| `sms_sender` | ExtendedTool | SmsManager | **비활성** - Gyo Bridge 필요 |
| `phone_caller` | ExtendedTool | TelephonyManager | **비활성** - Gyo Bridge 필요 |
| `contact_search` | ExtendedTool | ContactsProvider | **비활성** - Gyo Bridge 필요 |
| `device_info` | ExtendedTool | Build/Settings | **비활성** - Gyo Bridge 필요 |

### ReAct Agent 구조

```
User Input → chatStore.sendMessage() → ReactStrategy.execute()
  │
  ├─ System Prompt
  │   → 기본: "AIOS on-device assistant" + 응답 규칙
  │   → ConversationContext 주입: 최근 5턴 대화 기록 (있을 때만)
  │   → ToolPreferenceTracker 주입: 자주 사용하는 Tool top 3 (있을 때만)
  │
  ├─ 단일 루프 (최대 8회, 타임아웃 120초)
  │   → LLM에 3개 Tool schema 전달 (OpenAI function-calling format)
  │   → SSE streaming으로 LlmResponseChunk 수신
  │   → Map<number, ToolCallAccumulator>가 chunk 누적
  │   │
  │   ├─ LLM 응답이 tool_calls인 경우:
  │   │   1. RiskClassifier → 위험도 분류 (safe/low/high/critical)
  │   │   2. Tool.validate() → args 유효성 검증
  │   │   3. ConfirmationGate → high/critical 시 사용자 승인 요청
  │   │   4. Tool.execute() → 실제 실행
  │   │   5. ErrorRecovery → 실패 시 에러 분류 + 복구 넛지
  │   │   6. LoopDetector → 반복 감지 시 강제 종료
  │   │   7. session.addToolResult() → 결과를 대화에 추가
  │   │   8. 다음 iteration 계속
  │   │
  │   ├─ LLM 응답이 text인 경우 (tool_calls 없음):
  │   │   → Answer 반환 (루프 종료)
  │   │
  │   └─ LLM 응답이 비어있는 경우:
  │       → "Please use a tool or provide a direct answer" 넛지
  │       → 최대 2회 재시도
  │
  ├─ 빈 args 추론: inferToolArgs()로 calculator/notepad/timer에 한해 heuristic 추론
  ├─ Error Recovery
  │   → ErrorRecovery.analyze()로 에러 분류 (8가지 타입)
  │   → 재시도 가능: invalidAction, missingParameter, generic
  │   → 복구 힌트를 프롬프트에 주입
  │
  └─ recordTurn() → ConversationContext에 대화 기록 (다음 실행 시 system prompt에 반영)
```

### System Annotation (채팅 UI)

```
SystemAnnotation (src/components/SystemAnnotation.tsx)
  → 각 Phase/Step을 간략한 주석 형태로 채팅 내 표시
  → 회색 12px 이탤릭, 가운데 정렬, 아이콘 포함
  → 숨김 처리: thought, thinking_start, thinking_end
  → 표시: phase1_retry, action, observation, confirmation_required

SessionDrawer (src/components/SessionDrawer.tsx)
  → 왼쪽 Drawer로 세션 관리
  → 새 대화 생성, 세션 목록, 세션 전환/삭제

AppBar (src/components/ChatScreen.tsx)
  → 세션 제목 표시 (currentConversationTitle)
  → 햄버거 메뉴 (Drawer 열기), 새 대화 버튼
```

### Context Awareness

```
ConversationContext (src/agent/conversation-context.ts)
  → 최근 5턴 대화 기록 유지 (user Q + assistant A + tool used)
  → 응답 길이 제한 (200자)으로 컨텍스트 윈도우 절약
  → execute() 완료 시 자동 기록

ToolPreferenceTracker (src/agent/tool-preference-tracker.ts)
  → Tool 사용 빈도 추적 (top 3)
  → Routing 프롬프트에 "FREQUENTLY USED TOOLS" 섹션 추가
  → 자주 쓰는 tool 우선 라우팅 유도
```

### 세션 관리 (Session Management)

```
ChatScreen (src/components/ChatScreen.tsx)
  ├─ AppBar: 세션 제목 (자동 생성, 첫 메시지 기반 20자)
  ├─ Drawer (SessionDrawer)
  │   ├─ 새 대화 생성 버튼
  │   ├─ 세션 목록 (loadConversations)
  │   │   ├─ 세션 선택 → switchConversation()
  │   │   └─ 세션 삭제 → deleteConversation()
  │   └─ 설정 버튼
  └─ 세션 초기화: loadConversations() → 기존 세션 없으면 createConversation()

ConversationDB (src/services/conversation-db.ts)
  ├─ createConversation() → 새 세션 생성 (IndexedDB)
  ├─ getAllConversations() → 전체 세션 목록
  ├─ loadConversation(id) → 특정 세션 메시지 로드
  ├─ deleteConversation(id) → 세션 + 메시지 삭제
  └─ updateConversationTitle(id, title) → 세션 제목 업데이트

useChatStore (src/stores/chat-store.ts)
  ├─ currentConversationId: 현재 활성 세션 ID
  └─ currentConversationTitle: 현재 세션 제목 (AppBar에 표시)
```

### Tool 추가 시 체크리스트

1. Tool 클래스 구현 (`AgentTool` 인터페이스)
2. `react-strategy.ts`의 tools 배열에 등록
3. `RiskClassifier.classify()`에 위험도 분류 추가
4. 테스트 작성 (`src/tools/__tests__/{name}.test.ts`)
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
- **[docs/build-guide.md](docs/build-guide.md)** — 빌드/실행 가이드 (Gyo CLI, Vite, Android APK)
- **[TESTING.md](TESTING.md)** — 테스트 원칙, 스코프, TDD 워크플로우
- **[TESTING_DEVICE.md](TESTING_DEVICE.md)** — 기기 테스트: 스모크/기능/심화 테스트 + adb 패턴
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — 빌드/개발 명령어, 환경 설정, PR 규칙, 릴리즈
- **[ROADMAP.md](ROADMAP.md)** — 기능 목록, 마일스톤, 프로젝트 목표
- **[.opencode/skills/aios-dev/SKILL.md](.opencode/skills/aios-dev/SKILL.md)** — 자율 개발 스킬 정의
