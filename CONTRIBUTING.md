# Contributing to AIOS

Thank you for your interest in contributing to AIOS! This document provides guidelines for contributing to the project.

## Development Setup

### Prerequisites

- **Android Studio** (latest stable version)
- **JDK 17+**
- **Android SDK**: API 35 (Android 15)
- **Android NDK**: 27.2+
- **CMake**: 3.22.1+
- **Git** with submodule support

### Clone & Build

```bash
git clone https://github.com/hann/aios.git
cd aios
git submodule update --init --recursive
```

Open the `android/` directory in Android Studio and sync Gradle.

### Build Commands

```bash
# Debug build (from android/ directory)
./gradlew assembleDebug

# Release build (signed)
./gradlew assembleRelease

# Install on connected device
./gradlew installDebug

# Clean build
./gradlew clean

# Run unit tests
./gradlew test

# Run instrumented tests (requires device/emulator)
./gradlew connectedAndroidTest

# ktlint check
./gradlew ktlintCheck

# ktlint auto-fix
./gradlew ktlintFormat
```

### Native Build

C++ 레이어는 CMake로 Android 빌드 시 자동 빌드됨. Standalone 테스트:

```bash
cd native/tests
mkdir build && cd build
cmake .. -DLLAMA_CPP_DIR=../../native/llama.cpp
make
./test_inference
```

### Release & Deployment

```bash
# Git hooks 설정 (clone 후 1회)
git config core.hooksPath .githooks

# 수동 릴리즈 (버전 업 + 빌드 + 태그 + 푸시 + 릴리즈)
./release.sh 1.1.0
```

- `versionName`: semver (`MAJOR.MINOR.PATCH`)
- `versionCode`: `MAJOR * 10000 + MINOR * 100 + PATCH`
- pre-push hook: versionName 변경 감지 시 자동 빌드 + GitHub Release 생성

#### 배포 전 필수 실기 테스트 (MANDATORY)

**에뮬레이터 또는 실기기에서 instrumented 테스트를 실행하여 자동 검증한다:**

```bash
# 에뮬레이터 실행 (AVD 없으면 생성)
$ANDROID_HOME/emulator/emulator -avd aios_test -no-snapshot-load &

# Instrumented 테스트 실행 (단위 + UI + 네이티브 + 모델 로드 진행률)
cd android && ./gradlew connectedAndroidTest

# 수동 검증이 필요한 경우에만 아래 실행
adb install -r android/app/build/outputs/apk/release/app-release.apk
adb logcat -s "AIOS-*" "AndroidRuntime" "ActivityManager"
adb shell am start -n com.agent.aios/.MainActivity
```

**`connectedAndroidTest`가 통과하면 아래 항목이 자동 검증된다:**

| 테스트 클래스 | 검증 항목 |
|---|---|
| `LlamaBridgeInstrumentedTest` | 네이티브 로드, 진행률/스테이지 초기값 |
| `NativeInferenceTest` | 모델 로드, 추론, 진행률 폴링, 릴리즈 후 리셋 |
| `ChatScreenTest` | Compose UI 렌더링, 로딩 진행률 표시, 화면 전환 |
| `AgentToolsInstrumentedTest` | 툴 동작 |

**릴리즈 업로드는 `connectedAndroidTest` 통과 후에만 수행한다.**

## Development Workflow

### 1. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

### 2. Make Changes

- Follow existing code style and conventions (see below)
- Keep changes focused and atomic
- Test on a physical device when possible

### 3. Commit

Write clear, concise commit messages:

```
type: short description

Optional longer description
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`

### 4. Submit a Pull Request

- Fill out the PR template completely
- Reference any related issues
- Ensure the build passes
- Keep PRs focused on a single concern

## Code Style

### Kotlin

- Follow [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html)
- Use `StateFlow`/`SharedFlow` for reactive state (no LiveData)
- Use coroutines for async work (no RxJava)
- 4-space indentation
- Maximum line length: 120 characters

### C/C++

- Follow the [llama.cpp coding style](https://github.com/ggerganov/llama.cpp/blob/master/CONTRIBUTING.md)
- Use C-style for llama.cpp interop, modern C++ for internal logic
- 4-space indentation

### General

- No unnecessary comments — code should be self-documenting
- Use meaningful variable and function names
- Keep functions small and focused

## Adding Agent Tools

See the "Tool Development" section in [AGENTS.md](AGENTS.md) for detailed instructions on adding new agent tools.

## Project Structure

See [docs/architecture.md](docs/architecture.md) for a detailed overview of the project architecture and module responsibilities.

## Reporting Issues

- Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md) for bugs
- Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md) for new features
- Include device info, Android version, and model details when reporting bugs

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
