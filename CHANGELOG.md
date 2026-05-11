# Changelog

All notable changes to AIOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **Gyo Migration**: Migrated from Flutter/Dart to Gyo Framework (React + TypeScript + WebView)
  - React functional components + hooks replace Flutter widgets
  - Zustand replaces Riverpod for state management
  - IndexedDB (idb) replaces Drift (SQLite) for storage
  - fetch + SSE replaces Dio for LLM API communication
  - CSS Custom Properties replace Flutter ThemeData
  - Vite replaces Flutter build toolchain
  - Android WebView shell replaces Flutter Activity

### Added
- Gyo Framework integration (WebView shell + Bridge interface)
- OpenAI-compatible API client with SSE streaming
- React UI: ChatScreen, MessageBubble, InputBar, SessionDrawer, SystemAnnotation
- Agent tools (pure TS): calculator, notepad, timer
- Native tools deferred (Gyo Bridge needed): screen_action, screen_reader, app_launcher, etc.

### Removed
- Flutter/Dart codebase (lib/, test/, integration_test/)
- Riverpod providers and Freezed models
- Drift database layer
- llama_cpp_dart on-device inference
- Flutter build system

## [0.3.0] - Phone Control

### Added
- AccessibilityService integration
  - Screen text reading
  - Element search (by text/description)
  - Click, long click, type, scroll, gesture dispatch (tap, swipe)
  - Global actions (back, home, recents)
- Agent tools: `screen_reader`, `screen_find`, `screen_action`
- Agent tool: `app_launcher` (open apps, URLs, system settings)
- NotificationListener service
- Agent tool: `notification_reader`
- OverlayService (floating AI button)
- Permission management UI (Dashboard)

## [0.2.0] - Native UI

### Changed
- Migrated from Flutter to native Android (Kotlin + Jetpack Compose)

### Added
- Jetpack Compose setup with Material3 dark theme
- Chat screen with streaming message bubbles
- Agent mode with step visualization (thought/action/observation/answer)
- Model picker bottom sheet
- Status indicator
- Bottom navigation (Chat / Dashboard / Settings)
- Dual mode: Chat (direct LLM) and Agent (tool-using)

## [0.1.0] - Core Runtime

### Added
- llama.cpp build integration with CMake
- JNI Bridge (Kotlin ↔ C++)
- Streaming token generation
- Foreground Service for LLM inference
- Model management (load/unload GGUF models)
