import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ReactStrategy } from '../../../agent/react-strategy';
import { createProviderConfig } from '../../../llm/types';
import type { AgentTool } from '../../../tools/types';
import { toolResultOk } from '../../../types/agent';

class MockTool implements AgentTool {
  readonly name = 'mock';
  readonly description = 'mock';
  readonly parameters = '{}';
  readonly toolPrompt = 'mock';
  async execute(): Promise<import('../../../types/agent').ToolResult> {
    return toolResultOk('ok');
  }
}

describe('ReactStrategy setGenerationConfig', () => {
  let tools: Map<string, AgentTool>;
  let config: ReturnType<typeof createProviderConfig>;

  beforeEach(() => {
    tools = new Map();
    tools.set('mock', new MockTool());
    config = createProviderConfig('openai', 'sk-test', 'http://localhost:1234', 'test');
    vi.restoreAllMocks();
  });

  it('uses default generation config when not set', async () => {
    let capturedBody: Record<string, unknown> | null = null;
    vi.spyOn(globalThis, 'fetch').mockImplementation((_url: unknown, options: any) => {
      capturedBody = JSON.parse(options.body);
      return Promise.resolve(
        new Response(
          new ReadableStream({
            start(c) {
              c.enqueue(new TextEncoder().encode('data: {"choices":[{"delta":{"content":"hi"}}]}\ndata: [DONE]\n'));
              c.close();
            },
          }),
          { status: 200 },
        ),
      );
    });

    const strategy = new ReactStrategy(tools, config);
    await strategy.execute('test');

    expect(capturedBody).not.toBeNull();
    expect(capturedBody!.temperature).toBe(1.0);
    expect(capturedBody!.top_p).toBe(0.95);
    expect(capturedBody!.max_tokens).toBe(8192);
  });

  it('applies setGenerationConfig before execute', async () => {
    let capturedBody: Record<string, unknown> | null = null;
    vi.spyOn(globalThis, 'fetch').mockImplementation((_url: unknown, options: any) => {
      capturedBody = JSON.parse(options.body);
      return Promise.resolve(
        new Response(
          new ReadableStream({
            start(c) {
              c.enqueue(new TextEncoder().encode('data: {"choices":[{"delta":{"content":"ok"}}]}\ndata: [DONE]\n'));
              c.close();
            },
          }),
          { status: 200 },
        ),
      );
    });

    const strategy = new ReactStrategy(tools, config);
    strategy.setGenerationConfig({ temperature: 0.3, topP: 0.5, maxTokens: 256 });
    await strategy.execute('test');

    expect(capturedBody!.temperature).toBe(0.3);
    expect(capturedBody!.top_p).toBe(0.5);
    expect(capturedBody!.max_tokens).toBe(256);
  });

  it('merges partial generation config', async () => {
    let capturedBody: Record<string, unknown> | null = null;
    vi.spyOn(globalThis, 'fetch').mockImplementation((_url: unknown, options: any) => {
      capturedBody = JSON.parse(options.body);
      return Promise.resolve(
        new Response(
          new ReadableStream({
            start(c) {
              c.enqueue(new TextEncoder().encode('data: {"choices":[{"delta":{"content":"ok"}}]}\ndata: [DONE]\n'));
              c.close();
            },
          }),
          { status: 200 },
        ),
      );
    });

    const strategy = new ReactStrategy(tools, config);
    strategy.setGenerationConfig({ temperature: 0.5 });
    await strategy.execute('test');

    expect(capturedBody!.temperature).toBe(0.5);
    expect(capturedBody!.top_p).toBe(0.95);
    expect(capturedBody!.max_tokens).toBe(8192);
  });

  it('overrides previous config on subsequent calls', async () => {
    let capturedBody: Record<string, unknown> | null = null;
    vi.spyOn(globalThis, 'fetch').mockImplementation((_url: unknown, options: any) => {
      capturedBody = JSON.parse(options.body);
      return Promise.resolve(
        new Response(
          new ReadableStream({
            start(c) {
              c.enqueue(new TextEncoder().encode('data: {"choices":[{"delta":{"content":"ok"}}]}\ndata: [DONE]\n'));
              c.close();
            },
          }),
          { status: 200 },
        ),
      );
    });

    const strategy = new ReactStrategy(tools, config);
    strategy.setGenerationConfig({ temperature: 0.1, topP: 0.2, maxTokens: 100 });
    strategy.setGenerationConfig({ temperature: 0.8 });
    await strategy.execute('test');

    expect(capturedBody!.temperature).toBe(0.8);
    expect(capturedBody!.top_p).toBe(0.2);
    expect(capturedBody!.max_tokens).toBe(100);
  });
});
