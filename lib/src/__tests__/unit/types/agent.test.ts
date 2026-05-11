import { describe, it, expect } from 'vitest';
import { toolResultOk, toolResultErr, isToolError, toContent } from '../../../types/agent';

describe('toolResultOk', () => {
  it('returns ToolResult with output only', () => {
    const result = toolResultOk('hello');
    expect(result).toEqual({ output: 'hello' });
    expect(result.error).toBeUndefined();
    expect(result.system).toBeUndefined();
    expect(result.observation).toBeUndefined();
  });

  it('returns ToolResult with output and system', () => {
    const result = toolResultOk('hello', 'sys');
    expect(result).toEqual({ output: 'hello', system: 'sys' });
  });

  it('returns ToolResult with all fields', () => {
    const result = toolResultOk('hello', 'sys', 'obs');
    expect(result).toEqual({ output: 'hello', system: 'sys', observation: 'obs' });
  });

  it('handles empty output', () => {
    const result = toolResultOk('');
    expect(result.output).toBe('');
  });
});

describe('toolResultErr', () => {
  it('returns ToolResult with error', () => {
    const result = toolResultErr('something failed');
    expect(result).toEqual({ error: 'something failed' });
    expect(result.output).toBeUndefined();
  });

  it('handles empty error string', () => {
    const result = toolResultErr('');
    expect(result.error).toBe('');
  });
});

describe('isToolError', () => {
  it('returns true when error is present', () => {
    expect(isToolError({ error: 'fail' })).toBe(true);
  });

  it('returns true when error is empty string', () => {
    expect(isToolError({ error: '' })).toBe(true);
  });

  it('returns false when error is undefined', () => {
    expect(isToolError({ output: 'ok' })).toBe(false);
  });

  it('returns false for empty object', () => {
    expect(isToolError({})).toBe(false);
  });

  it('returns false when error is null', () => {
    expect(isToolError({ error: null as any })).toBe(false);
  });
});

describe('toContent', () => {
  it('returns empty string for empty object', () => {
    expect(toContent({})).toBe('');
  });

  it('returns output only', () => {
    expect(toContent({ output: 'result' })).toBe('result');
  });

  it('returns error prefixed with "Error: "', () => {
    expect(toContent({ error: 'fail' })).toBe('Error: fail');
  });

  it('returns system wrapped in tags', () => {
    expect(toContent({ system: 'info' })).toBe('<system>info</system>');
  });

  it('returns observation prefixed with "Screen: "', () => {
    expect(toContent({ observation: 'ui tree' })).toBe('Screen: ui tree');
  });

  it('error takes precedence over output', () => {
    expect(toContent({ output: 'ok', error: 'fail' })).toBe('Error: fail');
  });

  it('combines system + output', () => {
    expect(toContent({ system: 'info', output: 'data' })).toBe('<system>info</system>\ndata');
  });

  it('combines system + error', () => {
    expect(toContent({ system: 'info', error: 'fail' })).toBe('<system>info</system>\nError: fail');
  });

  it('combines output + observation', () => {
    expect(toContent({ output: 'data', observation: 'ui' })).toBe('data\nScreen: ui');
  });

  it('combines all fields with error taking precedence', () => {
    const result = toContent({ system: 'info', output: 'data', error: 'fail', observation: 'ui' });
    expect(result).toBe('<system>info</system>\nError: fail\nScreen: ui');
  });

  it('handles empty strings as falsy', () => {
    expect(toContent({ output: '', system: '', observation: '' })).toBe('');
  });

  it('handles only system field', () => {
    expect(toContent({ system: 'only' })).toBe('<system>only</system>');
  });
});
