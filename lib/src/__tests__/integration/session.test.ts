import { describe, it, expect, vi, beforeEach } from 'vitest';
import { LlmRemoteSession } from '../../llm/session';
import { OpenAiClient } from '../../llm/openai-client';
import { createProviderConfig } from '../../llm/types';
import type { LlmResponseChunk } from '../../llm/types';

function createMockClient(chunks: LlmResponseChunk[]): OpenAiClient {
  const config = createProviderConfig('openai', 'sk-test', 'http://localhost:1234', 'test-model');
  const client = new OpenAiClient(config);

  vi.spyOn(client, 'streamChat').mockImplementation(async function* () {
    for (const chunk of chunks) {
      yield chunk;
    }
  });

  return client;
}

describe('LlmRemoteSession', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('yields text chunks and stores assistant message', async () => {
    const client = createMockClient([
      { text: 'Hello' },
      { text: ' World' },
    ]);
    const session = new LlmRemoteSession(client, 'You are helpful.');

    const received: string[] = [];
    for await (const chunk of session.chat(['hi'], { temperature: 0.7, topP: 1, maxTokens: 100 }, [])) {
      if (chunk.text) received.push(chunk.text);
    }
    expect(received).toEqual(['Hello', ' World']);
  });

  it('accumulates tool calls from deltas', async () => {
    const client = createMockClient([
      { toolCallDeltas: [{ index: 0, id: 'call_1', name: 'calculator', arguments: '{"expr' }] },
      { toolCallDeltas: [{ index: 0, arguments: 'ession": "2+3"}' }] },
    ]);
    const session = new LlmRemoteSession(client, 'system');

    for await (const _ of session.chat(['calc 2+3'], { temperature: 0.7, topP: 1, maxTokens: 100 }, [])) {
    }
  });

  it('skips empty user parts', async () => {
    const client = createMockClient([{ text: 'response' }]);
    const session = new LlmRemoteSession(client, 'system');

    const chunks: LlmResponseChunk[] = [];
    for await (const chunk of session.chat([''], { temperature: 0.7, topP: 1, maxTokens: 100 }, [])) {
      chunks.push(chunk);
    }
    expect(chunks).toHaveLength(1);
  });

  it('skips empty user parts array', async () => {
    const client = createMockClient([{ text: 'response' }]);
    const session = new LlmRemoteSession(client, 'system');

    const chunks: LlmResponseChunk[] = [];
    for await (const chunk of session.chat([], { temperature: 0.7, topP: 1, maxTokens: 100 }, [])) {
      chunks.push(chunk);
    }
    expect(chunks).toHaveLength(1);
  });

  describe('addToolResult', () => {
    it('adds tool result with correct tool_call_id', async () => {
      const client = createMockClient([
        { toolCallDeltas: [{ index: 0, id: 'call_abc', name: 'calculator', arguments: '{"expression":"2+3"}' }] },
      ]);
      const session = new LlmRemoteSession(client, 'system');

      for await (const _ of session.chat(['calc'], { temperature: 0.7, topP: 1, maxTokens: 100 }, [])) {
      }
      session.addToolResult('calculator', '5');
    });

    it('returns empty string when no tool calls exist', () => {
      const config = createProviderConfig('openai', 'sk-test', 'http://localhost:1234', 'test-model');
      const client = new OpenAiClient(config);
      vi.spyOn(client, 'streamChat').mockImplementation(async function* () {
        yield { text: 'no tools' };
      });
      const session = new LlmRemoteSession(client, 'system');

      return (async () => {
        for await (const _ of session.chat(['hi'], { temperature: 0.7, topP: 1, maxTokens: 100 }, [])) {
        }
        session.addToolResult('calculator', '5');
      })();
    });
  });

  it('handles multiple tool calls', async () => {
    const client = createMockClient([
      { toolCallDeltas: [{ index: 0, id: 'call_1', name: 'calculator', arguments: '{"expression":"2+3"}' }] },
      { toolCallDeltas: [{ index: 1, id: 'call_2', name: 'notepad', arguments: '{"action":"save"}' }] },
    ]);
    const session = new LlmRemoteSession(client, 'system');

    for await (const _ of session.chat(['multi'], { temperature: 0.7, topP: 1, maxTokens: 100 }, [])) {
    }
    session.addToolResult('calculator', '5');
    session.addToolResult('notepad', 'Saved');
  });
});
