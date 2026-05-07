# Architecture

AIOS의 내부 아키텍처를 설명합니다.

## System Overview

AIOS는 **2-layer architecture**를 따릅니다: Dart (UI + logic)과 llama_cpp_dart (inference via Isolate).

```
┌──────────────────────────────────────────────────────────────┐
│                        Dart Layer                             │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Presentation                                          │  │
│  │  Flutter Widgets + Riverpod StateNotifier + GoRouter   │  │
│  └──────────────────────────┬─────────────────────────────┘  │
│                             │                                  │
│  ┌──────────────────────────▼─────────────────────────────┐  │
│  │  Domain                                                 │  │
│  │  Entities (freezed) + Repository Interfaces (abstract)  │  │
│  │  Agent System: ReactStrategy, ResponseParser, Tools     │  │
│  └──────────────────────────┬─────────────────────────────┘  │
│                             │                                  │
│  ┌──────────────────────────▼─────────────────────────────┐  │
│  │  Data                                                   │  │
│  │  Repository Impls + DataSource (Drift, Dio)             │  │
│  │  LlamaEngineProvider (llama_cpp_dart 추상화)            │  │
│  │  ToolContextImpl (MethodChannel 래핑)                   │  │
│  └──────────────────────────┬─────────────────────────────┘  │
└─────────────────────────────┼────────────────────────────────┘
                              │
┌─────────────────────────────▼────────────────────────────────┐
│                   llama_cpp_dart (Isolate)                    │
│  LLM 추론: loadModel / generate / stopGeneration             │
│  KV-cache: saveState / loadState                              │
└──────────────────────────────────────────────────────────────┘
```

## Layers

### Domain Layer (`lib/domain/`)

비즈니스 로직의 핵심. **외부 의존성 없음** (Flutter, DB, 네트워크 모르게).

| 하위 디렉토리 | 역할 | 파일 |
|--------------|------|------|
| `entities/` | 불변 데이터 모델 (freezed) | `chat_message.dart`, `agent_models.dart`, `model_info.dart` |
| `repositories/` | Repository 인터페이스 (abstract class) | `llm_repository.dart`, `settings_repository.dart` |
| `agent/` | 에이전트 전략, 파서, 위험 분류 | `react_strategy.dart`, `response_parser.dart`, `risk_classifier.dart` |

**규칙**: Domain은 Data, Presentation, 외부 패키지를 import하지 않음.

### Data Layer (`lib/data/`)

Domain 인터페이스의 구현체. 외부 API, DB, 파일시스템 접근.

| 하위 디렉토리 | 역할 | 파일 |
|--------------|------|------|
| `repositories/` | Domain Repository 구현체 | `llm_repository_impl.dart`, `update_repository_impl.dart` |
| `datasources/local/` | 로컬 저장소 (Drift/SQLite) | `database.dart`, `tables.dart` |
| `datasources/remote/` | 원격 API | `github_api.dart` (GitHub Releases, Dio) |
| `providers/` | 외부 엔진 추상화 | `real_llama_engine_provider.dart`, `tool_context_impl.dart` |

**규칙**: Data는 Domain을 참조 가능. Presentation은 참조하지 않음.

### Presentation Layer (`lib/presentation/`)

UI와 상태 관리. Riverpod으로 Domain/Data 계층 사용.

| 하위 디렉토리 | 역할 | 파일 |
|--------------|------|------|
| `screens/` | 화면 단위 Widget | `chat_screen.dart`, `settings_screen.dart`, `update_screen.dart` |
| `widgets/` | 재사용 UI 컴포넌트 | `message_bubble.dart`, `input_bar.dart`, `status_bar.dart` |
| `providers/` | Riverpod Provider + StateNotifier | `chat_notifier.dart`, `agent_provider.dart`, `settings_notifier.dart` |

**규칙**: Presentation은 Domain 인터페이스를 통해서만 Data에 접근. 직접 DataSource 참조 금지.

### Agent Tools (`lib/agent/tools/`)

독립적인 Tool 구현체. Domain의 `AgentTool` / `ExtendedTool` 인터페이스 구현.

| Tool | 타입 | 상태 | 설명 |
|------|------|------|------|
| `app_launcher_tool.dart` | ExtendedTool | **활성** | 앱 실행, URL 열기, 앱 목록 조회 |
| `screen_action_tool.dart` | ExtendedTool | **활성** | 화면 탭, 스와이프, 텍스트 입력 |
| `screen_reader_tool.dart` | ExtendedTool | **활성** | 화면 텍스트 읽기, UI 요소 검색 |
| `notification_tool.dart` | ExtendedTool | 비활성 | 알림 읽기 |
| `sms_sender_tool.dart` | ExtendedTool | 비활성 | SMS 전송 |
| `phone_caller_tool.dart` | ExtendedTool | 비활성 | 전화 걸기 |
| `calculator_tool.dart` | BasicTool | 비활성 | 수학 계산 |
| `contact_search_tool.dart` | BasicTool | 비활성 | 연락처 검색 |
| `device_info_tool.dart` | BasicTool | 비활성 | 기기 정보 조회 |
| `notepad_tool.dart` | BasicTool | 비활성 | 메모 작성 |
| `timer_tool.dart` | BasicTool | 비활성 | 타이머 설정 |

### Core Layer (`lib/core/`)

모든 계층에서 공유하는 유틸리티.

| 하위 디렉토리 | 역할 |
|--------------|------|
| `router/` | GoRouter 화면 라우팅 |
| `theme/` | `AppColors` 색상 상수, `aiosTheme` ThemeData |

## Data Flow

### Agent Mode (2-Phase ReAct)

