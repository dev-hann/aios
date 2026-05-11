# Architecture

AIOS의 내부 아키텍처를 설명합니다.

## System Overview

AIOS는 **React + TypeScript** (Gyo Framework) 기반 Android AI 에이전트 앱입니다.

WebView 셸(Android Kotlin) + Vite 개발 서버 + Remote OpenAI-compatible API 구조를 사용합니다.

```
┌──────────────────────────────────────────────────────────────────┐
│                     Presentation Layer (React)                    │
│                                                                    │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │  Components (React 함수형 컴포넌트)                         │   │
│  │  ChatScreen + MessageBubble + InputBar + SessionDrawer      │   │
│  │  SettingsScreen + ProviderSettingsScreen                    │   │
│  │  InferenceSettingsScreen + PermissionManagementScreen       │   │
│  │  SystemAnnotation                                           │   │
│  └──────────────────────────┬─────────────────────────────────┘   │
│                              │                                     │
│  ┌──────────────────────────▼─────────────────────────────────┐   │
│  │  Zustand Store (chat-store.ts)                              │   │
│  │  useChatStore — 단일 전역 상태                                │   │
│  └──────────────────────────┬─────────────────────────────────┘   │
└──────────────────────────────┼────────────────────────────────────┘
                                │
┌───────────────────────────────┼────────────────────────────────────┐
│                     Agent Layer                                     │
│                                │                                     │
│  ┌─────────────────────────────▼──────────────────────────────┐   │
│  │  ReactStrategy (ReAct 루프)                                  │   │
│  │  최대 8회 반복, tool-calling, Safety Pipeline                │   │
│  └─────────────────────────────┬──────────────────────────────┘   │
│                                │                                     │
│  ┌─────────────────────────────▼──────────────────────────────┐   │
│  │  Support Modules                                             │   │
│  │  ErrorRecovery + LoopDetector + RiskClassifier               │   │
│  │  ConversationContext + ToolPreferenceTracker                 │   │
│  │  ToolJsonParser + ToolArgInference + Truncate                │   │
│  └─────────────────────────────────────────────────────────────┘   │
└───────────────────────────────┼────────────────────────────────────┘
                                │
┌───────────────────────────────┼────────────────────────────────────┐
│                     Data / LLM Layer                                │
│                                │                                     │
│  ┌─────────────────────────────▼──────────────────────────────┐   │
│  │  LLM Client                                                 │   │
│  │  OpenAiClient (fetch + SSE) + LlmRemoteSession              │   │
│  │  Provider Config (zai, openai, anthropic, custom)            │   │
│  └─────────────────────────────┬──────────────────────────────┘   │
│                                │                                     │
│  ┌─────────────────────────────▼──────────────────────────────┐   │
│  │  Storage (IndexedDB via idb)                                 │   │
│  │  ConversationDB — 대화/메시지 CRUD                            │   │
│  │  Notepad — 메모 CRUD                                         │   │
│  └─────────────────────────────────────────────────────────────┘   │
└───────────────────────────────┼────────────────────────────────────┘
                                │
         ┌──────────────────────┼─────────────────────┐
         ▼                                            ▼
┌──────────────────────┐              ┌─────────────────────────────┐
│  Remote LLM API      │              │  Android Native (Gyo Bridge) │
│  OpenAI-compatible   │              │  WebView Shell (Kotlin)      │
│  (GLM-4 via z.ai)    │              │  Gyo CLI 빌드                │
│  fetch + SSE         │              │  (네이티브 연동 예정)          │
└──────────────────────┘              └─────────────────────────────┘
```

## Layer Rules

### `lib/src/agent/` — 에이전트 로직

**역할**: ReAct 전략, 에러 복구, 루프 감지 등 에이전트 핵심 로직.

| 파일 | 역할 |
|------|------|
| `react-strategy.ts` | ReAct 루프 (최대 8회 반복, tool-calling, 120초 타임아웃) |
| `error-recovery.ts` | 에러 분류 (8가지 타입) + 복구 힌트 |
| `loop-detector.ts` | 반복 감지 (3-strike) |
| `risk-classifier.ts` | Tool 위험도 분류 (safe/low/medium/high/critical) |
| `conversation-context.ts` | 최근 5턴 대화 기록 |
| `tool-preference-tracker.ts` | Tool 사용 빈도 추적 (top 3) |
| `tool-json-parser.ts` | JSON 인수 파싱 유틸리티 |
| `tool-arg-inference.ts` | 빈 args 휴리스틱 추론 (calculator/notepad/timer) |
| `truncate.ts` | 문자열 자르기 유틸리티 |

### `lib/src/tools/` — 에이전트 Tool 구현체

