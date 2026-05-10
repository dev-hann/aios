---
name: aios-dev
description: AIOS autonomous development - main thread runs sub-tasks, each sub-task reads roadmap, analyzes, implements, tests, commits, and deploys
metadata:
  project: aios
  stack: flutter/dart
  target: natural-language phone control
---

## AIOS 자율 개발 스킬

### 필수 참조 문서

서브태스크는 작업 시작 전 아래 문서를 숙지해야 한다:

| 문서 | 용도 |
|------|------|
| `AGENTS.md` | 코딩 규약(§2-3), 활성 Tool(§4), 테스트 의무(§0), 기기 명령어(§0), 문서 업데이트(§5) |
| `CONTRIBUTING.md` | 빌드/개발 명령어, PR 규칙, 커밋 타입, 릴리즈 프로세스 |
| `TESTING.md` | 테스트 원칙, 스코프, TDD 워크플로우 |
| `TESTING_DEVICE.md` | 기기 스모크/기능/심화 테스트, adb 패턴 |
| `docs/architecture.md` | 시스템 아키텍처, 모듈 구조, 데이터 흐름 |

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
0. 기존 테스트 상태 확인:
   - ./scripts/test.sh 실행 → 실패 시 신규 기능보다 기존 테스트 수정 우선
   - all green 확인 후 다음 단계 진행
1. git log --oneline -20 → 완료된 feat(FXX) 커밋 패턴 확인
2. ROADMAP.md 읽기 → 전체 기능 목록 파악
3. 다음 미완료 기능 식별 (가장 낮은 FXX 번호)
   - 없으면 "ROADMAP 전체 완료" 반환 후 종료
4. AGENTS.md 읽기 → 코딩 규약 숙지
5. 관련 기존 코드 분석:
   - 같은 타입(BasicTool/ExtendedTool)의 활성 Tool 코드 읽기
   - 기존 테스트 파일 패턴 파악
   - agent_provider.dart 등록 방식 확인
   - RiskClassifier 위험도 분류 확인
6. 작업 리스트 작성 (구체적인 파일/함수 단위)
7. 각 작업별 TDD:
   a. 테스트 코드 작성 (RED)
   b. 기능 구현 (GREEN)
   c. ./scripts/test.sh 실행 → 실패 시 수정
   d. 리팩토링 (REFACTOR)
8. ./scripts/test.sh 전체 실행 → 반드시 0 실패 확인
9. 커밋 전 필수 체크 (CONTRIBUTING.md 참고):
   - flutter analyze → 0 warnings
   - dart format . --set-exat-if-changed → no diff
   - dart run build_runner build → 코드 생성 성공
10. 기기 연결 시 (AGENTS.md §0 기기 명령어 참고):
    a. flutter build apk --debug
    b. adb 설치 → 실행
    c. 스크린샷 → read로 화면 확인
    d. logcat에서 [AIOS-] 로그 확인
    e. TESTING_DEVICE.md 스모크 테스트 수행
    f. 문제 발견 시 7번부터 수정 반복
11. git add → commit:
    - 메시지: "type: 기능명 - 변경 내용 요약" (CONTRIBUTING.md 커밋 타입 참고)
    - 문서 업데이트 포함 (AGENTS.md §5 체크리스트 참고)
12. git push
13. 마일스톤 완료 시 (CONTRIBUTING.md Release Process 참고):
    - pubspec.yaml 버전업
    - git commit -m "release: MX 마일스톤명"
    - git tag v{version}
    - git push && git push --tags
14. 결과 요약 반환:
    "FXX 완료: 작업 N개, 테스트 M개 추가/수정, 전체 {count} 테스트 통과"
```

### 병렬 실행 규칙

- 독립적인 작업은 반드시 동시에 실행 (순차 실행 금지)
- 예: 파일 읽기 여러 개는 병렬, 코드 수정 + 테스트는 순차