```
User Input → ChatNotifier.sendMessage()
  → ReactStrategy.execute()
    ├─ Phase 1: Routing
    │   → PromptBuilder.buildRoutingPrompt() (최소 프롬프트)
    │   → LlmRepository.sendMessage() → LLM 응답
    │   → ResponseParser.parse()
    │     ├─ ParseAction: tool_name 식별 (args 없음 → Phase 2)
    │     ├─ ParseAction: tool_name 식별 (args 있음 → 바로 실행)
    │     ├─ ParseAnswer: 최종 응답 반환
    │     └─ ParseEmpty: 포맷 넛지 후 재시도
    ├─ Phase 2: Tool-specific execution
    │   → Tool.toolPrompt (tool 전용 프롬프트)
    │   → Tool.phaseContext() (app 리스트 등 컨텍스트)
    │   → PromptBuilder.buildToolPrompt()
    │   → LLM 응답 → Action + Args 파싱
    ├─ Tool Execution
    │   → RiskClassifier.classify() (위험도 분류)
    │   → Tool.validate() (검증)
    │   → ConfirmationGate (HIGH/CRITICAL 승인)
    │   → Tool.execute() → Observation
    └─ 루프 반복 (최대 8회) 또는 Answer 반환
```

### Chat Mode (순수 채팅)

```
User Input → ChatNotifier.sendMessage()
  → LlmRepository.sendMessage()
    → LlamaEngineProvider.generate() (Isolate)
      → Stream<String> (토큰 단위 스트리밍)
    → ChatState 업데이트 (currentResponse 누적)
  → _finalizeResponse() → ChatMessage 저장 (Drift DB)
```

### Update Flow

```
UpdateScreen → UpdateNotifier.checkForUpdates()
  → UpdateRepositoryImpl → GitHubApi.getLatestRelease()
  → 버전 비교 (package_info_plus)
  → APK 다운로드 (Dio) → 설치 Intent
```

## Agent System

### 2-Phase ReAct 구조

Phase 1은 최소 프롬프트(~80 토큰)로 LLM에게 tool 선택만 요청.
Phase 2는 선택된 tool의 전용 프롬프트 + 컨텍스트로 args 포맷팅.

```
PromptBuilder
  ├─ buildRoutingPrompt(manifest)  → Phase 1 system prompt
  └─ buildToolPrompt(name, toolPrompt, extraContext) → Phase 2 system prompt

ReactStrategy
  ├─ Phase 1: _generateResponse(routingSystem)
  │   → ParseAction(toolName, args={})  → Phase 2로
  │   → ParseAction(toolName, args={..}) → 바로 _executeTool()
  │   → ParseAnswer(text) → 최종 응답
  │   → ParseEmpty → 넛지 후 재시도
  └─ Phase 2: _phase2Execute(toolName)
      → Tool.phaseContext()로 컨텍스트 fetch (예: 앱 리스트)
      → LLM이 Action + Args 포맷팅
      → _executeTool() 실행
```

### Tool 인터페이스

| 인터페이스 | 용도 | 메서드 |
|-----------|------|--------|
| `AgentTool` | 플랫폼 채널 불필요 | `execute()`, `validate()`, `toolPrompt`, `phaseContext()` |
| `ExtendedTool` | MethodChannel 필요 | `execute(args, ToolContext)`, `validate(args, ToolContext)`, `toolPrompt`, `phaseContext(args, ToolContext)` |

### Safety Pipeline

모든 Tool 실행 전:

1. **RiskClassifier** — tool name + args 기반 위험도 분류 (LOW/MEDIUM/HIGH/CRITICAL)
2. **Tool.validate()** — args 검증 (package 존재 여부, 필수 파라미터 등)
3. **ConfirmationGate** — HIGH/CRITICAL 위험도 시 사용자 승인 요청
4. **LoopDetector** — 동일 tool + 유사 args 반복 감지 → 넛지 또는 강제 종료
5. **AuditLog** — 모든 tool 실행 기록

## State Management

### ServiceState (LlmRepository)

```
idle → loadingModel → ready ↔ generating → ready
                          ↘ error ↗
```

### Riverpod Provider 스코프

- **keepAlive: true**: Repository, DataSource, LlmEngine (싱글톤)
- **Screen-scoped**: Notifier, UI 상태 (화면 전환 시 재생성)

## Threading

- **CPU 집약 작업 (LLM 추론)**: `LlamaEngine`이 별도 Isolate에서 처리
- **플랫폼 채널**: MethodChannel / EventChannel (Android 네이티브 연동)
- **UI 업데이트**: Main Isolate (기본값, 별도 처리 불필요)
- **에이전트 실행**: LlmEngine Isolate에서 실행, Stream으로 UI에 전달
- **취소**: 취소 플래그 + StreamController.close() 조합

## Key Design Decisions

### Why 2-Phase ReAct?

- **Phase 1 최소 프롬프트** (~80 토큰)로 빠른 tool 선택
- **Phase 2 tool 전용 프롬프트**로 정확한 args 포맷팅
- 전체 시스템 프롬프트를 매번 보내지 않아 **토큰 절약**
- `phaseContext()`로 tool 실행에 필요한 컨텍스트를 동적 fetch

### Why Flutter?

- JNI + C++ ~1500줄 → llama_cpp_dart ~20줄
- 단일 언어 (Dart)로 유지보수 간소화
- Isolate 기반으로 Foreground Service 불필요
- KV-cache, Context shift 등 고급 기능 패키지에서 지원

### Why ReAct?

- 투명한 추론 과정 (visible "thought" steps)
- 관찰 기반 Tool 사용
- 자연스러운 종료 조건 (Answer output)
- 구현/디버그 단순