| Tool | 파일 | 타입 | 상태 |
|------|------|------|------|
| `calculator` | `calculator.ts` | AgentTool | **활성** — 사칙연산, 퍼센트, 제곱근 |
| `notepad` | `notepad.ts` | AgentTool | **활성** — 메모 작성/조회/목록/삭제 |
| `timer` | `timer.ts` | AgentTool | **활성** — 타이머 설정/확인/취소/목록 |
| — | `types.ts` | 인터페이스 | AgentTool 인터페이스 정의 |

비활성 Tool (Gyo Bridge 필요):

| Tool | 필요 권한 | 상태 |
|------|-----------|------|
| `app_launcher` | PackageManager | **비활성** |
| `screen_action` | AccessibilityService | **비활성** |
| `screen_reader` | AccessibilityService | **비활성** |
| `screen_find` | AccessibilityService | **비활성** |
| `notification_reader` | NotificationListenerService | **비활성** |
| `sms_sender` | SmsManager | **비활성** |
| `phone_caller` | TelephonyManager | **비활성** |
| `contact_search` | ContactsProvider | **비활성** |
| `device_info` | Build/Settings | **비활성** |

### `lib/src/llm/` — LLM 통신 계층

| 파일 | 역할 |
|------|------|
| `openai-client.ts` | fetch HTTP + SSE 스트리밍 파싱, tool schema 변환, 모델 목록 조회 |
| `session.ts` | 메시지 히스토리 관리 + tool result 주입 + 자동 compaction |
| `types.ts` | LLM 타입 정의 (LlmProviderConfig, LlmResponseChunk, LlmToolSchema 등) |

### `lib/src/stores/` — 상태 관리

| 파일 | 역할 |
|------|------|
| `chat-store.ts` | Zustand 단일 전역 스토어. 메시지, 세션, Provider, Inference 설정 |

### `lib/src/services/` — 데이터 영속성

| 파일 | 역할 |
|------|------|
| `db.ts` | IndexedDB 스키마 (idb 라이브러리). conversations, messages, notes 스토어 |
| `conversation-db.ts` | 대화/메시지 CRUD (IndexedDB) |

### `lib/src/components/` — React UI 컴포넌트

| 파일 | 역할 |
|------|------|
| `ChatScreen.tsx` | 메인 채팅 화면 (AppBar, Drawer, 메시지 목록, 입력) |
| `MessageBubble.tsx` | 유저/어시스턴트 말풍선 |
| `InputBar.tsx` | 메시지 입력 + 전송/정지 |
| `SessionDrawer.tsx` | 세션 관리 Drawer |
| `SystemAnnotation.tsx` | 에이전트 Phase/Step 주석 표시 (risk-level 색상, retry count, error 감지) |
| `SettingsScreen.tsx` | 설정 메인 화면 |
| `ProviderSettingsScreen.tsx` | AI 제공자 설정 화면 |
| `InferenceSettingsScreen.tsx` | 추론 파라미터 설정 화면 |
| `PermissionManagementScreen.tsx` | 권한 관리 화면 |

### `lib/src/types/` — TypeScript 타입 정의

| 파일 | 역할 |
|------|------|
| `agent.ts` | ToolResult, AgentStep, AgentResult, ToolRisk + 헬퍼 함수 |

### `lib/src/constants/` — 상수

| 파일 | 역할 |
|------|------|
| `providers.ts` | LLM Provider 타입 목록 (zai, openai, anthropic, custom) |

### `lib/src/styles/` — CSS 스타일

| 파일 | 역할 |
|------|------|
| `theme.css` | CSS Custom Properties (색상, 간격, 폰트) |
| `chat.css` | 채팅 화면 스타일 |
| `message-bubble.css` | 말풍선 스타일 |
| `input-bar.css` | 입력 바 스타일 |
| `drawer.css` | Drawer 스타일 |
| `confirmation-dialog.css` | 확인 다이얼로그 스타일 |
| `system-annotation.css` | 시스템 주석 스타일 (risk-level 색상: high/critical/error) |
| `settings.css` | 설정 화면 스타일 |

## LLM Engine Architecture

### fetch + SSE 구조

```
ReactStrategy
  │
  ├─ OpenAiClient (fetch HTTP)
  │   → POST /chat/completions with stream: true
  │   → Response.body ReadableStream → SSE data: lines → LlmResponseChunk 파싱
  │   → Tool schemas를 OpenAI function-calling JSON으로 변환
  │
  └─ LlmRemoteSession
      → messages: Array<Record<string, unknown>> (OpenAI format)
      → addToolResult(): tool 결과를 role: tool 메시지로 추가
      → chat(): userParts + 전체 히스토리를 API에 전송
      → 자동 compaction: 12K 토큰 추정 시 tool output 제거 → LLM 요약 → hard limit
```

### Streaming Flow

