# AIOS Testing Policy

## 테스트별 참고 섹션

| 상황 | 참고 섹션 |
|------|-----------|
| 단위 테스트 작성 | §1 원칙, §3 스코프, §5-6 네이밍/커버리지, §9 패턴 |
| 통합 테스트 | §3 P4, §4 카테고리 |
| TDD 워크플로우 | §8 TDD, §7 회귀 테스트 |
| Tool 추가 시 | §8 Tool 체크리스트 |
| 기기 테스트 | **TESTING_DEVICE.md** 참고 |

## 1. Principles

- 모든 **public 함수**는 최소 1개 이상의 단위 테스트를 가져야 함
- **상태 변경** 함수는 상태 전이를 반드시 검증
- 버그 수정 시 원본 버그를 재현하는 **회귀 테스트** 포함 필수
- 테스트는 기능 구현 **이전에 작성** (TDD)

## 2. Current Status

- **374 단위/통합 테스트** (전체 통과)
- 테스트 프레임워크: **Vitest** + **fake-indexeddb** + **@testing-library/react**
- 20 테스트 파일, 0 실패

## 3. Test Scope

### P0: Core Types (필수)

| Module | File | Test 항목 |
|--------|------|-----------|
| ToolResult helpers | `src/types/agent.ts` | toolResultOk, toolResultErr, isToolError, toContent (all branches) |
| Provider config | `src/llm/types.ts` | createProviderConfig, baseUrl resolution (4 providers + custom + unknown) |

### P1: Agent System (필수)

| Module | File | Test 항목 |
|--------|------|-----------|
| Truncate | `src/agent/truncate.ts` | 경계값, 빈 문자열, 한국어 멀티바이트 |
| ToolJsonParser | `src/agent/tool-json-parser.ts` | tryParseToolJson (12 cases), parseIntDynamic (14 cases) |
| ToolArgInference | `src/agent/tool-arg-inference.ts` | calculator/notepad/timer 추론, 한영혼합, 32 cases |
| RiskClassifier | `src/agent/risk-classifier.ts` | 전체 tool 위험도 분류, 민감정보 감지, 38 cases |
| ConversationContext | `src/agent/conversation-context.ts` | addTurn, FIFO eviction, 응답 길이 제한, clear, 14 cases |
| ToolPreferenceTracker | `src/agent/tool-preference-tracker.ts` | 빈도 추적, topN 제한, 정렬, clear, 8 cases |
| LoopDetector | `src/agent/loop-detector.ts` | 반복 감지, override 허용, 관측 동일성, 18 cases |
| ErrorRecovery | `src/agent/error-recovery.ts` | 8가지 에러 타입, 재시도 로직, Korean 메시지, 33 cases |
| GenerationConfig | `src/agent/react-strategy.ts` | temperature/topP/maxTokens 설정, 기본값, 5 cases |

### P1.5: UI Components (필수)

| Module | File | Test 항목 |
|--------|------|-----------|
| SystemAnnotation | `src/components/SystemAnnotation.tsx` | hidden types, risk-level CSS classes, retry count, observation error detection, truncation, 16 cases |

### P2: Tools (필수)

| Module | File | Test 항목 |
|--------|------|-----------|
| CalculatorTool | `src/tools/calculator.ts` | 사칙연산, 괄호, 우선순위, sanitize, 에러, validate, 28 cases |
| NotepadTool | `src/tools/notepad.ts` | save/get/list/delete, 덮어쓰기, case-insensitive, validate, 27 cases |
| TimerTool | `src/tools/timer.ts` | set/check/cancel/list, 경계값, 만료, Date.now() mock, validate, 35 cases |

### P3: Integration (필수)

| Module | File | Test 항목 |
|--------|------|-----------|
| OpenAiClient | `src/llm/openai-client.ts` | convertTools 스키마, SSE 파싱 (mock fetch), 에러, 20 cases |
| LlmRemoteSession | `src/llm/session.ts` | chat 스트림, tool call 누적, addToolResult, 7 cases |
| ReactStrategy | `src/agent/react-strategy.ts` | text 응답, tool 호출, 취소, system prompt, error recovery wiring, 8 cases |
| ConversationDB | `src/services/conversation-db.ts` | CRUD with fake-indexeddb, 정렬, 삭제 cascade, 16 cases |

## 4. Test Categories

