# AIOS - Android Local LLM Agent Runtime

## On-device AI Runtime Platform

Flutter UI + Android Service + llama.cpp Runtime = Personal AI OS Core

---

## System Architecture

```
[Flutter App (UI Layer)]
        | MethodChannel
[Android Service Layer (Kotlin)]
        | JNI Bridge
[Native C++ Runtime (llama.cpp)]
        |
[GGUF Model Files (Local Storage)]
```

---

## Phase 1: llama.cpp Android Build + Single Inference

- [x] 1-1. Dev environment setup (NDK, CMake)
- [ ] 1-2. llama.cpp git submodule + CMakeLists
- [ ] 1-3. Native C++ entry point (inference test)
- [ ] 1-4. Android Gradle build config (NDK + CMake)
- [ ] 1-5. Kotlin app entry point (native call)
- [ ] 1-6. Performance benchmark checkpoint

## Phase 2: JNI Bridge (Kotlin <-> C++)

- [ ] 2-1. JNI interface design
- [ ] 2-2. C++ JNI implementation
- [ ] 2-3. Kotlin wrapper class
- [ ] 2-4. Streaming callback implementation
- [ ] 2-5. JNI unit tests

## Phase 3: Flutter MethodChannel

- [ ] 3-1. Flutter project integration
- [ ] 3-2. MethodChannel interface
- [ ] 3-3. EventChannel streaming
- [ ] 3-4. Chat UI (MVP)
- [ ] 3-5. Model management UI

## Phase 4: Foreground Service

- [ ] 4-1. Foreground Service implementation
- [ ] 4-2. Service-Flutter communication (AIDL)
- [ ] 4-3. Service state management
- [ ] 4-4. Lifecycle management
- [ ] 4-5. Background triggers
- [ ] 4-6. Permissions and UX

## Phase 5: Agent Structure

- [ ] 5-1. Agent prompt engineering (ReAct)
- [ ] 5-2. Tool interface design
- [ ] 5-3. Basic tools implementation
- [ ] 5-4. Tool router
- [ ] 5-5. Agent execution engine
- [ ] 5-6. Agent UI
- [ ] 5-7. Context window management
- [ ] 5-8. Security and permissions

---

## Tech Stack

- Flutter (UI)
- Kotlin (Android Service)
- C++ (NDK / llama.cpp)
- JNI (Bridge)
- GGUF model format

## Key Principles

- LLM is Runtime, not UI
- Model loaded once, reused
- Queue-based sequential inference
- Interface separation (UI <-> Agent <-> Runtime)
