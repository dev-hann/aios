---
name: aios-dev
description: AIOS autonomous development - main thread runs sub-tasks, each sub-task reads roadmap, analyzes, implements, tests, commits, and deploys
metadata:
  project: aios
  stack: react/typescript
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
2. 서브태스크 종료 대기
3. 결과 로깅: "[AIOS-Dev] 서브태스크 N 완료: {결과}"
4. 서브태스크 결과가 "전체 완료"면 사용자에게 알림
5. 아니면 1번부터 반복 (다음 서브태스크 실행)
```

### SUB-TASK 프로시저

서브태스크는 코드베이스 분석부터 개선/리팩토링, 커밋까지 모두 수행한다.

```
0. 기존 테스트 상태 확인:
   - cd lib && npm run verify 실행 → 실패 시 기존 코드 수정 우선
   - all green 확인 후 다음 단계 진행
1. AGENTS.md, CONTRIBUTING.md, TESTING.md, docs/architecture.md 읽기 → 규약 숙지
2. git log --oneline -20 → 최근 변경사항 파악
3. 코드베이스 분석 → 개선/리팩토링 후보 전체 탐색:
   a. 중복 코드 (동일한 헬퍼/로직이 여러 파일에 있는지 grep)
   b. 과도하게 긴 메서드/클래스 (100줄+)
   c. 누락된 테스트 (src/ 대 __tests__/ 비교, 미커버 모듈 식별)
   d. 에러 핸들링 (빈 catch, 잘못된 에러 반환, unsafe cast)
   e. 성능 (불필요한 리렌더, O(n) 복사, 매번 새 인스턴스 생성)
   f. 미사용 의존성, dead code, TODO/FIXME/HACK 주석
   → 발견된 항목을 우선순위(HIGH > MEDIUM > LOW)로 정렬
   → 전체 항목을 작업 리스트로 작성
   - 발견된 항목이 없으면 "전체 완료" 반환 후 종료
4. 관련 기존 코드 분석:
   - 수정 대상 파일의 주변 컨텍스트 읽기
   - 기존 테스트 파일 패턴 파악
   - 의존성 주입 방식 (Zustand store) 확인
5. 작업 리스트의 각 항목에 대해 TDD 수행:
   a. 테스트 코드 작성 (RED)
   b. 기능 구현/수정 (GREEN)
   c. npm run test 실행 → 실패 시 수정
   d. 리팩토링 (REFACTOR)
6. npm run verify 전체 실행 → 반드시 0 실패 확인
7. 커밋 전 필수 체크:
   - npm run type-check → 0 errors
   - npm run build → 성공
8. 기기 연결 시 (AGENTS.md §0 기기 명령어 참고):
   a. cd android && ./gradlew assembleDebug
   b. adb 설치 → 실행
   c. 스크린샷 → read로 화면 확인
   d. logcat에서 [AIOS-] 로그 확인
   e. TESTING_DEVICE.md 스모크 테스트 수행
   f. 문제 발견 시 5번부터 수정 반복
9. git add → commit:
   - 메시지: "refactor: 변경 내용 요약" (CONTRIBUTING.md 커밋 타입 참고)
   - 문서 업데이트 포함 (AGENTS.md §5 체크리스트 참고)
10. git push
11. 결과 요약 반환:
    "리팩토링 N개 완료: {항목 요약}, 테스트 M개 추가/수정, 전체 {count} 테스트 통과"
```

### 병렬 실행 규칙

- 독립적인 작업은 반드시 동시에 실행 (순차 실행 금지)
- 예: 파일 읽기 여러 개는 병렬, 코드 수정 + 테스트는 순차
