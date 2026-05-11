import { describe, it, expect } from 'vitest';
import { truncate } from '../../../agent/truncate';

describe('truncate', () => {
  it('returns text unchanged when shorter than maxLength', () => {
    expect(truncate('hello', 10)).toBe('hello');
  });

  it('returns text unchanged when equal to maxLength', () => {
    expect(truncate('hello', 5)).toBe('hello');
  });

  it('truncates and appends ... when longer', () => {
    expect(truncate('hello world', 5)).toBe('hello...');
  });

  it('handles empty string', () => {
    expect(truncate('', 10)).toBe('');
  });

  it('handles maxLength of 0', () => {
    expect(truncate('hello', 0)).toBe('...');
  });

  it('handles Korean multi-byte characters', () => {
    expect(truncate('안녕하세요', 3)).toBe('안녕하...');
  });

  it('truncates single character', () => {
    expect(truncate('abcdef', 1)).toBe('a...');
  });
});
