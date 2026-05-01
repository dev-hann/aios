# Architecture

This document describes the internal architecture of AIOS in detail.

## System Overview

AIOS follows a **2-layer architecture**: Kotlin (UI + services) and C++ (inference). The two layers communicate via JNI (Java Native Interface).

```
┌──────────────────────────────────────────────────────────────┐
│                        Kotlin Layer                          │
│                                                              │
│  ┌────────────────┐  ┌─────────────┐  ┌──────────────────┐  │
│  │  Compose UI    │  │ AIOSApp     │  │ AgentEngine      │  │
│  │  (Screens)     │──│ (App Class) │──│ (ReAct Loop)     │  │
│  └────────────────┘  └──────┬──────┘  └────────┬─────────┘  │
│                             │                   │            │
│  ┌──────────────────────────▼───────────────────▼──────────┐ │
│  │                    LlmService                           │ │
│  │              (Foreground Service)                        │ │
│  └──────────────────────────┬──────────────────────────────┘ │
│                             │                                │
│  ┌──────────────────────────▼──────────────────────────────┐ │
│  │                  LlamaBridge (JNI)                       │ │
│  └──────────────────────────┬──────────────────────────────┘ │
└─────────────────────────────┼────────────────────────────────┘
                              │
┌─────────────────────────────▼────────────────────────────────┐
│                        C++ Layer                              │
│  ┌──────────────────────────────────────────────────────────┐│
│  │                  native-lib.cpp                           ││
│  │     llama_model_load / llama_tokenize / llama_decode     ││
│  └──────────────────────────────────────────────────────────┘│
│  ┌──────────────────────────────────────────────────────────┐│
│  │                  llama.cpp (static)                       ││
│  └──────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────┘
```

## Module Details

### 1. Compose UI Layer

**Files**: `ui/screen/`, `ui/component/`, `ui/viewmodel/`, `ui/navigation/`

| Component | File | Role |
|-----------|------|------|
| ChatScreen | `ChatScreen.kt` | Main chat UI with dual mode (chat/agent) |
| DashboardScreen | `DashboardScreen.kt` | Permission management (Accessibility, Notifications, Overlay) |
| SettingsScreen | `SettingsScreen.kt` | App settings, model management |
| ChatViewModel | `ChatViewModel.kt` | State management: messages, generation state, model status |
| AIOSNavGraph | `AIOSNavGraph.kt` | Navigation host with bottom navigation |
| MessageBubble | `MessageBubble.kt` | Renders chat messages and agent steps |
| ModelPicker | `ModelPicker.kt` | Bottom sheet for model selection |
| StatusBar | `StatusBar.kt` | Model loading / generation status display |

**State Flow**:
```
User Input → ChatViewModel.sendMessage()
    ├── CHAT mode → AIOSApp.generateStream() → tokenFlow → UI
    └── AGENT mode → AIOSApp.runAgent() → agentStepFlow → UI
```

### 2. AIOSApp (Application Class)

**File**: `AIOSApp.kt`

Central coordinator that manages:
- **Service binding** — Binds to `LlmService` and manages lifecycle
- **State flows** — `_serviceState`, `_tokenFlow`, `_agentStepFlow` (SharedFlow)
- **Model lifecycle** — `loadModel()`, `unloadModel()`
- **Entry points**:
  - `generateStream(prompt, onToken, onComplete)` — Direct LLM generation
  - `runAgent(message, onStep, onComplete)` — Agent mode execution

**Service States**:
```
DISCONNECTED → CONNECTING → READY → MODEL_LOADED → GENERATING → AGENT_RUNNING
```

### 3. LlmService (Foreground Service)

**File**: `LlmService.kt`

Android foreground service that:
- Keeps the app alive during inference
- Shows a persistent notification
- Wraps `LlamaBridge` JNI calls
- Provides `generateStream()` and `generate()` methods

### 4. LlamaBridge (JNI Declarations)

**File**: `LlamaBridge.kt`

Kotlin-side JNI declarations:
- `nativeLoadModel(path: String): Boolean`
- `nativeUnloadModel()`
- `nativeGenerateStream(prompt: String, callback: (String) -> Unit): String`
- `nativeGenerate(prompt: String): String`
- `nativeTokenize(text: String): IntArray`

### 5. AgentEngine (ReAct Loop)

**File**: `AgentEngine.kt`

Implements the ReAct (Reason + Act) pattern:

