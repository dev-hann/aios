---
name: aios-dev
description: AIOS autonomous development - main thread runs sub-tasks, each sub-task reads roadmap, analyzes, implements, tests, commits, and deploys
metadata:
  project: aios
  stack: flutter/dart
  target: natural-language phone control
---

## AIOS 자율 개발 스킬

### MAIN THREAD 프로시저

메인 스레드는 서브태스크만 실행하고 관리한다. 코드를 직접 수정하지 않는다.

```
1. 서브태스크 실행 (Task 도구, subagent_type: "general")
   - 프롬프트에 SKILL.md의 "SUB-TASK 프로시저" 전체 내용 전달
   - 서브태스크가 알아서 ROADMAP 읽고 다음 기능 찾아서 구현
2. 서브태스크 종료 대기
3. 결과 로깅: "[AIOS-Dev] 서브태스크 N 완료: {결과}"
4. 서브태스크 결과가 "ROADMAP 전체 완료"면 사용자에게 알림
5. 아니면 1번부터 반복 (다음 서브태스크 실행)
```

### SUB-TASK 프로시저

서브태스크는 ROADMAP 분석부터 기능 구현, 커밋까지 모두 수행한다.

```
0. git log --oneline -20 → 완료된 feat(FXX) 커밋 패턴 확인
1. ROADMAP.md 읽기 → 전체 기능 목록 파악
2. 다음 미완료 기능 식별 (가장 낮은 FXX 번호)
   - 없으면 "ROADMAP 전체 완료" 반환 후 종료
3. AGENTS.md 읽기 → 코딩 규약 숙지
4. 관련 기존 코드 분석:
   - 같은 타입(BasicTool/ExtendedTool)의 활성 Tool 코드 읽기
   - 기존 테스트 파일 패턴 파악
   - agent_provider.dart 등록 방식 확인
   - RiskClassifier 위험도 분류 확인
5. 작업 리스트 작성 (구체적인 파일/함수 단위)
6. 각 작업별 TDD:
   a. 테스트 코드 작성 (RED)
   b. 기능 구현 (GREEN)
   c. flutter test 실행 → 실패 시 수정
   d. 리팩토링 (REFACTOR)
7. flutter test 전체 실행 → 반드시 0 실패 확인
8. 기기 연결 시:
   a. flutter build apk --debug
   b. adb 설치 → 실행
   c. 스크린샷 → read로 화면 확인
   d. logcat에서 [AIOS-] 로그 확인
   e. 문제 발견 시 6번부터 수정 반복
9. git add → commit:
   - 메시지: "feat(FXX): 기능명 - 변경 내용 요약"
   - 문서 업데이트 포함 (AGENTS.md §4, architecture.md 등)
10. git push
11. 마일스톤 완료 시:
    - pubspec.yaml 버전업
    - git commit -m "release: MX 마일스톤명"
    - git tag v{version}
    - git push && git push --tags
12. 결과 요약 반환:
    "FXX 완료: 작업 N개, 테스트 M개 추가/수정, 전체 {count} 테스트 통과"
```

### 기기 명령어 (서브태스크 내에서 사용)

| 동작 | 명령어 |
|------|--------|
| 연결 확인 | `adb devices` |
| 스크린샷 | `adb shell screencap -p /sdcard/screen.png && adb pull /sdcard/screen.png /tmp/screen.png` |
| 스크린샷 읽기 | `read` 도구로 `/tmp/screen.png` 열기 |
| 로그 수집 | `adb logcat -d \| grep "\[AIOS-"` |
| 로그 초기화 | `adb logcat -c` |
| 텍스트 입력 | `adb shell input text "message"` |
| 탭 | `adb shell input tap X Y` |
| 엔터 | `adb shell input keyevent 66` |
| APK 설치 | `adb uninstall com.agent.aios && adb install build/app/outputs/flutter-apk/app-debug.apk` |
| 앱 실행 | `adb shell am start -n com.agent.aios/.MainActivity` |

### 기기 연결 규칙

- 기기가 연결되지 않으면 사용자에게 알리고 기기 관련 스텝을 건너뛴다
- 코드 수정, 테스트, 빌드는 기기 없이도 진행한다
- 기기 연결 복구 후 중단된 스텝부터 재개한다

### 병렬 실행 규칙

