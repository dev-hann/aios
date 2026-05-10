import { OpenAiClient } from './openai-client';
import type {
  LlmResponseChunk,
  LlmGenerationConfig,
  LlmToolSchema,
} from './types';

const TAG = 'AIOS-LlmSession';

const COMPACT_THRESHOLD = 12000;
const MAX_COMPACTION_ATTEMPTS = 3;
const HARD_LIMIT_MESSAGES = 30;
const KEEP_RECENT_MESSAGES = 10;

export class LlmRemoteSession {
  private messages: Array<Record<string, unknown>> = [];
  private lastToolCalls: Array<Record<string, unknown>> | null = null;
  private compactionAttempts = 0;

  constructor(
    private client: OpenAiClient,
    private systemPrompt: string,
  ) {}

  async *chat(
    userParts: string[],
    config: LlmGenerationConfig,
    tools: LlmToolSchema[],
  ): AsyncGenerator<LlmResponseChunk> {
    if (userParts.length > 0 && userParts[0]) {
      this.messages.push({ role: 'user', content: userParts[0] });
    }

    await this.compactIfNeeded();

    console.log(`[${TAG}] chat: ${this.messages.length} msgs | ${this.messages.map(m => `${m['role']}:${String(m['content'] ?? '').substring(0, 40)}`).join(' | ')}`);

    const apiMessages: Array<Record<string, unknown>> = [
      { role: 'system', content: this.systemPrompt },
      ...this.messages,
    ];

    let fullContent = '';
    const toolCallAcc = new Map<number, { id: string; name: string; arguments: string }>();

    for await (const chunk of this.client.streamChat({
      messages: apiMessages,
      config,
      tools,
    })) {
      if (chunk.text) fullContent += chunk.text;

      if (chunk.toolCallDeltas) {
        for (const tc of chunk.toolCallDeltas) {
          const entry = toolCallAcc.get(tc.index) || { id: '', name: '', arguments: '' };
          if (tc.id) entry.id = tc.id;
          if (tc.name) entry.name = tc.name;
          if (tc.arguments) entry.arguments += tc.arguments;
          toolCallAcc.set(tc.index, entry);
        }
      }

      yield chunk;
    }

    const assistantMsg: Record<string, unknown> = { role: 'assistant' };
    if (fullContent) assistantMsg['content'] = fullContent;

    if (toolCallAcc.size > 0) {
      const toolCallsList: Array<Record<string, unknown>> = [];
      for (const [idx, tc] of toolCallAcc.entries()) {
        toolCallsList.push({
          id: tc.id || `call_${idx}`,
          type: 'function',
          function: { name: tc.name, arguments: tc.arguments },
        });
      }
      assistantMsg['tool_calls'] = toolCallsList;
      this.lastToolCalls = toolCallsList;
    } else {
      this.lastToolCalls = null;
    }

    this.messages.push(assistantMsg);
    console.log(`[${TAG}] chat complete: content=${fullContent.length}chars, toolCalls=${toolCallAcc.size}`);
  }

  addToolResult(toolName: string, result: string): void {
    const toolCallId = this.findToolCallId(toolName);
    this.messages.push({
      role: 'tool',
      tool_call_id: toolCallId,
      content: result,
    });
    console.log(`[${TAG}] Tool result added: ${toolName} (id=${toolCallId})`);
  }

  private async compactIfNeeded(): Promise<void> {
    const estimated = this.estimateTokens();
    if (estimated < COMPACT_THRESHOLD) return;

    if (this.compactionAttempts >= MAX_COMPACTION_ATTEMPTS) {
      console.warn(`[${TAG}] Compaction thrashing detected, applying hard limit`);
      this.applyHardLimit();
      return;
    }

    console.log(`[${TAG}] Compaction triggered: ~${estimated} tokens`);
    this.compactionAttempts++;

    const cleaned = this.stripToolOutputs();
    if (this.estimateTokensFor(cleaned) < COMPACT_THRESHOLD) {
      this.messages = cleaned;
      console.log(`[${TAG}] Compaction stage 1 done (tool output stripped)`);
      return;
    }

    const summary = await this.summarize(cleaned);
    if (summary) {
      const recent = cleaned.slice(-4);
      this.messages = [
        { role: 'user', content: `[이전 대화 요약]\n${summary}` },
        { role: 'assistant', content: '요약을 확인했습니다. 계속 도와드리겠습니다.' },
        ...recent,
      ];
      console.log(`[${TAG}] Compaction stage 2 done (summarized)`);
    } else {
      this.applyHardLimit();
    }
  }

  private stripToolOutputs(): Array<Record<string, unknown>> {
    const keepRecent = 4;
    return this.messages.map((msg, i) => {
      if (msg['role'] === 'tool' && i < this.messages.length - keepRecent) {
        return { ...msg, content: '[tool output removed]' };
      }
      return msg;
    });
  }

  private async summarize(messages: Array<Record<string, unknown>>): Promise<string> {
    const summarizationMessages = [
      {
        role: 'system',
        content: '다음 대화 기록을 간결한 구조화된 요약으로 압축하세요. 사용자 요청, 핵심 답변, 언급된 파일/코드, 에러와 해결, 진행 중인 작업만 보존하세요. 전체 도구 출력과 중간 과정은 제거하세요. 300자 이내.',
      },
      {
        role: 'user',
        content: JSON.stringify(
          messages.map((m) => ({
            role: m['role'],
            content: String(m['content'] ?? '').substring(0, 300),
          })),
        ),
      },
    ];

    try {
      const result = await this.client.chat({ messages: summarizationMessages, maxTokens: 500 });
      return result;
    } catch (e) {
      console.error(`[${TAG}] Compaction summarize failed:`, e);
      return '';
    }
  }

  private applyHardLimit(): void {
    if (this.messages.length <= HARD_LIMIT_MESSAGES) return;
    this.messages = this.messages.slice(-KEEP_RECENT_MESSAGES);
    console.log(`[${TAG}] Hard limit applied: ${this.messages.length} messages`);
  }

  private estimateTokens(): number {
    return this.estimateTokensFor(this.messages);
  }

  private estimateTokensFor(messages: Array<Record<string, unknown>>): number {
    let totalChars = 0;
    for (const msg of messages) {
      const content = String(msg['content'] ?? '');
      totalChars += content.length;
      const toolCalls = msg['tool_calls'] as Array<Record<string, unknown>> | undefined;
      if (toolCalls) {
        for (const tc of toolCalls) {
          const fn = tc['function'] as Record<string, unknown> | undefined;
          if (fn) totalChars += String(fn['arguments'] ?? '').length;
        }
      }
    }
    return Math.round(totalChars * 1.2);
  }

  private findToolCallId(toolName: string): string {
    if (!this.lastToolCalls) return '';
    for (const tc of this.lastToolCalls) {
      const fn = tc['function'] as Record<string, unknown> | undefined;
      if (fn?.['name'] === toolName) return (tc['id'] as string) || '';
    }
    return this.lastToolCalls.length > 0 ? (this.lastToolCalls[this.lastToolCalls.length - 1]['id'] as string) || '' : '';
  }
}
