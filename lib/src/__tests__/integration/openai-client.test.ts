import { describe, it, expect, vi, beforeEach } from 'vitest';
import { OpenAiClient } from '../../llm/openai-client';
import { createProviderConfig } from '../../llm/types';
import type { LlmToolSchema } from '../../llm/types';

function createTestClient(): OpenAiClient {
  const config = createProviderConfig('openai', 'sk-test', 'http://localhost:1234', 'test-model');
  return new OpenAiClient(config);
}

describe('OpenAiClient', () => {
  describe('convertTools', () => {
    const client = createTestClient();

    it('converts empty array', () => {
      expect(client.convertTools([])).toEqual([]);
    });

    it('converts tool with required parameters', () => {
      const tools: LlmToolSchema[] = [
        {
          name: 'calculator',
          description: 'Calculate',
          parameters: [
            { name: 'expression', description: 'Math expression', type: 'string', required: true },
          ],
        },
      ];
      const result = client.convertTools(tools);
      expect(result).toHaveLength(1);
      expect(result[0]).toEqual({
        type: 'function',
        function: {
          name: 'calculator',
          description: 'Calculate',
          parameters: {
            type: 'object',
            properties: {
              expression: { type: 'string', description: 'Math expression' },
            },
            required: ['expression'],
          },
        },
      });
    });

    it('converts tool with optional parameters (no required array)', () => {
      const tools: LlmToolSchema[] = [
        {
          name: 'tool',
          description: 'A tool',
          parameters: [
            { name: 'name', description: 'optional name', type: 'string', required: false },
          ],
        },
      ];
      const result = client.convertTools(tools);
      const fn = result[0].function as Record<string, unknown>;
      const params = fn.parameters as Record<string, unknown>;
      expect(params).not.toHaveProperty('required');
    });

    it('converts tool with enum parameter', () => {
      const tools: LlmToolSchema[] = [
        {
          name: 'tool',
          description: 'A tool',
          parameters: [
            {
              name: 'action',
              description: 'Action',
              type: 'string',
              required: true,
              isEnum: true,
              enumValues: ['save', 'get'],
            },
          ],
        },
      ];
      const result = client.convertTools(tools);
      const fn = result[0].function as Record<string, unknown>;
      const params = fn.parameters as Record<string, unknown>;
      const props = params.properties as Record<string, Record<string, unknown>>;
      expect(props['action']['enum']).toEqual(['save', 'get']);
    });

    it('converts tool with example', () => {
      const tools: LlmToolSchema[] = [
        {
          name: 'tool',
          description: 'A tool',
          parameters: [
            {
              name: 'expr',
              description: 'Expression',
              type: 'string',
              required: true,
              example: '2+3',
            },
          ],
        },
      ];
      const result = client.convertTools(tools);
      const fn = result[0].function as Record<string, unknown>;
      const params = fn.parameters as Record<string, unknown>;
      const props = params.properties as Record<string, Record<string, unknown>>;
      expect(props['expr']['example']).toBe('2+3');
    });

    it('converts tool with mixed required/optional parameters', () => {
      const tools: LlmToolSchema[] = [
        {
          name: 'tool',
          description: 'A tool',
          parameters: [
            { name: 'required1', description: 'Required', type: 'string', required: true },
            { name: 'required2', description: 'Required', type: 'string', required: true },
            { name: 'optional1', description: 'Optional', type: 'string', required: false },
          ],
        },
      ];
      const result = client.convertTools(tools);
      const fn = result[0].function as Record<string, unknown>;
      const params = fn.parameters as Record<string, unknown>;
      expect(params['required']).toEqual(['required1', 'required2']);
    });

    it('converts multiple tools', () => {
      const tools: LlmToolSchema[] = [
        { name: 'a', description: 'Tool A', parameters: [] },
        { name: 'b', description: 'Tool B', parameters: [] },
      ];
      const result = client.convertTools(tools);
      expect(result).toHaveLength(2);
      const fn0 = result[0].function as Record<string, unknown>;
      const fn1 = result[1].function as Record<string, unknown>;
      expect(fn0.name).toBe('a');
      expect(fn1.name).toBe('b');
    });

    it('handles tool with no parameters', () => {
      const tools: LlmToolSchema[] = [
        { name: 'noop', description: 'No params', parameters: [] },
      ];
      const result = client.convertTools(tools);
      const fn = result[0].function as Record<string, unknown>;
      const params = fn.parameters as Record<string, unknown>;
      expect(params.properties).toEqual({});
    });
  });

  describe('streamChat', () => {
    beforeEach(() => {
      vi.restoreAllMocks();
    });

    it('throws on HTTP error', async () => {
      const client = createTestClient();
      vi.spyOn(globalThis, 'fetch').mockResolvedValue(
        new Response('Bad Request', { status: 400 }),
      );
      const gen = client.streamChat({
        messages: [],
        config: { temperature: 0.7, topP: 1, maxTokens: 100 },
        tools: [],
      });
      await expect(gen.next()).rejects.toThrow('HTTP 400');
    });

    it('yields text chunks from SSE', async () => {
      const client = createTestClient();
      const sseData = [
        'data: {"choices":[{"delta":{"content":"Hello"}}]}',
        'data: {"choices":[{"delta":{"content":" World"}}]}',
        'data: [DONE]',
      ].join('\n');

      const stream = new ReadableStream({
        start(controller) {
          controller.enqueue(new TextEncoder().encode(sseData));
          controller.close();
        },
      });

      vi.spyOn(globalThis, 'fetch').mockResolvedValue(
        new Response(stream, { status: 200 }),
      );

      const chunks: string[] = [];
      for await (const chunk of client.streamChat({
        messages: [],
        config: { temperature: 0.7, topP: 1, maxTokens: 100 },
        tools: [],
      })) {
        if (chunk.text) chunks.push(chunk.text);
      }
      expect(chunks).toEqual(['Hello', ' World']);
    });

    it('yields thinking chunks', async () => {
      const client = createTestClient();
      const sseData = 'data: {"choices":[{"delta":{"reasoning_content":"thinking..."}}]}\n\n';

      const stream = new ReadableStream({
        start(controller) {
          controller.enqueue(new TextEncoder().encode(sseData));
          controller.close();
        },
      });

      vi.spyOn(globalThis, 'fetch').mockResolvedValue(
        new Response(stream, { status: 200 }),
      );

      const chunks: string[] = [];
      for await (const chunk of client.streamChat({
        messages: [],
        config: { temperature: 0.7, topP: 1, maxTokens: 100 },
        tools: [],
      })) {
        if (chunk.thinking) chunks.push(chunk.thinking);
      }
      expect(chunks).toEqual(['thinking...']);
    });

    it('yields tool call deltas', async () => {
      const client = createTestClient();
      const sseData = [
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"calculator","arguments":"{\\"expr"}}]}}]}',
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"ession\\": \\"2+3\\"}"}}]}}]}',
        'data: [DONE]',
      ].join('\n');

      const stream = new ReadableStream({
        start(controller) {
          controller.enqueue(new TextEncoder().encode(sseData));
          controller.close();
        },
      });

      vi.spyOn(globalThis, 'fetch').mockResolvedValue(
        new Response(stream, { status: 200 }),
      );

      const chunks: any[] = [];
      for await (const chunk of client.streamChat({
        messages: [],
        config: { temperature: 0.7, topP: 1, maxTokens: 100 },
        tools: [],
      })) {
        if (chunk.toolCallDeltas) chunks.push(...chunk.toolCallDeltas);
      }
      expect(chunks).toHaveLength(2);
      expect(chunks[0].name).toBe('calculator');
      expect(chunks[0].id).toBe('call_1');
      expect(chunks[0].arguments).toBe('{"expr');
      expect(chunks[1].arguments).toBe('ession": "2+3"}');
    });

    it('skips malformed SSE lines', async () => {
      const client = createTestClient();
      const sseData = [
        'data: {"choices":[{"delta":{"content":"ok"}}]}',
        'not a data line',
        'data: invalid json',
        'data: {"choices":[{"delta":{"content":" done"}}]}',
        'data: [DONE]',
      ].join('\n');

      const stream = new ReadableStream({
        start(controller) {
          controller.enqueue(new TextEncoder().encode(sseData));
          controller.close();
        },
      });

      vi.spyOn(globalThis, 'fetch').mockResolvedValue(
        new Response(stream, { status: 200 }),
      );

      const chunks: string[] = [];
      for await (const chunk of client.streamChat({
        messages: [],
        config: { temperature: 0.7, topP: 1, maxTokens: 100 },
        tools: [],
      })) {
        if (chunk.text) chunks.push(chunk.text);
      }
      expect(chunks).toEqual(['ok', ' done']);
    });
  });

  describe('fetchModels', () => {
    beforeEach(() => {
      vi.restoreAllMocks();
    });

    it('fetches models from array response', async () => {
      const client = createTestClient();
      vi.spyOn(globalThis, 'fetch').mockResolvedValue(
        new Response(JSON.stringify([{ id: 'model-a' }, { id: 'model-b' }]), { status: 200 }),
      );
      const models = await client.fetchModels();
      expect(models).toEqual([{ id: 'model-a' }, { id: 'model-b' }]);
    });

    it('fetches models from {data: [...]} response', async () => {
      const client = createTestClient();
      vi.spyOn(globalThis, 'fetch').mockResolvedValue(
        new Response(JSON.stringify({ data: [{ id: 'model-x' }] }), { status: 200 }),
      );
      const models = await client.fetchModels();
      expect(models).toEqual([{ id: 'model-x' }]);
    });

    it('skips items without id', async () => {
      const client = createTestClient();
      vi.spyOn(globalThis, 'fetch').mockResolvedValue(
        new Response(JSON.stringify([{ id: 'ok' }, { name: 'no-id' }]), { status: 200 }),
      );
      const models = await client.fetchModels();
      expect(models).toEqual([{ id: 'ok' }]);
    });

    it('returns empty array on error', async () => {
      const client = createTestClient();
      vi.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('Network error'));
      const models = await client.fetchModels();
      expect(models).toEqual([]);
    });
  });

  describe('testConnection', () => {
    beforeEach(() => {
      vi.restoreAllMocks();
    });

    it('returns true on success', async () => {
      const client = createTestClient();
      vi.spyOn(globalThis, 'fetch').mockResolvedValue(
        new Response('ok', { status: 200 }),
      );
      expect(await client.testConnection()).toBe(true);
    });

    it('returns false on error', async () => {
      const client = createTestClient();
      vi.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('fail'));
      expect(await client.testConnection()).toBe(false);
    });
  });

  describe('cancel', () => {
    it('calls abort on active controller', async () => {
      const client = createTestClient();
      const sseData = 'data: {"choices":[{"delta":{"content":"hi"}}]}\n\ndata: [DONE]\n';

      const stream = new ReadableStream({
        start(controller) {
          controller.enqueue(new TextEncoder().encode(sseData));
          controller.close();
        },
      });

      vi.spyOn(globalThis, 'fetch').mockResolvedValue(
        new Response(stream, { status: 200 }),
      );

      const gen = client.streamChat({
        messages: [],
        config: { temperature: 0.7, topP: 1, maxTokens: 100 },
        tools: [],
      });
      await gen.next();
      client.cancel();
    });
  });
});
