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
# Debug build
./gradlew assembleDebug

# Install on connected device
./gradlew installDebug

# Run unit tests
./gradlew test

# Clean build
./gradlew clean
```

For detailed build instructions, see [docs/build-guide.md](docs/build-guide.md).

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