- 독립적인 작업은 반드시 동시에 실행 (순차 실행 금지)
- 예: 파일 읽기 여러 개는 병렬, 코드 수정 + 테스트는 순차

### 코딩 규약 요약 (AGENTS.md)

#### 필수 프레임워크
- 상태관리: **Riverpod** (GetX, Bloc 금지)
- 라우팅: **GoRouter** (Navigator 1.0 금지)
- 불변 모델: **Freezed** (`@freezed` + `const factory`)
- 패키지 구조: `domain/`, `data/`, `presentation/`, `core/`

#### 에러 처리
- Tool 에러: 반드시 `"Error: ..."` 문자열 반환 (예외 throw 금지)
- Repository 에러: try-catch + `print()` + 상태 업데이트
- 빈 catch 금지: `catch (_) {}` 최소한 `print()` 출력 필요
- action 비교: 항상 `.toLowerCase()` 사용

#### 로깅
```dart
print('[AIOS-{Component}] message');
print('[AIOS-{Component}] WARN: message');
print('[AIOS-{Component}] ERROR: message - $e');
```
- `developer.log` 사용 금지 (logcat에 출력 안 됨)

#### 네이밍
- Class: PascalCase, Function/Variable: camelCase
- Tool name/File name: snake_case
- Test file: `{name}_test.dart`
- Test function: `{method}_{scenario}_expectedResult`

#### 파일 배치
- Repository 인터페이스: `domain/repositories/`
- Repository 구현: `data/repositories/`
- Agent 전략/로직: `domain/agent/`
- Tool: `agent/tools/`
- Screen: `presentation/screens/`
- Widget: `presentation/widgets/`
- Provider: `presentation/providers/`

#### 절대 금지
1. Tool에서 예외 throw → `"Error: ..."` 문자열 반환
2. 빈 catch 블록 → 최소한 `print()` 출력
3. 테스트 삭제해서 통과시키기 → 근본 원인 해결
4. Riverpod 외 상태관리 → GetX, Bloc 등 금지
5. 타입체크 없는 `as` 캐스트 → `is` 체크 후 캐스트
6. `// ignore:` 경고 숨기기 → 근본 원인 해결
7. `pubspec.yaml` 없는 의존성 → 의존성 추가 전 확인
8. `developer.log` 사용 → `print()` 사용

### 커밋 메시지 규칙

```
feat(FXX): 기능명 - 변경 내용 요약
```

예시:
- `feat(F01): app_launcher - open_app/open_url 프롬프트 구분 강화`
- `feat(F02): screen_action - 탭, 스와이프, 텍스트 입력 구현`

### 마일스톤 배포 규칙

마일스톤의 모든 기능이 완료되면:
1. `pubspec.yaml` version 업데이트
2. `git commit -m "release: MX 마일스톤명"`
3. `git tag v{version}`
4. `git push && git push --tags`

### 커밋 전 문서 업데이트 체크 (MANDATORY)

코드 변경 후 커밋하기 전, 변경 내용이 관련 문서에 영향을 주는지 확인하고
필요시 업데이트한다:

| 변경 유형 | 업데이트할 문서 | 체크 항목 |
|-----------|----------------|-----------|
| Tool 추가/제거/수정 | AGENTS.md §4, architecture.md | 활성 Tool 목록, Tool Categories |
| 아키텍처 변경 | architecture.md | Data Flow, Layers, Design Decisions |
| 테스트 추가/삭제/수정 | TESTING.md | 테스트 수, 커버리지, 알려진 실패 |
| 새 파일 생성 | AGENTS.md §2.5 | 디렉토리 구조 테이블 |
| 새 의존성 추가 | CONTRIBUTING.md | 패키지 목록 |
| Agent 로직 변경 | AGENTS.md §4, architecture.md | Phase 구조, 프롬프트, 파서 |
| 빌드/CI/배포 변경 | CONTRIBUTING.md | 명령어, 환경 설정 |
| 코딩 규약 변경 | AGENTS.md §2, §3 | 규약, 금지사항 |

### 체크 방법

1. `git diff --stat` 으로 변경 파일 목록 확인
2. 위 테이블에서 해당하는 문서 식별
3. 문서 읽기 → 변경 내용 반영 → 저장
4. 문서 업데이트를 커밋에 포함
