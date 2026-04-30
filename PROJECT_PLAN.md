# AIOS - Android Local LLM Agent Runtime

## On-device AI OS: Control your phone with AI

Native Android (Kotlin + Jetpack Compose) + llama.cpp Runtime = Personal AI OS

---

## System Architecture

```
[Jetpack Compose UI Layer]
        | ViewModel / StateFlow
[AIOSApp (Application)]
        | Service Binding
[LlmService (Foreground Service)]
        | JNI Bridge
[Native C++ Runtime (llama.cpp)]
        |
[GGUF Model Files (Local Storage)]

[AIOSAccessibilityService]
        | AccessibilityNodeInfo
[Screen Reader / Screen Action Tools]

[OverlayService]
        | System Alert Window
[Floating AI Button (Any App)]
```

---

## Migration from Flutter to Native Android (v2)

### Why Native?
- iOS is impossible for full phone control (strict sandboxing)
- Flutter's cross-platform advantage is irrelevant
- Direct access to AccessibilityService, NotificationListener, System APIs
- Simpler architecture: 2-layer (Kotlin → C++) instead of 3-layer (Flutter → Kotlin → C++)
- Better performance and smaller APK

### Architecture Comparison

| Layer | Flutter (v1) | Native (v2) |
|---|---|---|
| UI | Flutter/Dart | Jetpack Compose |
| State | MethodChannel/EventChannel | StateFlow/SharedFlow |
| Service Bridge | FlutterActivity | ComponentActivity + AIOSApp |
| LLM Service | Same | Same |
| Native Bridge | JNI (3 hops) | JNI (2 hops) |
| Phone Control | N/A | AccessibilityService |

---

## Phase 1: Core Runtime (COMPLETED)
- [x] llama.cpp build + CMake integration
- [x] JNI Bridge (Kotlin <-> C++)
- [x] Streaming token generation
- [x] Foreground Service
- [x] Model management

## Phase 2: Native UI (COMPLETED)
- [x] Jetpack Compose setup (Material3)
- [x] Chat screen with message bubbles
- [x] Agent mode with step visualization
- [x] Model picker bottom sheet
- [x] Status indicator
- [x] Navigation (Chat / Dashboard / Settings)

## Phase 3: Phone Control (COMPLETED)
- [x] AccessibilityService integration
  - Screen text reading
  - Element search (by text/description)
  - Click, long click, type, scroll
  - Gesture dispatch (tap, swipe)
  - Global actions (back, home, recents)
- [x] Agent tools: screen_reader, screen_find, screen_action
- [x] Agent tool: app_launcher (open apps, URLs, settings)
- [x] NotificationListener service
- [x] Agent tool: notification_reader
- [x] OverlayService (floating AI button)
- [x] Permission management UI (Dashboard)

## Phase 4: Polish & Advanced (PENDING)
- [ ] Context window management
- [ ] Multi-turn conversation history
- [ ] Agent tool: contact_search (read contacts)
- [ ] Agent tool: sms_sender (send SMS)
- [ ] Agent tool: phone_caller (make calls)
- [ ] Security sandbox for agent actions
- [ ] User confirmation for sensitive actions
- [ ] Settings persistence (DataStore)
- [ ] Model download manager
- [ ] Performance optimization (thread tuning, quantization)
- [ ] CI/CD pipeline

---

## Tech Stack

- Kotlin 2.2.20
- Jetpack Compose (Material3)
- Navigation Compose
- Lifecycle/ViewModel Compose
- Coroutines + Flow
- Android NDK 27.2 + CMake
- llama.cpp (C/C++)
- Accessibility Service API
- Notification Listener Service
- System Alert Window (Overlay)

## Key Principles

- LLM is Runtime, not UI
- Model loaded once, reused across interactions
- Queue-based sequential inference
- Interface separation (UI <-> ViewModel <-> Service <-> Native)
- Privacy-first: everything runs on-device
- Phone control through accessibility API
