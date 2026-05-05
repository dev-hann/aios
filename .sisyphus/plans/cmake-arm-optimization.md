# CMake ARM SIMD 최적화 + Git Push

## TL;DR

> **Quick Summary**: CMakeLists.txt에 ARM SIMD 컴파일 플래그를 추가하여 실기기 LLM 추론 속도를 향상시키고, 이전 작업 6커밋을 push.
> 
> **Deliverables**:
> - CMakeLists.txt에 `GGML_CPU_ARM_ARCH=armv8.2-a+dotprod+fp16` 추가
> - arm64-v8a 빌드에만 ARM 플래그 적용 (x86_64 디버그 빌드 보호)
> - 빌드/테스트 검증
> - git push (6커밋 + 신규 1커밋)
> 
> **Estimated Effort**: Quick
> **Parallel Execution**: NO - 순차 (파일 1개 수정 → 빌드 → push)
> **Critical Path**: T1 → T2 → T3

---

## Context

### Original Request
웹 검색으로 발견한 CMake ARM 최적화 기회. 현재 CMakeLists.txt에 SIMD 컴파일 플래그가 전혀 없어, 실기기에서도 기본 ARM 명령어만 사용 중.

### Interview Summary
**Key Discussions**:
- Godzilla675/llama.cpp-android 프로젝트: armv8.6-a+i8mm+dotprod+fp16로 Qwen3-0.6B에서 17-19 t/s 달성
- 우리 프로젝트는 API 26+ (Android 8.0+) 타겟, arm64-v8a only (release)
- Push는 CMake 작업 후 같이 진행

### Research Findings
- **CMakeLists.txt (42줄)**: SIMD 플래그 전무. `GGML_LLAMAFILE=ON`만 설정됨
- **build.gradle.kts**: release=arm64-v8a, debug=arm64-v8a+x86_64
- **native-lib.cpp**: threads=2~4 (sysconf 기반), SIMD 코드 없음
- **llama.cpp upstream**: `GGML_CPU_ARM_ARCH` 캐시 변수로 ARM 아키텍처 플래그 제어
- **NDK 27.2 (Clang 17.x)**: armv8.6-a까지 완전 지원

### Metis Review
**Identified Gaps** (addressed):
- ARM 플래그를 ABI 조건 없이 적용하면 x86_64 빌드 실패 → `if(ANDROID_ABI STREQUAL "arm64-v8a")` 가드 필수
- `armv8.6-a+i8mm`는 구형 기기에서 SIGILL 위험 → `armv8.2-a+dotprod+fp16`으로 안전하게
- `-O3`, LTO는 별도 PR로 분리 → 이번 PR은 CMake ARM 플래그만
- `GGML_CPU_ARM_ARCH`는 `add_subdirectory` 이전에 설정해야 함 (CMake 캐시 변수 순서)
- fp16 산술 연산 지원: Cortex-A75+ 필수 (Android 8+ arm64-v8a 기기는 모두 충족)
- 예상 성능 향상: 토큰 생성 20-50%, 프롬프트 처리 50-100% (2-5x 아님)
- KleidiAI는 외부 의존성 필요 → scope 밖

---

## Work Objectives

### Core Objective
CMakeLists.txt에 ARM SIMD 컴파일 플래그를 추가하여 실기기에서 LLM 추론 속도 향상.

### Concrete Deliverables
- `android/app/src/main/cpp/CMakeLists.txt` 수정 (약 5줄 추가)
- 빌드 성공 확인 (debug + release)
- 테스트 140개 통과 확인
- git push (기존 6커밋 + 신규 1커밋)

### Definition of Done
- [ ] `./gradlew assembleDebug` 성공 (arm64-v8a + x86_64)
- [ ] `./gradlew assembleRelease` 성공 (arm64-v8a)
- [ ] `./gradlew test` 140 테스트 통과
- [ ] 빌드 로그에 `-march=armv8.2-a+dotprod+fp16` 확인
- [ ] git push 완료

### Must Have
- `GGML_CPU_ARM_ARCH=armv8.2-a+dotprod+fp16` 설정
- ABI 조건부 적용 (`if(ANDROID_ABI STREQUAL "arm64-v8a")`)
- `add_subdirectory` 이전에 캐시 변수 설정
- x86_64 디버그 빌드 정상 동작
- 모든 기존 테스트 통과

