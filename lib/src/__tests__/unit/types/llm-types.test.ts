import { describe, it, expect } from 'vitest';
import { createProviderConfig } from '../../../llm/types';

describe('createProviderConfig', () => {
  describe('baseUrl resolution for known providers', () => {
    it('resolves zai to correct baseUrl', () => {
      const config = createProviderConfig('zai', 'key', '', 'model');
      expect(config.baseUrl).toBe('https://api.z.ai/api/paas/v4');
    });

    it('resolves zaiCoding to correct baseUrl', () => {
      const config = createProviderConfig('zaiCoding', 'key', '', 'model');
      expect(config.baseUrl).toBe('https://api.z.ai/api/coding/paas/v4');
    });

    it('resolves openai to correct baseUrl', () => {
      const config = createProviderConfig('openai', 'key', '', 'model');
      expect(config.baseUrl).toBe('https://api.openai.com/v1');
    });

    it('resolves anthropic to correct baseUrl', () => {
      const config = createProviderConfig('anthropic', 'key', '', 'model');
      expect(config.baseUrl).toBe('https://api.anthropic.com/v1');
    });
  });

  describe('baseUrl with custom override', () => {
    it('uses custom baseUrl when provided', () => {
      const config = createProviderConfig('zai', 'key', 'https://custom.api.com', 'model');
      expect(config.baseUrl).toBe('https://custom.api.com');
    });

    it('uses custom baseUrl even for known provider', () => {
      const config = createProviderConfig('openai', 'key', 'http://localhost:8080', 'model');
      expect(config.baseUrl).toBe('http://localhost:8080');
    });

    it('ignores whitespace-only baseUrl', () => {
      const config = createProviderConfig('zai', 'key', '   ', 'model');
      expect(config.baseUrl).toBe('https://api.z.ai/api/paas/v4');
    });
  });

  describe('unknown provider', () => {
    it('returns empty baseUrl for unknown provider without custom baseUrl', () => {
      const config = createProviderConfig('unknown_provider', 'key', '', 'model');
      expect(config.baseUrl).toBe('');
    });

    it('uses custom baseUrl for unknown provider', () => {
      const config = createProviderConfig('unknown_provider', 'key', 'https://my.api.com', 'model');
      expect(config.baseUrl).toBe('https://my.api.com');
    });
  });

  describe('getters', () => {
    const config = createProviderConfig('openai', 'sk-test-key', '', 'gpt-4');

    it('chatEndpoint appends /chat/completions', () => {
      expect(config.chatEndpoint).toBe('https://api.openai.com/v1/chat/completions');
    });

    it('modelsEndpoint appends /models', () => {
      expect(config.modelsEndpoint).toBe('https://api.openai.com/v1/models');
    });

    it('headers returns Bearer token', () => {
      expect(config.headers).toEqual({
        'Content-Type': 'application/json',
        Authorization: 'Bearer sk-test-key',
      });
    });
  });

  describe('field passthrough', () => {
    it('preserves providerType, apiKey, model', () => {
      const config = createProviderConfig('zaiCoding', 'my-key', '', 'glm-4');
      expect(config.providerType).toBe('zaiCoding');
      expect(config.apiKey).toBe('my-key');
      expect(config.model).toBe('glm-4');
    });
  });
});
