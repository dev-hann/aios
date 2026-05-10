# Architecture

AIOS의 내부 아키텍처를 설명합니다.

## System Overview

AIOS는 **Flutter** (Dart) 기반 Android AI 에이전트 앱입니다.

Clean Architecture + Riverpod 상태관리 + Remote OpenAI-compatible API (LLM 추론) 구조를 사용합니다.

```
┌──────────────────────────────────────────────────────────────┐
│                     Presentation Layer (Flutter)              │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Screens & Widgets                                     │  │
│  │  ChatScreen + MessageBubble + InputBar + SessionDrawer │  │
│  └──────────────────────────┬─────────────────────────────┘  │
│                             │                                  │
│  ┌──────────────────────────▼─────────────────────────────┐  │
│  │  Providers (Riverpod StateNotifier)                    │  │
│  │  ChatNotifier + SettingsNotifier + UpdateNotifier      │  │
│  └──────────────────────────┬─────────────────────────────┘  │
└─────────────────────────────┼────────────────────────────────┘
                              │
┌─────────────────────────────┼────────────────────────────────┐
│                     Domain Layer                              │
│                             │                                  │
│  ┌──────────────────────────▼─────────────────────────────┐  │
│  │  Agent                                                  │  │
│  │  ReactStrategy + Tools + Safety Pipeline                │  │
│  └──────────────────────────┬─────────────────────────────┘  │
│                             │                                  │
│  ┌──────────────────────────▼─────────────────────────────┐  │
│  │  Entities & Repository Interfaces                       │  │
│  │  ChatMessage + Conversation + LlmEngine + Repositories  │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────┼────────────────────────────────┘
                              │
┌─────────────────────────────┼────────────────────────────────┐
│                     Data Layer                                │
│                             │                                  │
│  ┌──────────────────────────▼─────────────────────────────┐  │
│  │  Providers & Repositories                               │  │
│  │  OpenAiClient (Dio+SSE) + Database (Drift/SQLite)       │  │
│  │  SharedPreferences + GitHubApi + OverlayService          │  │
│  └──────────────────────────┬─────────────────────────────┘  │
└─────────────────────────────┼────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         ▼                                         ▼
┌─────────────────────┐               ┌─────────────────────────┐
│  Remote LLM API     │               │  Android Native          │
│  OpenAI-compatible  │               │  AccessibilityService    │
│  (GLM-4 via z.ai)   │               │  PackageManager          │
│  Dio + SSE streaming│               │  MethodChannel           │
└─────────────────────┘               └─────────────────────────┘
```

## Layer Rules

### `lib/domain/agent/` — 에이전트 로직

**역할**: ReAct 전략, 에러 복구, 루프 감지 등 에이전트 핵심 로직.

| 파일 | 역할 |
|------|------|
| `react_strategy.dart` | ReAct 루프 (최대 8회 반복, tool-calling) |
| `error_recovery.dart` | 에러 분류 (8가지 타입) + 복구 힌트 |
| `loop_detector.dart` | 반복 감지 (3-strike) |
| `risk_classifier.dart` | Tool 위험도 분류 (safe/low/high/critical) |
| `confirmation_gate.dart` | 고위험 도구 사용자 승인 게이트 |
| `permission_gate.dart` | 런타임 권한 요청 게이트 |
| `gate_completer.dart` | Completer 기반 게이트 공통 베이스 |
| `conversation_context.dart` | 최근 5턴 대화 기록 |
| `tool_preference_tracker.dart` | Tool 사용 빈도 추적 |
| `tool_json_parser.dart` | JSON 인수 파싱 유틸리티 (parseIntDynamic, parseDoubleDynamic) |
| `tool_arg_inference.dart` | 빈 args 휴리스틱 추론 |
| `tool_permission_mapper.dart` | Tool → Android 권한 매핑 |
| `user_message_mapper.dart` | 기술적 에러 → 사용자 친화적 메시지 변환 |
| `truncate.dart` | 문자열 자르기 유틸리티 |
| `version_util.dart` | 버전 문자열 비교 유틸리티 |
| `audit_log.dart` | 도구 실행 감사 로그 |
| `tool_result.dart` | ToolResult (success/error) sealed class |
| `llm_engine.dart` | LLM 엔진 인터페이스 |
| `agent_strategy.dart` | Agent 전략 인터페이스 |
| `agent_tool.dart` | 기본 Tool 인터페이스 |
| `extended_tool.dart` | 네이티브 접근이 필요한 Tool 인터페이스 |
| `tool_context.dart` | 네이티브 MethodChannel 인터페이스 |

### `lib/agent/tools/` — 에이전트 Tool 구현체