### Must NOT Have (Guardrails)
- native-lib.cpp 수정 금지
- build.gradle.kts 수정 금지
- llama.cpp 서브모듈 파일 수정 금지
- `-O3`, LTO 추가 금지 (별도 PR)
- `GGML_CPU_KLEIDIAI` 활성화 금지 (외부 의존성)
- `GGML_CPU_ALL_VARIANTS` 활성화 금지
- `armv8.6-a+i8mm` 사용 금지 (구형 기기 SIGILL 위험)
- `-ffast-math` 또는 `-fno-math-errno` 추가 금지 (수치 정확도 문제)

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** - ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES
- **Automated tests**: Tests-after (기존 테스트만 검증, 신규 테스트 불필요)
- **Framework**: Android Gradle (./gradlew test)

### QA Policy
빌드 성공이 핵심 검증. ARM 플래그는 컴파일 타임 설정이므로 런타임 QA보다 빌드 로그 확인이 중요.

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Sequential - single file change):
└── Task 1: CMakeLists.txt ARM 최적화 플래그 추가 [quick]

Wave 2 (Build verification):
└── Task 2: 빌드 + 테스트 검증 [quick]

Wave 3 (Push):
└── Task 3: Git push [quick]

Critical Path: T1 → T2 → T3 (완전 순차)
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|-----------|--------|
| T1 | - | T2, T3 |
| T2 | T1 | T3 |
| T3 | T2 | - |

### Agent Dispatch Summary

- **Wave 1**: 1 task — T1 → `quick`
- **Wave 2**: 1 task — T2 → `quick`
- **Wave 3**: 1 task — T3 → `quick`

---

## TODOs

- [ ] 1. CMakeLists.txt ARM SIMD 최적화 플래그 추가

  **What to do**:
  - `android/app/src/main/cpp/CMakeLists.txt`에 `GGML_CPU_ARM_ARCH` 캐시 변수 추가
  - `add_subdirectory(${LLAMA_DIR} llama_cpp_build)` **이전**에 설정 (CMake 캐시 변수 순서 중요)
  - ABI 조건부: `if(ANDROID_ABI STREQUAL "arm64-v8a")` 가드 필수
  - 값: `armv8.2-a+dotprod+fp16`
  - `CACHE STRING "" FORCE` 사용 (llama.cpp 기본값 "" 덮어쓰기)

  **수정 위치** (CMakeLists.txt 42줄):
  ```cmake
  # 기존 GGML_LLAMAFILE ON 설정 이후, add_subdirectory 이전에 추가:
  if(ANDROID_ABI STREQUAL "arm64-v8a")
      set(GGML_CPU_ARM_ARCH "armv8.2-a+dotprod+fp16" CACHE STRING "" FORCE)
  endif()

  add_subdirectory(${LLAMA_DIR} llama_cpp_build)
  ```

  **Must NOT do**:
  - `-O3`, LTO, `-ffast-math` 추가 금지
  - `GGML_CPU_KLEIDIAI` 활성화 금지
  - `armv8.6-a+i8mm` 사용 금지
  - native-lib.cpp, build.gradle.kts 수정 금지

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 단일 파일 5줄 추가, 명확한 스펙
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (단독)
  - **Blocks**: T2, T3
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `android/app/src/main/cpp/CMakeLists.txt` — 현재 전체 파일 (42줄). 수정 대상. `GGML_LLAMAFILE ON` 이후, `add_subdirectory` 이전에 GGML_CPU_ARM_ARCH 추가

  **External References**:
  - llama.cpp upstream `ggml/CMakeLists.txt:184`: `set(GGML_CPU_ARM_ARCH "" CACHE STRING "ggml: CPU architecture for ARM")` — 변수 정의 위치
  - llama.cpp upstream `ggml-cpu/CMakeLists.txt:177-178`: `if (GGML_CPU_ARM_ARCH) list(APPEND ARCH_FLAGS -march=${GGML_CPU_ARM_ARCH})` — 변수 사용 방식
  - Godzilla675/llama.cpp-android: `GGML_CPU_ARM_ARCH=armv8.6-a+i8mm+dotprod+fp16` — 참고용 (우리는 armv8.2-a 사용)

  **WHY Each Reference Matters**:
  - CMakeLists.txt: 수정할 유일한 파일, 삽입 위치 확인 필수
  - ggml/CMakeLists.txt: GGML_CPU_ARM_ARCH가 빈 문자열 기본값이므로 CACHE FORCE로 덮어써야 함
  - ggml-cpu/CMakeLists.txt: 값이 `-march=` 플래그로 직접 전달됨을 확인

  **Acceptance Criteria**:
  - [ ] CMakeLists.txt에 `if(ANDROID_ABI STREQUAL "arm64-v8a")` 조건 블록 존재
  - [ ] `GGML_CPU_ARM_ARCH`가 `"armv8.2-a+dotprod+fp16"`으로 설정됨
  - [ ] `CACHE STRING "" FORCE` 사용됨
  - [ ] `add_subdirectory` 이전에 위치함

  **QA Scenarios:**

  ```
  Scenario: ARM 플래그가 올바르게 추가됨
    Tool: Bash (grep)
    Preconditions: CMakeLists.txt 수정 완료
    Steps:
      1. grep -n "GGML_CPU_ARM_ARCH" android/app/src/main/cpp/CMakeLists.txt
      2. grep -n "armv8.2-a+dotprod+fp16" android/app/src/main/cpp/CMakeLists.txt
      3. grep -n "ANDROID_ABI" android/app/src/main/cpp/CMakeLists.txt
    Expected Result: 세 패턴 모두 동일 라인 범위에서 발견, add_subdirectory 이전에 위치
    Failure Indicators: 패턴 미발견 또는 add_subdirectory 이후에 위치
    Evidence: .sisyphus/evidence/task-1-cmake-arm-flags.txt

  Scenario: ABI 가드가 올바름
    Tool: Bash (grep)
    Preconditions: CMakeLists.txt 수정 완료
    Steps:
      1. grep -A1 "ANDROID_ABI" android/app/src/main/cpp/CMakeLists.txt
      2. 확인: if(ANDROID_ABI STREQUAL "arm64-v8a") 내부에만 GGML_CPU_ARM_ARCH 존재
    Expected Result: GGML_CPU_ARM_ARCH가 arm64-v8a 조건 블록 내부에만 있음
    Failure Indicators: 조건 없이 전역으로 설정됨 (x86_64 빌드 실패 위험)
    Evidence: .sisyphus/evidence/task-1-abi-guard.txt
  ```

  **Commit**: YES
  - Message: `perf(native): add ARM SIMD optimization flags for llama.cpp build`
  - Files: `android/app/src/main/cpp/CMakeLists.txt`
  - Pre-commit: `cd android && ./gradlew assembleDebug`