```
lib/src/__tests__/
  unit/                   → 단위 테스트 (순수 함수 + 클래스, mock 불필요)
    types/                → agent.ts, llm-types.ts
    agent/                → truncate, json-parser, arg-inference, risk-classifier,
                              conversation-context, tool-preference-tracker,
                              loop-detector, error-recovery, generation-config
    tools/                → calculator, notepad, timer
    components/           → SystemAnnotation (jsdom environment)
  integration/            → 통합 테스트 (mock fetch, fake-indexeddb)
    openai-client.test.ts
    session.test.ts
    react-strategy.test.ts
    conversation-db.test.ts
```

## 5. Naming Conventions

```
File:     {name}.test.ts
Function: describe → it pattern

Examples:
  describe('toolResultOk', () => { it('returns ToolResult with output only', ...) })
  describe('RiskClassifier', () => { it('classifies open_app as high', ...) })
```

## 6. Coverage Requirements

### 함수별
- **Happy path**: 1 test (정상 입력 → 예상 출력)
- **Edge case**: 1 test 이상 (null, empty, 경계값)
- **Error path**: 알려진 각 실패 모드당 1 test

### 동시성 시나리오별
- **실행 중 취소**: 1 test
- **Race condition**: 식별된 race당 1 test
- **Timeout**: 1 test

## 7. Regression Test Rule

버그 리포트 시:
1. **버그를 재현하는 테스트** 작성 (반드시 실패해야 함)
2. 버그 수정
3. 테스트 **통과** 확인
4. 테스트 + 수정 함께 커밋

## 8. TDD Workflow

| Phase | 작업 | 검증 |
|-------|------|------|
| RED | 테스트 케이스 작성 | `npm run test:run` → 실패 확인 |
| GREEN | 최소 구현 코드 작성 | `npm run test:run` → 전체 통과 |
| REFACTOR | 코드 품질 개선 | `npm run test:run` → 여전히 통과 |

### Tool 추가 시 TDD 체크리스트

1. [ ] Tool 클래스 구현 (AgentTool 인터페이스)
2. [ ] `react-strategy.ts`의 tools 맵에 등록
3. [ ] `RiskClassifier`에 위험도 분류 추가
4. [ ] Tool 동작 테스트 작성 (`src/__tests__/unit/tools/{name}.test.ts`)
5. [ ] `npm run verify` 통과 확인

## 9. Test Patterns

### 순수 함수 테스트 (Mock 불필요)

```typescript
import { describe, it, expect } from 'vitest';
import { tryParseToolJson } from '../../agent/tool-json-parser';

describe('tryParseToolJson', () => {
  it('parses valid JSON object', () => {
    expect(tryParseToolJson('{"a": 1}')).toEqual({ a: 1 });
  });
});
```

### Tool 테스트 (자체 완결형)

```typescript
import { describe, it, expect } from 'vitest';
import { CalculatorTool } from '../../tools/calculator';

describe('CalculatorTool', () => {
  const calc = new CalculatorTool();
  it('adds two numbers', async () => {
    const result = await calc.execute('{"expression": "2+3"}');
    expect(result.output).toBe('5.0000');
  });
});
```

### SSE 스트리밍 테스트 (Mock fetch)

```typescript
import { describe, it, expect, vi } from 'vitest';
import { OpenAiClient } from '../../llm/openai-client';

describe('OpenAiClient', () => {
  it('yields text chunks from SSE', async () => {
    const client = new OpenAiClient(config);
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      new Response(stream, { status: 200 }),
    );
    // ... verify chunks
  });
});
```

### IndexedDB 테스트 (fake-indexeddb)

```typescript
import 'fake-indexeddb/auto';
import { conversationDb } from '../../services/conversation-db';

describe('conversationDb', () => {
  it('creates and retrieves conversation', async () => {
    const conv = await conversationDb.createConversation();
    const convs = await conversationDb.getAllConversations();
    expect(convs).toHaveLength(1);
  });
});
```

## 10. Required Dependencies

```json
{
  "devDependencies": {
    "vitest": "^1.0.0",
    "@testing-library/react": "^14.0.0",
    "@testing-library/jest-dom": "^6.0.0",
    "jsdom": "^24.0.0",
    "fake-indexeddb": "^6.0.0"
  }
}
```

## 11. Local Development & Verification

- 전체 검증: `npm run verify` (type-check + test + build)
- 테스트만: `npm run test:run`
- 특정 파일만: `npx vitest run src/__tests__/unit/tools/calculator.test.ts`
- 감시 모드: `npm run test`
- 정적 분석: `npm run type-check`
- 빌드: `npm run build`
- 테스트 실패 시 작업 중단, 다음 단계로 넘어가지 않음