| Tool | 파일 | 타입 | 상태 |
|------|------|------|------|
| `calculator` | `calculator_tool.dart` | AgentTool | **활성** |
| `notepad` | `notepad_tool.dart` | AgentTool | **활성** |
| `timer` | `timer_tool.dart` | AgentTool | **활성** |
| `app_launcher` | `app_launcher_tool.dart` | ExtendedTool | **활성** (패키지 매니저 필요) |
| `screen_action` | `screen_action_tool.dart` | ExtendedTool | **활성** (접근성 서비스 필요) |
| `screen_reader` | `screen_reader_tool.dart` | ExtendedTool | **활성** (접근성 서비스 필요) |
| `notification_reader` | `notification_tool.dart` | ExtendedTool | **활성** (알림 접근 필요) |
| `sms_sender` | `sms_sender_tool.dart` | ExtendedTool | **활성** (SMS 권한 필요) |
| `phone_caller` | `phone_caller_tool.dart` | ExtendedTool | **활성** (전화 권한 필요) |
| `contact_search` | `contact_search_tool.dart` | ExtendedTool | **활성** (연락처 권한 필요) |
| `device_info` | `device_info_tool.dart` | ExtendedTool | **활성** |

### `lib/data/` — 데이터 계층

**역할**: Repository 구현체, 데이터 소스, 외부 API 통신.

#### Providers (LLM 통신)

| 파일 | 역할 |
|------|------|
| `openai_client.dart` | Dio HTTP + SSE 스트리밍 파싱, tool schema 변환 |
| `llm_remote_session.dart` | 메시지 히스토리 관리 + tool result 주입 |
| `llm_remote_engine.dart` | LlmEngine 구현체, 세션 생성/관리 |
| `tool_context_impl.dart` | MethodChannel 기반 ToolContext 구현 |

#### Repositories

| 파일 | 역할 |
|------|------|
| `conversation_repository_impl.dart` | 대화/메시지 CRUD (Drift SQLite) |
| `llm_repository_impl.dart` | LLM 상태 관리, 세션 생성 |
| `settings_repository_impl.dart` | SharedPreferences 기반 설정 영속성 |
| `note_repository_impl.dart` | 메모 CRUD (Drift SQLite) |
| `update_repository_impl.dart` | APK 다운로드/설치 (GitHub Releases) |

#### Data Sources

| 파일 | 역할 |
|------|------|
| `database.dart` | Drift SQLite 데이터베이스 |
| `tables.dart` | 테이블 정의 |
| `github_api.dart` | GitHub Releases API |

#### Services

| 파일 | 역할 |
|------|------|
| `overlay_service.dart` | 오버레이 상태 표시/숨김 |
| `foreground_service.dart` | 포그라운드 서비스 제어 |

### `lib/domain/entities/` — 엔티티 (Freezed)

| 파일 | 역할 |
|------|------|
| `agent_models.dart` | AgentStep, AgentResult |
| `chat_message.dart` | ChatMessage |
| `conversation.dart` | Conversation |
| `llm_provider_config.dart` | LlmProviderConfig, LlmModelInfo |
| `service_state.dart` | ServiceState enum |
| `update_info.dart` | UpdateInfo |

### `lib/domain/repositories/` — Repository 인터페이스

| 파일 | 역할 |
|------|------|
| `conversation_repository.dart` | 대화/메시지 CRUD 인터페이스 |
| `llm_repository.dart` | LLM 상태/세션 인터페이스 |
| `settings_repository.dart` | 설정 읽기/쓰기 인터페이스 |
| `note_repository.dart` | 메모 CRUD 인터페이스 |
| `update_repository.dart` | 업데이트 확인/다운로드/설치 인터페이스 |

### `lib/presentation/` — 프레젠테이션 계층

#### Providers (Riverpod)

| 파일 | 역할 |
|------|------|
| `chat_notifier.dart` | 채팅 상태 관리, 메시지 송수신 |
| `settings_notifier.dart` | 설정 상태 관리 |
| `update_notifier.dart` | 업데이트 상태 관리 |
| `agent_provider.dart` | AgentStrategy Provider |
| `conversation_provider.dart` | ConversationRepository Provider |
| `llm_provider.dart` | LlmRepository Provider |
| `settings_provider.dart` | SettingsRepository Provider |
| `update_provider.dart` | UpdateRepository Provider |
| `overlay_assistant_provider.dart` | 오버레이 보조 Provider |
| `chat_providers.dart` | ChatState Provider |
| `chat_state.dart` | ChatState (Freezed) |
| `settings_state.dart` | SettingsState (Freezed) |
| `update_state.dart` | UpdateState (Freezed) |

#### Screens

| 파일 | 역할 |
|------|------|
| `chat_screen.dart` | 메인 채팅 화면 |
| `settings_screen.dart` | 설정 메인 화면 |
| `provider_settings_screen.dart` | AI 제공자 설정 화면 |
| `inference_settings_screen.dart` | 추론 파라미터 설정 화면 |
| `permission_management_screen.dart` | 권한 관리 화면 |

#### Widgets

| 파일 | 역할 |
|------|------|
| `message_bubble.dart` | 유저/어시스턴트 말풍선 |
| `input_bar.dart` | 메시지 입력 + 전송/정지 |
| `session_drawer.dart` | 세션 관리 Drawer |
| `connection_status_badge.dart` | 연결 상태 뱃지 |
| `loading_indicator.dart` | 로딩 인디케이터 |
| `section_card.dart` | 설정 섹션 카드 |
| `nav_tile.dart` | 네비게이션 타일 |