- [ ] 2. 빌드 + 테스트 검증

  **What to do**:
  - `./gradlew assembleDebug` 실행 → arm64-v8a + x86_64 빌드 확인
  - `./gradlew assembleRelease` 실행 → arm64-v8a 릴리즈 빌드 확인
  - `./gradlew test` 실행 → 140 테스트 통과 확인
  - 빌드 로그에서 ARM 플래그 적용 여부 확인

  **Must NOT do**:
  - 테스트 실패 시 테스트 삭제 금지
  - 빌드 실패 시 CMakeLists.txt 무시하고 push 금지

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 빌드/테스트 실행, 로그 확인
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (T1 완료 후)
  - **Blocks**: T3
  - **Blocked By**: T1

  **References**:

  **Pattern References**:
  - `android/app/src/main/cpp/CMakeLists.txt` — 수정된 파일. 빌드 로그에서 `-march=armv8.2-a+dotprod+fp16` 확인

  **API/Type References**:
  - `android/app/build.gradle.kts:24-32` — defaultConfig ABI: arm64-v8a
  - `android/app/build.gradle.kts:71-76` — debug ABI: arm64-v8a + x86_64

  **WHY Each Reference Matters**:
  - debug 빌드는 x86_64 포함 → ARM 플래그가 x86_64에 적용되지 않아야 함
  - release 빌드는 arm64-v8a only → ARM 플래그가 정상 적용되어야 함

  **Acceptance Criteria**:
  - [ ] `./gradlew assembleDebug` → BUILD SUCCESSFUL
  - [ ] `./gradlew assembleRelease` → BUILD SUCCESSFUL
  - [ ] `./gradlew test` → 140 tests, 0 failures
  - [ ] 빌드 로그에 arm64-v8a용 `-march=armv8.2-a+dotprod+fp16` 확인
  - [ ] x86_64 빌드에 ARM 플래그 미포함 확인

  **QA Scenarios:**

  ```
  Scenario: 전체 빌드 성공
    Tool: Bash
    Preconditions: T1 CMakeLists.txt 수정 완료
    Steps:
      1. cd android && ./gradlew assembleDebug 2>&1 | tee /tmp/build-debug.log
      2. cd android && ./gradlew assembleRelease 2>&1 | tee /tmp/build-release.log
      3. grep "BUILD SUCCESSFUL" /tmp/build-debug.log /tmp/build-release.log
    Expected Result: 두 빌드 모두 BUILD SUCCESSFUL
    Failure Indicators: BUILD FAILED, compilation error
    Evidence: .sisyphus/evidence/task-2-build-result.txt

  Scenario: ARM 플래그 적용 확인
    Tool: Bash (grep)
    Preconditions: 빌드 성공
    Steps:
      1. grep -i "armv8.2" /tmp/build-release.log || grep -i "march" /tmp/build-release.log
      2. grep -c "dotprod" /tmp/build-release.log || echo "Checking build output..."
    Expected Result: 빌드 로그에 ARM 아키텍처 관련 메시지 존재
    Failure Indicators: ARM 관련 메시지가 전혀 없음 (플래그 미적용)
    Evidence: .sisyphus/evidence/task-2-arm-flags-log.txt

  Scenario: 테스트 통과
    Tool: Bash
    Preconditions: 빌드 성공
    Steps:
      1. cd android && ./gradlew test 2>&1 | tail -20
    Expected Result: 140 tests, 0 failures
    Failure Indicators: test FAILED 또는 140 != passed count
    Evidence: .sisyphus/evidence/task-2-test-result.txt
  ```

  **Commit**: NO (T1과 함께 또는 T3에서 push)

