export interface LlmToolParamSchema {
  name: string;
  description: string;
  type: string;
  required: boolean;
  isEnum?: boolean;
  enumValues?: string[];
  example?: string;
}

export interface LlmToolSchema {
  name: string;
  description: string;
  parameters: LlmToolParamSchema[];
}

export interface LlmToolCallDelta {
  index: number;
  id?: string;
  name?: string;
  arguments?: string;
}

export interface LlmResponseChunk {
  text?: string;
  thinking?: string;
  toolCallDeltas?: LlmToolCallDelta[];
  finishReason?: string;
}

export interface LlmGenerationConfig {
  temperature: number;
  topP: number;
  maxTokens: number;
}

export interface LlmModelInfo {
  id: string;
}

export interface LlmProviderConfig {
  providerType: string;
  apiKey: string;
  baseUrl: string;
  model: string;
  get chatEndpoint(): string;
  get modelsEndpoint(): string;
  get headers(): Record<string, string>;
}

const PROVIDER_BASE_URLS: Record<string, string> = {
  zai: 'https://api.z.ai/api/paas/v4',
  zaiCoding: 'https://api.z.ai/api/coding/paas/v4',
  openai: 'https://api.openai.com/v1',
  anthropic: 'https://api.anthropic.com/v1',
};

function resolveBaseUrl(providerType: string, baseUrl?: string): string {
  if (baseUrl && baseUrl.trim() !== '') return baseUrl;
  return PROVIDER_BASE_URLS[providerType] ?? baseUrl ?? '';
}

export function createProviderConfig(
  providerType: string,
  apiKey: string,
  baseUrl: string,
  model: string,
): LlmProviderConfig {
  const effectiveBaseUrl = resolveBaseUrl(providerType, baseUrl);
  return {
    providerType,
    apiKey,
    baseUrl: effectiveBaseUrl,
    model,
    get chatEndpoint(): string {
      return `${this.baseUrl}/chat/completions`;
    },
    get modelsEndpoint(): string {
      return `${this.baseUrl}/models`;
    },
    get headers(): Record<string, string> {
      return {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.apiKey}`,
      };
    },
  };
}
