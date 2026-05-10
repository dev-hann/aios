import { OpenAiClient } from './openai-client';
import type {
  LlmResponseChunk,
  LlmGenerationConfig,
  LlmToolSchema,
} from './types';

const TAG = 'AIOS-LlmSession';

export class LlmRemoteSession {
  private messages: Array<Record<string, unknown>> = [];
  private lastToolCalls: Array<Record<string, unknown>> | null = null;

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

  private findToolCallId(toolName: string): string {
    if (!this.lastToolCalls) return '';
    for (const tc of this.lastToolCalls) {
      const fn = tc['function'] as Record<string, unknown> | undefined;
      if (fn?.['name'] === toolName) return (tc['id'] as string) || '';
    }
    return this.lastToolCalls.length > 0 ? (this.lastToolCalls[this.lastToolCalls.length - 1]['id'] as string) || '' : '';
  }
}