- [ ] 3. Git Push

  **What to do**:
  - `git push origin master` 실행
  - pre-push 훅이 자동으로: assembleRelease + 버전 bump + GitHub release 생성
  - push 성공 및 GitHub release 생성 확인

  **Must NOT do**:
  - `--force` push 금지
  - pre-push 훅 우회 (`--no-verify`) 금지

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 단순 git push + 확인
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (T2 완료 후)
  - **Blocks**: F1, F2
  - **Blocked By**: T2

  **References**:

  **Pattern References**:
  - `.husky/pre-push` — pre-push 훅: 자동 버전 bump + assembleRelease + gh release create

  **WHY Each Reference Matters**:
  - pre-push 훅이 push 시 자동 실행되므로 별도 릴리즈 수동 작업 불필요

  **Acceptance Criteria**:
  - [ ] `git push origin master` 성공
  - [ ] GitHub release 생성 확인 (`gh release list --limit 1`)

  **QA Scenarios:**

  ```
  Scenario: Push 성공
    Tool: Bash
    Preconditions: T2 빌드+테스트 검증 완료
    Steps:
      1. git push origin master 2>&1 | tee /tmp/push-result.log
      2. gh release list --limit 1
    Expected Result: push 성공, 새 GitHub release 생성
    Failure Indicators: push rejected, pre-push hook failed
    Evidence: .sisyphus/evidence/task-3-push-result.txt
  ```

  **Commit**: N/A (push 자체가 커밋 전송)

---

## Final Verification Wave (after ALL tasks)

> Push 후 pre-push 훅이 자동으로 assembleRelease + 버전 bump + GitHub release 생성.
> 푸시 성공 여부로 최종 검증.

- [ ] F1. **빌드 성공 확인** — `quick`
  `./gradlew assembleDebug`와 `./gradlew assembleRelease` 빌드 로그에서 ARM 관련 메시지 확인.
  Output: `Debug [PASS/FAIL] | Release [PASS/FAIL] | ARM flags in log [YES/NO]`

- [ ] F2. **푸시 + 릴리즈 확인** — `quick`
  `git push origin master` 실행. pre-push 훅 성공 후 GitHub release 생성 확인.
  Output: `Push [PASS/FAIL] | Release created [YES/NO] | Version [x.y.z]`

---

## Commit Strategy

- **T1**: `perf(native): add ARM SIMD optimization flags for llama.cpp build` — CMakeLists.txt
  Pre-commit: `cd android && ./gradlew assembleDebug`

---

## Success Criteria

### Verification Commands
```bash
cd android && ./gradlew assembleDebug    # Expected: BUILD SUCCESSFUL
cd android && ./gradlew assembleRelease  # Expected: BUILD SUCCESSFUL
cd android && ./gradlew test             # Expected: 140 tests passed
git log --oneline -1                     # Expected: perf(native): add ARM SIMD...
git push origin master                   # Expected: pre-push hook triggers release
```

### Expected Performance Impact (Real Device)
- Token generation: 20-50% faster
- Prompt processing: 50-100% faster
- Binary size: ~100KB increase (negligible)

### Final Checklist
- [ ] CMakeLists.txt에 GGML_CPU_ARM_ARCH 설정 추가
- [ ] ABI 조건부 (arm64-v8a만) 적용
- [ ] add_subdirectory 이전에 설정
- [ ] x86_64 빌드 정상 (ARM 플래그 미적용)
- [ ] 140 테스트 통과
- [ ] git push + release 생성 완료