### `lib/core/` — 공통 유틸리티

| 파일 | 역할 |
|------|------|
| `theme/theme.dart` | Material ThemeData |
| `theme/app_colors.dart` | 색상 상수 |
| `theme/app_strings.dart` | 중앙화된 한국어 문자열 |
| `theme/time_formatter.dart` | 시간 포맷 유틸리티 |
| `router/router.dart` | GoRouter 라우팅 |

## LLM Engine Architecture

### Dio + SSE 구조

```
ReactStrategy
  │
  ├─ OpenAiClient (Dio HTTP)
  │   → POST /v1/chat/completions with stream: true
  │   → ResponseBody stream → SSE data: lines → LlmResponseChunk 파싱
  │   → Tool schemas를 OpenAI function-calling JSON으로 변환
  │
  └─ LlmRemoteSession
      → _messages: List<Map<String, dynamic>> (OpenAI format)
      → addToolResult(): tool 결과를 role: tool 메시지로 추가
      → chat(): userParts + 전체 히스토리를 API에 전송
```

### Streaming Flow

```
Dio.post() → ResponseBody stream → utf8 decode
  → SSE data: lines → JSON 파싱
  → delta.tool_calls[] 추출
  → Map<int, _ToolCallBuilder>가 chunk 누적
  → 완전한 tool call 구성 후 실행
```

## Agent System

### 단일 루프 ReAct 구조

```
User Input → ChatNotifier.sendMessage() → ReactStrategy.execute()
  → for 루프 (최대 8회, 타임아웃 120초):
      1. LlmRemoteSession.chat() — LLM에 tool schemas 전달, SSE 응답 수신
      2. LLM 응답이 tool_calls → Safety Pipeline 통과 후 실행
      3. LLM 응답이 text → Answer 반환 (루프 종료)
      4. LLM 응답이 비어있음 → 넛지 후 재시도 (max 2회)
```

### Safety Pipeline

1. **PermissionGate** — Android 런타임 권한 확인/요청
2. **RiskClassifier** — tool + args 기반 위험도 분류
3. **Tool.validate()** — args 유효성 검증
4. **ConfirmationGate** — HIGH/CRITICAL 위험도 시 사용자 승인 요청
5. **Tool.execute()** — 실제 실행
6. **ErrorRecovery** — 실패 시 에러 분류 + 복구 힌트
7. **LoopDetector** — 반복 감지 (3-strike)
8. **AuditLog** — 실행 감사 로그 기록

## State Management (Riverpod)

```
ChatNotifier (StateNotifier<ChatState>)
├─ messages: List<ChatMessage>
├─ currentResponse: String
├─ serviceState: ServiceState
├─ errorMessage: String?
├─ agentSteps: List<AgentStep>
├─ isConfirming: bool
├─ isAwaitingPermission: bool
├─ currentConversationId: String?
├─ currentConversationTitle: String
│
├─ sendMessage(text, {temperature, maxTokens, topP, agentMaxIterations})
├─ stopGeneration()
├─ resolveConfirmation(approved)
├─ resolvePermission(userTappedGrant)
├─ createNewChat()
├─ switchConversation(id, title)
├─ deleteConversation(id)
└─ initializeSession()

SettingsNotifier (StateNotifier<SettingsState>)
├─ providerConfig: LlmProviderConfig?
├─ temperature, topP, maxTokens, agentMaxIterations
├─ connect/disconnect provider
└─ update inference parameters

UpdateNotifier (StateNotifier<UpdateState>)
├─ status: UpdateStatus
├─ updateInfo: UpdateInfo?
├─ downloadProgress: double
├─ downloadedFilePath: String?
└─ checkForUpdate/downloadApk/installApk
```

## Storage (Drift SQLite)

```
Database: aios_db
├── conversations: { id (PK), title, createdAt, updatedAt }
├── messages: { id (PK), conversationId (index), role, content, createdAt, toolName, toolArgs, toolResult }
└── notes: { key (PK), value, updatedAt }
```

## Key Design Decisions

### Why Flutter?

- 크로스 플랫폼 (Android 우선, iOS 확장 가능)
- 네이티브 접근 (MethodChannel, AccessibilityService)
- 풍부한 UI 프레임워크 + 핫 리로드
- Dart의 강력한 타입 시스템

### Why Riverpod?

- 컴파일 타임 안전성 (Provider key 중복 방지)
- StateNotifier로 명확한 상태 전이
- 의존성 주입 (Provider override로 테스트 용이)

### Why Freezed?

- Immutable 데이터 클래스 자동 생성
- copyWith, equality, toString 보일러플레이트 제거
- sealed class 패턴으로 상태 모델링

### Why Drift (SQLite)?

- Flutter 네이티브 SQLite 지원
- 타입 안전한 쿼리 빌더
- 마이그레이션 관리

### Why Dio + SSE?

- 스트리밍 응답 처리 (ReadableStream)
- HTTP 클라이언트 고급 기능 (인터셉터, 타임아웃)
- 추가 의존성 없이 스트리밍 가능
