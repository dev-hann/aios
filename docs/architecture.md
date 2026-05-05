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
│  └──────────────────────────┬─────────────────────────────┘  │
│                             │                                  │
│  ┌──────────────────────────▼─────────────────────────────┐  │
│  │  Data                                                   │  │
│  │  Repository Impls + DataSource (Drift, Dio)             │  │
│  │  LlamaEngineProvider (llama_cpp_dart 추상화)            │  │
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

| 하위 디렉토리 | 역할 | 예시 |
|--------------|------|------|
| `entities/` | 불변 데이터 모델 (freezed) | `ChatMessage`, `ModelInfo`, `ServiceState`, `UpdateInfo` |
| `repositories/` | Repository 인터페이스 (abstract class) | `LlmRepository`, `SettingsRepository`, `ConversationRepository` |
| `agent/` | 에이전트 전략, 파서, 위험 분류 | `ReactStrategy`, `ResponseParser`, `RiskClassifier` |

**규칙**: Domain은 Data, Presentation, 외부 패키지를 import하지 않음.

### Data Layer (`lib/data/`)

Domain 인터페이스의 구현체. 외부 API, DB, 파일시스템 접근.

| 하위 디렉토리 | 역할 | 예시 |
|--------------|------|------|
| `repositories/` | Domain Repository 구현체 | `LlmRepositoryImpl`, `UpdateRepositoryImpl` |
| `datasources/local/` | 로컬 저장소 (Drift/SQLite) | `AppDatabase`, `tables.dart` |
| `datasources/remote/` | 원격 API | `GitHubApi` (GitHub Releases, Dio) |
| `providers/` | 외부 엔진 추상화 | `LlamaEngineProvider` (llama_cpp_dart 래핑) |

**규칙**: Data는 Domain을 참조 가능. Presentation은 참조하지 않음.

### Presentation Layer (`lib/presentation/`)

UI와 상태 관리. Riverpod으로 Domain/Data 계층 사용.

| 하위 디렉토리 | 역할 | 예시 |
|--------------|------|------|
| `screens/` | 화면 단위 Widget | `ChatScreen`, `SettingsScreen`, `UpdateScreen` |
| `widgets/` | 재사용 UI 컴포넌트 | `MessageBubble`, `InputBar`, `StatusBar`, `ModelPicker` |
| `providers/` | Riverpod Provider + StateNotifier | `ChatNotifier`, `chatStateProvider`, `SettingsNotifier` |

**규칙**: Presentation은 Domain 인터페이스를 통해서만 Data에 접근. 직접 DataSource 참조 금지.

### Core Layer (`lib/core/`)

모든 계층에서 공유하는 유틸리티.

| 하위 디렉토리 | 역할 |
|--------------|------|
| `router/` | GoRouter 화면 라우팅 |
| `theme/` | `AppColors` 색상 상수, `aiosTheme` ThemeData |

## Data Flow

### Chat Mode

```
User Input → ChatNotifier.sendMessage()
  → LlmRepository.sendMessage()
    → LlamaEngineProvider.generate() (Isolate)
      → Stream<String> (토큰 단위 스트리밍)
    → ChatState 업데이트 (currentResponse 누적)
  → _finalizeResponse() → ChatMessage 저장 (Drift DB)
```

### Agent Mode (향후 구현)

```
User Input → ChatNotifier → ReactStrategy (ReAct 루프)
  → LlmRepository.generate()
    → ResponseParser (Action/Answer 파싱)
    → RiskClassifier (위험도 분류)
    → ConfirmationGate (HIGH/CRITICAL 승인)
    → Tool 실행 → Observation
  → 루프 반복 (최대 5회) 또는 Answer 반환
```

### Update Flow

```
UpdateScreen → UpdateNotifier.checkForUpdates()
  → UpdateRepositoryImpl → GitHubApi.getLatestRelease()
  → 버전 비교 (package_info_plus)
  → APK 다운로드 (Dio) → 설치 Intent
```

## State Management

### ServiceState (LlmRepository)

```
idle → loadingModel → ready ↔ generating → ready
                          ↘ error ↗
```

### Riverpod Provider 스코프

- **keepAlive: true**: Repository, DataSource, LlmEngine (싱글톤)
- **Screen-scoped**: Notifier, UI 상태 (화면 전환 시 재생성)

## Agent System (향후 구현)

ReAct (Reason + Act) 에이전트 루프:

1. **Build Prompt** — System prompt (tools) + User message + History
2. **LLM Generate** — Streaming tokens
3. **Parse Response** — Action (tool 실행) / Answer (최종 응답)
4. **Tool Execute** → Observation → History에 추가 → 루프 반복

### Tool Categories

| Category | Interface | 특징 |
|----------|-----------|------|
| Basic Tool | `AgentTool` | 플랫폼 채널 불필요 (calculator, timer, device_info, notepad) |
| Extended Tool | `ExtendedTool` | MethodChannel 필요 (screen_reader, screen_action, app_launcher, notification_reader) |

### Agent 실행 흐름

`LlmRepositoryImpl` → `ReactStrategy` → `ResponseParser` → `RiskClassifier` → `ConfirmationGate` → Tool 실행

## Key Design Decisions

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
