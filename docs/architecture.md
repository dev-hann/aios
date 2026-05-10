# Architecture

AIOS의 내부 아키텍처를 설명합니다.

## System Overview

AIOS는 **Dart Layer** (UI + logic)와 **Remote OpenAI-compatible API** (LLM 추론) 두 파트로 구성됩니다.

Dart Layer 내부는 Clean Architecture 기반 **3계층 + Core** 구조를 따릅니다.

```
┌──────────────────────────────────────────────────────────────┐
│                        Dart Layer                             │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Presentation                                          │  │
│  │  Flutter Widgets + Riverpod + GoRouter                 │  │
│  └──────────────────────────┬─────────────────────────────┘  │
│                             │                                  │
│  ┌──────────────────────────▼─────────────────────────────┐  │
│  │  Domain                                                 │  │
│  │  Entities (freezed) + Repository Interfaces (abstract)  │  │
│  │  Agent System: Strategy, Tools, Safety Pipeline         │  │
│  └──────────────────────────┬─────────────────────────────┘  │
│                             │                                  │
│  ┌──────────────────────────▼─────────────────────────────┐  │
│  │  Data                                                   │  │
│  │  Repository Impls + DataSource (Drift, Dio)             │  │
│  │  LlmRemoteEngine + OpenAiClient + ToolContextImpl       │  │
│  └──────────────────────────┬─────────────────────────────┘  │
└─────────────────────────────┼────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         ▼                                         ▼
┌─────────────────────┐               ┌─────────────────────────┐
│  Remote LLM API     │               │  Android Native          │
│  OpenAI-compatible  │               │  AccessibilityService    │
│  (glm-4.5-air       │               │  OverlayService          │
│   via z.ai)         │               │  MethodChannel           │
│  HTTP/SSE streaming │               └─────────────────────────┘
└─────────────────────┘
```

## Layer Rules

### Domain (`lib/domain/`)

**역할**: 비즈니스 로직의 핸심. 외부 의존성 없이 순수 Dart로만 구성.

| 하위 디렉토리 | 역할 |
|--------------|------|
| `entities/` | 불변 데이터 모델 (freezed) |
| `repositories/` | Repository 인터페이스 (abstract class) |
| `agent/` | 에이전트 전략, Safety Pipeline, 컨텍스트 추적 |

**규칙**:
- Domain은 Data, Presentation, 외부 패키지를 import하지 않음
- 모든 외부 접근은 Repository 인터페이스를 통해 추상화

### Data (`lib/data/`)

**역할**: Domain 인터페이스의 구현체. 외부 API, DB, 파일시스템, 네이티브 채널 접근.

| 하위 디렉토리 | 역할 |
|--------------|------|
| `repositories/` | Domain Repository 구현체 |
| `datasources/local/` | 로컬 저장소 (Drift/SQLite) |
| `datasources/remote/` | 원격 API (GitHub Releases 등) |
| `providers/remote/` | LLM 엔진 (LlmRemoteEngine, OpenAiClient) |
| `providers/` | ToolContextImpl (MethodChannel) |
| `services/` | OverlayService 등 플랫폼 서비스 |

**규칙**:
- Data는 Domain을 참조 가능
- Data는 Presentation을 참조하지 않음
- Repository 구현체는 Domain의 인터페이스를 구현

### Presentation (`lib/presentation/`)

**역할**: UI와 상태 관리. Riverpod으로 Domain/Data 계층 사용.

| 하위 디렉토리 | 역할 |
|--------------|------|
| `screens/` | 화면 단위 Widget (기능별 서브디렉토리) |
| `widgets/` | 재사용 UI 컴포넌트 |
| `providers/` | Riverpod Provider + StateNotifier + State 클래스 |

**규칙**:
- Presentation은 Domain 인터페이스를 통해서만 Data에 접근
- 직접 DataSource 참조 금지
- 상태 관리는 Riverpod만 사용 (GetX, Bloc, Provider 금지)
- 라우팅은 GoRouter만 사용

### Agent Tools (`lib/agent/tools/`)

**역할**: 독립적인 Tool 구현체. Domain의 `AgentTool` 또는 `ExtendedTool` 인터페이스 구현.

**Tool 인터페이스**:

| 인터페이스 | 용도 |
|-----------|------|
| `AgentTool` | 플랫폼 채널 불필요 (순수 Dart 계산 등) |
| `ExtendedTool` | MethodChannel 필요 (화면 조작, 앱 실행 등) |

**규칙**:
- Tool에서 예외 throw 금지 → `"Error: ..."` 문자열 반환
- 각 Tool은 `execute()`, `validate()`, `toolPrompt`, `phaseContext()` 구현
- 새 Tool 추가 시 `agent_provider.dart`에 등록 + `RiskClassifier`에 위험도 분류 추가

### Core (`lib/core/`)

**역할**: 모든 계층에서 공유하는 유틸리티.

| 하위 디렉토리 | 역할 |
|--------------|------|
| `router/` | GoRouter 화면 라우팅 설정 |
| `theme/` | 색상 상수, ThemeData (Light/Dark) |

## LLM Engine Architecture

### Remote API 구조

