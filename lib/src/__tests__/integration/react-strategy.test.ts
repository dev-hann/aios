import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ReactStrategy } from '../../agent/react-strategy';
import { createProviderConfig } from '../../llm/types';
import type { AgentTool } from '../../tools/types';
import type { ToolResult } from '../../types/agent';
import { toolResultOk } from '../../types/agent';

class MockTool implements AgentTool {
  readonly name: string;
  readonly description = 'Mock tool';
  readonly parameters = '{"input": "string"}';
  readonly toolPrompt = 'Mock tool for testing';
  private result: ToolResult;
  public lastArgs: string | null = null;
  public callCount = 0;

  constructor(name: string, result?: ToolResult) {
    this.name = name;
    this.result = result ?? toolResultOk('mock result');
  }

  async execute(args: string): Promise<ToolResult> {
    this.lastArgs = args;
    this.callCount++;
    return this.result;
  }
}

function makeTextResponse(text: string): Response {
  const sse = `data: {"choices":[{"delta":{"content":"${text}"}}]}\ndata: [DONE]\n`;
  return new Response(
    new ReadableStream({
      start(controller) {
        controller.enqueue(new TextEncoder().encode(sse));
        controller.close();
      },
    }),
    { status: 200 },
  );
}

function makeToolCallResponse(toolName: string, args: string): Response {
  const escapedArgs = args.replace(/"/g, '\\"');
  const sse = `data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"${toolName}","arguments":"${escapedArgs}"}}]}}]}\ndata: [DONE]\n`;
  return new Response(
    new ReadableStream({
      start(controller) {
        controller.enqueue(new TextEncoder().encode(sse));
        controller.close();
      },
    }),
    { status: 200 },
  );
}

describe('ReactStrategy', () => {
  let tools: Map<string, AgentTool>;
  let config: ReturnType<typeof createProviderConfig>;

  beforeEach(() => {
    tools = new Map();
    config = createProviderConfig('openai', 'sk-test', 'http://localhost:1234', 'test-model');
    vi.restoreAllMocks();
  });

  describe('execute - text response', () => {
    it('returns answer for text-only LLM response', async () => {
      const calcTool = new MockTool('calculator');
      tools.set('calculator', calcTool);

      vi.spyOn(globalThis, 'fetch').mockResolvedValue(makeTextResponse('Hello!'));

      const strategy = new ReactStrategy(tools, config);
      const steps: any[] = [];
      const result = await strategy.execute('hi', (step) => steps.push(step));

      expect(result.success).toBe(true);
      const answer = result.steps.find((s) => s.type === 'answer');
      expect(answer?.content).toBe('Hello!');
    });
  });

  describe('execute - tool calls', () => {
    it('executes tool and returns result', async () => {
      const calcTool = new MockTool('calculator', toolResultOk('5.0000'));
      tools.set('calculator', calcTool);

      let callCount = 0;
      vi.spyOn(globalThis, 'fetch').mockImplementation(() => {
        callCount++;
        if (callCount === 1) {
          return Promise.resolve(makeToolCallResponse('calculator', '{"expression":"2+3"}'));
        }
        return Promise.resolve(makeTextResponse('The answer is 5'));
      });

      const strategy = new ReactStrategy(tools, config);
      const result = await strategy.execute('calculate 2+3');

      expect(result.success).toBe(true);
      expect(calcTool.callCount).toBe(1);
      const obs = result.steps.find((s) => s.type === 'observation');
      expect(obs).toBeDefined();
    });
  });

  describe('execute - unknown tool', () => {
    it.todo('handles unknown tool gracefully - SSE stream reuse issue in test env');
  });

  describe('execute - cancel', () => {
    it('stops when cancelled before execution', async () => {
      vi.spyOn(globalThis, 'fetch').mockResolvedValue(makeTextResponse('thinking...'));

      const strategy = new ReactStrategy(tools, config);
      strategy.cancel();
      const result = await strategy.execute('test');

      expect(result.steps.some((s) => s.type === 'answer')).toBe(true);
    });
  });

  describe('clearHistory', () => {
    it('clears session without error', () => {
      const strategy = new ReactStrategy(tools, config);
      expect(() => strategy.clearHistory()).not.toThrow();
    });
  });

  describe('system prompt', () => {
    it('includes tool descriptions in system message', async () => {
      const mockTool = new MockTool('calculator');
      tools.set('calculator', mockTool);

      let capturedBody: any = null;
      vi.spyOn(globalThis, 'fetch').mockImplementation((_url: any, options: any) => {
        capturedBody = JSON.parse(options.body);
        return Promise.resolve(makeTextResponse('ok'));
      });

      const strategy = new ReactStrategy(tools, config);
      await strategy.execute('test');

      expect(capturedBody).not.toBeNull();
      const systemMsg = capturedBody.messages[0];
      expect(systemMsg.role).toBe('system');
      expect(systemMsg.content).toContain('calculator');
      expect(systemMsg.content).toContain('AIOS');
    });
  });

  describe('recordTurn', () => {
    it('records turn in conversation context', async () => {
      const { ConversationContext } = await import('../../agent/conversation-context');
      const ctx = new ConversationContext();
      const mockTool = new MockTool('calculator');
      tools.set('calculator', mockTool);

      vi.spyOn(globalThis, 'fetch').mockResolvedValue(makeTextResponse('answer'));

      const strategy = new ReactStrategy(tools, config);
      strategy.setConversationContext(ctx);
      await strategy.execute('test');

      expect(ctx.length).toBe(1);
    });
  });
});