```
┌─────────────────────────────────┐
│         ReAct Loop              │
│                                 │
│  1. Build Prompt                │
│     ├─ System prompt (tools)    │
│     ├─ User message             │
│     └─ Conversation history     │
│                                 │
│  2. LLM Generate                │
│     └─ Streaming tokens         │
│                                 │
│  3. Parse Response              │
│     ├─ Action: tool → Execute   │
│     │   └─ Args: JSON params    │
│     ├─ Answer: text → Return    │
│     └─ Plain text → Return      │
│                                 │
│  4. If Action:                  │
│     ├─ Execute tool             │
│     ├─ Get observation          │
│     └─ Append to history, loop  │
│                                 │
│  Max iterations: 5              │
└─────────────────────────────────┘
```

**Tool Categories**:

| Category | Registration | Access |
|----------|-------------|--------|
| Basic Tools | `basicTools` map in `AgentTools.kt` | Self-contained, no Android context |
| Extended Tools | `extendedTools` map in `AgentEngine` | Requires `Context`, `AccessibilityService` |

### 6. Agent Tools

#### Basic Tools (`AgentTools.kt`)

| Tool | Input | Output |
|------|-------|--------|
| `calculator` | Math expression | Computed result |
| `timer` | Seconds (1-300) | Confirmation after sleep |
| `device_info` | None | Device model, OS version, memory |
| `notepad` | Action + text | Save/get/list/delete notes |

#### Extended Tools (`agent/tools/`)

| Tool | File | Capabilities |
|------|------|-------------|
| `screen_reader` | `ScreenReaderTool.kt` | Read all visible text on screen |
| `screen_find` | `ScreenReaderTool.kt` | Find UI elements by text/description |
| `screen_action` | `ScreenActionTool.kt` | tap, long_click, type, scroll, swipe, global actions |
| `app_launcher` | `AppLauncherTool.kt` | Open apps by package, URLs, system settings |
| `notification_reader` | `NotificationTool.kt` | Read recent system notifications |

### 7. Android Services

| Service | File | Purpose |
|---------|------|---------|
| AIOSAccessibilityService | `service/AIOSAccessibilityService.kt` | Screen tree access, element interaction, gesture dispatch |
| NotificationListener | `service/NotificationListener.kt` | System notification interception and caching |
| OverlayService | `service/OverlayService.kt` | Floating AI button overlay on top of other apps |

### 8. Native Layer (C++)

**File**: `cpp/native-lib.cpp`

JNI function implementations:
- `nativeLoadModel` — Loads GGUF model via `llama_model_load()`
- `nativeGenerateStream` — Streaming generation with `llama_decode()` loop
- `nativeGenerate` — Synchronous generation
- `nativeTokenize` — Text to token IDs via `llama_tokenize()`

**Sampling Parameters**:
- Temperature: 0.7
- Top-K: 40
- Top-P: 0.9
- Repeat penalty: 1.1

**Chat Template**: Applied via `llama_chat_apply_template()` for model-specific formatting.

## Data Flow: Complete Request Lifecycle

### Chat Mode

```
1. User types message in ChatScreen
2. ChatViewModel.sendMessage() called
3. Mode check: CHAT → AIOSApp.generateStream()
4. AIOSApp calls LlmService.generateStream()
5. LlmService calls LlamaBridge.nativeGenerateStream()
6. JNI → native-lib.cpp → llama.cpp inference
7. Each token → onTokenCallback → SharedFlow → ChatViewModel → UI update
8. Generation complete → onComplete callback
```

### Agent Mode

```
1. User types message in ChatScreen
2. ChatViewModel.sendMessage() called
3. Mode check: AGENT → AIOSApp.runAgent()
4. AgentEngine.run() starts ReAct loop
5. Each iteration:
   a. Build prompt (system + user + history)
   b. LLM generates response
   c. Parse response:
      - "Action: tool_name\nArgs: {...}" → executeTool()
      - "Answer: text" → return as final
   d. Tool execution → observation string
   e. Append to conversation history
   f. Emit AgentStep to SharedFlow → UI update
6. Loop ends (answer found or max iterations)
7. List<AgentStep> returned → UI renders all steps
```

## Key Design Decisions

### Why Native Android over Flutter?

| Factor | Flutter | Native |
|--------|---------|--------|
| Accessibility Service | Indirect (MethodChannel) | Direct API access |
| JNI hops | 3 (Flutter→Kotlin→C++) | 2 (Kotlin→C++) |
| APK size | Larger (Flutter engine) | Smaller |
| Platform relevance | Cross-platform (iOS irrelevant for phone control) | Single platform focus |
| Development complexity | 3-layer architecture | 2-layer architecture |

### Why ReAct over other Agent Patterns?

ReAct (Reason + Act) provides:
- Transparent reasoning (visible "thought" steps)
- Tool-use grounded in observation
- Natural stop condition (Answer output)
- Simple to implement and debug

### Why llama.cpp Direct (No Wrapper)?

- Minimal dependency overhead
- Direct control over sampling and KV cache
- Smaller binary size
- Easier to update to latest llama.cpp versions