```
ReactStrategy
  │
  ├─ LlmEngine (abstract interface, domain/agent/llm_engine.dart)
  │   ├─ LlmToolSchema: tool 이름, 설명, 파라미터 스키마
  │   ├─ LlmChatSession: 대화 히스토리 + tool result 주입
  │   └─ LlmResponseChunk: streaming 응답 (text + toolCallDeltas)
  │
  └─ LlmRemoteEngine (concrete, data/providers/remote/)
      ├─ OpenAiClient: HTTP/SSE → OpenAI-compatible API
      │   → POST /chat/completions with stream: true
      │   → SSE data: lines → LlmResponseChunk 파싱
      │   → Tool schemas를 OpenAI function-calling JSON으로 변환
      │
      └─ LlmRemoteSession: 메시지 히스토리 관리
          → _messages: List<Map<String, dynamic>> (OpenAI format)
          → addToolResult(): tool 결과를 role: tool 메시지로 추가
          → chat(): userParts + 전체 히스토리를 API에 전송
```

### Tool Schema 변환

```dart
// Dart LlmToolSchema → OpenAI function format
{
  "type": "function",
  "function": {
    "name": "screen_action",
    "description": "Control the device screen...",
    "parameters": {
      "type": "object",
      "properties": {
        "action": {"type": "string", "enum": ["tap","type","scroll",...]},
        "content": {"type": "string", "description": "..."}
      },
      "required": ["action"]
    }
  }
}
```

### Streaming Flow

```
OpenAiClient.streamChat()
  → Dio POST with responseType: ResponseType.stream
  → SSE data: lines → JSON 파싱
  → delta.tool_calls[] 추출
  → LlmResponseChunk(toolCallDeltas: [LlmToolCallDelta(index, id, name, arguments)])
  → ReactStrategy._ToolCallAccumulator가 chunk 누적
  → 완전한 tool call 구성 후 실행
```

## Agent System

### 단일 루프 ReAct 구조

OpenAI function-calling API를 사용하는 **단일 루프** 구조입니다.

```
User Input → ChatNotifier → ReactStrategy.execute()
  → for 루프 (최대 8회, 타임아웃 120초):
      1. LlmRemoteSession.chat() — LLM에 tool schemas 전달, SSE streaming 응답 수신
      2. LLM 응답이 tool_calls → Safety Pipeline 통과 후 실행
      3. LLM 응답이 text → Answer 반환 (루프 종료)
      4. LLM 응답이 비어있음 → 넛지 후 재시도 (max 2회)
```

**핵심 원칙**:
- LLM이 직접 tool 선택 및 args 생성 (OpenAI function-calling)
- SSE streaming으로 LlmToolCallDelta 수신
- `_ToolCallAccumulator`가 chunk를 누적하여 완전한 tool call 구성
- Multi-tool chaining: 이전 Tool 결과가 자동으로 다음 LLM 호출에 포함
- Context Tracking: 대화 맥락(최근 5턴)과 Tool 사용 빈도(top 3)가 system prompt에 주입
- 빈 args 추론: calculator/notepad/timer에 한해 heuristic 추론 (`_inferToolArgs`)

### Safety Pipeline

모든 Tool 실행은 아래 순서를 거칩니다:

1. **PermissionGate** — Android 권한 확인 (카메라, 연락처 등)
2. **RiskClassifier** — tool + args 기반 위험도 분류 (safe/low/high/critical)
3. **Tool.validate()** — args 유효성 검증
4. **ConfirmationGate** — HIGH/CRITICAL 위험도 시 사용자 승인 요청
5. **Tool.execute()** — 실제 실행
6. **AuditLog** — 실행 기록
7. **ErrorRecovery** — 실패 시 에러 분류 및 복구 힌트 (8가지 타입)
8. **LoopDetector** — 반복 감지 및 강제 종료 (3-strike)

### Error Recovery 규칙

- 에러 분류 후 복구 가능한 경우에만 재시도
- Tool별 최대 1회 재시도
- 실행 간 복구 상태 초기화
- 에러 판별: `"Error:"` 문자열 prefix로 감지

## State Management

### Riverpod Provider 스코프

| 스코프 | 용도 | 예시 |
|--------|------|------|
| `keepAlive: true` | 앱 전역 싱글톤 | Repository, DataSource, LlmEngine |
| Screen-scoped | 화면 단위 상태 | Notifier, UI State |

## Threading

| 역할 | 위치 |
|------|------|
| LLM 추론 | 원격 API (HTTP/SSE) |
| 에이전트 실행 | Main Isolate에서 실행, Stream으로 UI 전달 |
| 플랫폼 채널 | MethodChannel / EventChannel (Android 네이티브) |
| UI 업데이트 | Main Isolate |
| 취소 | 취소 플래그 + StreamController.close() |

## Key Design Decisions

### Why OpenAI-compatible Tool Calling?

- 텍스트 파싱(Action:/Answer:) 없이 LLM이 직접 tool 선택
- 프롬프트 엔지니어링 부담 감소 (포맷 넛지, 재시도 로직 불필요)
- OpenAI function-calling 표준으로 다양한 LLM 백엔드 교체 가능

### Why Remote API over On-device?

- 소형 온디바이스 모델 대비 높은 tool-calling 정확도
- 기기 리소스(CPU/메모리/배터리) 절약
- 모델 업데이트 시 앱 업데이트 불필요

### Why Flutter?

- 단일 언어 (Dart)로 유지보수 간소화
- Android/iOS 크로스 플랫폼
- 접근성 서비스 + MethodChannel으로 네이티브 제어

### Why ReAct?

- 투명한 추론 과정 (visible thought/action/observation steps)
- 관찰 기반 Tool 사용
- 자연스러운 종료 조건 (LLM이 text 응답 시 루프 종료)
- Multi-tool chaining 지원