```
fetch() → ReadableStream → TextDecoder
  → SSE data: lines → JSON 파싱
  → delta.content → text chunk
  → delta.tool_calls[] → Map<int, ToolCallBuilder>가 chunk 누적
  → 완전한 tool call 구성 후 실행
```

## Agent System

### 단일 루프 ReAct 구조

```
User Input → useChatStore.sendMessage() → ReactStrategy.execute()
  → for 루프 (최대 8회, 타임아웃 120초):
      1. LlmRemoteSession.chat() — LLM에 tool schemas 전달, SSE 응답 수신
      2. LLM 응답이 tool_calls → Safety Pipeline 통과 후 실행
      3. LLM 응답이 text → Answer 반환 (루프 종료)
      4. LLM 응답이 비어있음 → 넛지 후 재시도 (max 2회)
      5. finish_reason === 'length' → continuation (max 3회)
```

### Safety Pipeline

1. **RiskClassifier** — tool + args 기반 위험도 분류
2. **Tool.validate()** — args 유효성 검증
3. **ConfirmationGate** — HIGH/CRITICAL 위험도 시 사용자 승인 요청 (risk-level 색상 차등: critical=주황, high=노랑)
4. **Tool.execute()** — 실제 실행
5. **ErrorRecovery** — 실패 시 에러 분류 + 복구 힌트
6. **LoopDetector** — 반복 감지 (3-strike)
7. **ToolPreferenceTracker** — tool 사용 빈도 기록

### 빈 args 추론

LLM이 tool call 시 args를 비워보내면 `inferToolArgs()`가 휴리스틱으로 추론:
- calculator: 수식 패턴 감지
- notepad: 메모 내용 추출
- timer: 시간 표현 파싱 (한/영 혼합 지원)

## State Management (Zustand)

```
useChatStore (create<ChatState>)
├─ messages: ChatMessage[]
├─ agentSteps: AgentStep[]
├─ serviceState: ServiceState { status, label }
├─ streamingContent: string
├─ isStreamingText: boolean
├─ isConfirming: boolean
├─ pendingToolName: string
├─ pendingToolArgs: string
├─ pendingToolRisk: string
├─ errorMessage: string | null
│
├─ conversations: Conversation[]
├─ currentConversationId: string | null
├─ currentConversationTitle: string
│
├─ providerConfig: LlmProviderConfig | null
├─ apiKey: string
├─ baseUrl: string
├─ model: string
├─ providerType: string
├─ availableModels: LlmModelInfo[]
├─ connectionTestResult: { success, message } | null
│
├─ inferenceConfig: InferenceConfig { temperature, topP, maxTokens, maxIterations }
│
├─ sendMessage(text)
├─ cancelGeneration()
├─ resolveConfirmation(approved)
├─ setProvider(type, apiKey, baseUrl, model)
├─ disconnectProvider()
├─ testConnection()
├─ fetchModels()
├─ initializeSession()
├─ createConversation()
├─ switchConversation(id)
├─ deleteConversation(id)
├─ loadConversations()
├─ clearHistory()
└─ setInferenceConfig(config)
```

## Storage (IndexedDB)

```
Database: aios-db (version 1, via idb library)
├── conversations: { id (PK), title, createdAt, updatedAt }
├── messages: { id (PK), conversationId (index), role, content, createdAt, toolName, toolArgs, toolResult }
└── notes: { key (PK), value, updatedAt }
```

## Routing (React Router)

```
BrowserRouter
├── /                        → ChatScreen
├── /settings                → SettingsScreen
├── /settings/provider       → ProviderSettingsScreen
├── /settings/inference      → InferenceSettingsScreen
└── /settings/permissions    → PermissionManagementScreen
```

## Key Design Decisions

### Why React + TypeScript (Gyo Framework)?

- 웹 기술로 Android 앱 개발 (WebView 셸)
- Vite 개발 서버 + HMR로 빠른 개발 사이클
- TypeScript strict mode로 타입 안전성
- Gyo CLI로 Android APK 빌드 자동화

### Why Zustand?

- 최소 보일러플레이트 (Redux 대비)
- React hooks와 자연스러운 통합
- 단일 스토어 패턴으로 상태 추적 용이
- TypeScript와 완벽한 타입 추론

### Why IndexedDB (idb)?

- 브라우저 내 대용량 데이터 저장
- Promise 기반 idb 래퍼로 깔끔한 async/await API
- 대화 히스토리 + 메모 영속성

### Why fetch + SSE?

- 네이티브 fetch API로 추가 의존성 없이 스트리밍
- ReadableStream으로 SSE 파싱
- AbortController로 취소 지원

### Why CSS Custom Properties?

- CSS-in-JS 없이 테마 관리
- 런타임 다크/라이트 테마 전환 가능
- 번들 사이즈 최소화
