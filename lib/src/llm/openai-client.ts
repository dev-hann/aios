import type {
  LlmResponseChunk,
  LlmGenerationConfig,
  LlmToolSchema,
  LlmModelInfo,
  LlmProviderConfig,
} from './types';

const TAG = 'AIOS-OpenAiClient';

export class OpenAiClient {
  private abortController: AbortController | null = null;

  constructor(private config: LlmProviderConfig) {}

  async *streamChat(params: {
    messages: Array<Record<string, unknown>>;
    config: LlmGenerationConfig;
    tools: LlmToolSchema[];
  }): AsyncGenerator<LlmResponseChunk> {
    const { messages, config, tools } = params;

    const body: Record<string, unknown> = {
      model: this.config.model,
      messages,
      stream: true,
      temperature: config.temperature,
      top_p: config.topP,
      max_tokens: config.maxTokens,
    };

    if (tools.length > 0) {
      body.tools = this.convertTools(tools);
      body.tool_choice = 'auto';
    }

    this.abortController = new AbortController();

    const response = await fetch(this.config.chatEndpoint, {
      method: 'POST',
      headers: this.config.headers,
      body: JSON.stringify(body),
      signal: this.abortController.signal,
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error(`[${TAG}] HTTP ${response.status}: ${errorBody}`);
      throw new Error(`HTTP ${response.status}: ${errorBody}`);
    }

    const reader = response.body?.getReader();
    if (!reader) throw new Error('No response body');

    const decoder = new TextDecoder();
    let buffer = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed || trimmed === 'data: [DONE]') continue;
        if (!trimmed.startsWith('data: ')) continue;

        try {
          const data = JSON.parse(trimmed.slice(6));
          const choices = data.choices as Array<Record<string, unknown>> | undefined;
          if (!choices || choices.length === 0) continue;

          const delta = (choices[0] as Record<string, unknown>)['delta'] as Record<string, unknown> | undefined ?? {};

          if (typeof delta['content'] === 'string') {
            yield { text: delta['content'] as string };
          }

          const reasoning = delta['reasoning_content'];
          if (typeof reasoning === 'string') {
            yield { thinking: reasoning as string };
          }

          const toolCalls = delta['tool_calls'] as Array<Record<string, unknown>> | undefined;
          if (toolCalls) {
            const deltas = toolCalls.map((tc) => {
              const func = tc['function'] as Record<string, string> | undefined;
              return {
                index: (tc['index'] as number) ?? 0,
                id: tc['id'] as string | undefined,
                name: func?.['name'],
                arguments: func?.['arguments'],
              };
            });
            yield { toolCallDeltas: deltas };
          }

          const finishReason = (choices[0] as Record<string, unknown>)['finish_reason'] as string | null | undefined;
          if (finishReason) {
            yield { finishReason };
          }
        } catch (e) {
          console.warn(`[${TAG}] SSE parse error:`, e);
        }
      }
    }
  }

  async chat(params: {
    messages: Array<Record<string, unknown>>;
    maxTokens?: number;
  }): Promise<string> {
    const body: Record<string, unknown> = {
      model: this.config.model,
      messages: params.messages,
      max_tokens: params.maxTokens ?? 500,
      stream: false,
    };

    const response = await fetch(this.config.chatEndpoint, {
      method: 'POST',
      headers: this.config.headers,
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error(`[${TAG}] HTTP ${response.status}: ${errorBody}`);
      return '';
    }

    const data = await response.json() as Record<string, unknown>;
    const choices = data.choices as Array<Record<string, unknown>> | undefined;
    if (!choices || choices.length === 0) return '';
    const message = choices[0]['message'] as Record<string, unknown> | undefined;
    return (message?.['content'] as string) ?? '';
  }

  async fetchModels(): Promise<LlmModelInfo[]> {
    try {
      const response = await fetch(this.config.modelsEndpoint, {
        headers: this.config.headers,
      });
      const data = await response.json();
      const modelList = Array.isArray(data) ? data : data.data;
      const models: LlmModelInfo[] = [];
      for (const item of modelList ?? []) {
        const id = item.id as string;
        if (id) models.push({ id });
      }
      console.log(`[${TAG}] Fetched ${models.length} models`);
      return models;
    } catch (e) {
      console.error(`[${TAG}] fetchModels failed:`, e);
      return [];
    }
  }

  async testConnection(): Promise<boolean> {
    try {
      await fetch(this.config.chatEndpoint, {
        method: 'POST',
        headers: this.config.headers,
        body: JSON.stringify({
          model: this.config.model,
          messages: [{ role: 'user', content: 'ping' }],
          max_tokens: 1,
          stream: false,
        }),
      });
      console.log(`[${TAG}] Connection test passed`);
      return true;
    } catch (e) {
      console.error(`[${TAG}] Connection test failed:`, e);
      return false;
    }
  }

  convertTools(tools: LlmToolSchema[]): Array<Record<string, unknown>> {
    return tools.map((t) => {
      const properties: Record<string, unknown> = {};
      const requiredParams: string[] = [];

      for (const p of t.parameters) {
        const prop: Record<string, unknown> = {
          type: p.type,
          description: p.description,
        };
        if (p.isEnum && p.enumValues) prop['enum'] = p.enumValues;
        if (p.example) prop['example'] = p.example;
        properties[p.name] = prop;
        if (p.required) requiredParams.push(p.name);
      }

      return {
        type: 'function',
        function: {
          name: t.name,
          description: t.description,
          parameters: {
            type: 'object',
            properties,
            ...(requiredParams.length > 0 && { required: requiredParams }),
          },
        },
      };
    });
  }

  cancel(): void {
    this.abortController?.abort();
    this.abortController = null;
  }
}
