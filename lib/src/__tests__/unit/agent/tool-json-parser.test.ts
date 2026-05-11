import { describe, it, expect } from 'vitest';
import { tryParseToolJson, parseIntDynamic } from '../../../agent/tool-json-parser';

describe('tryParseToolJson', () => {
  it('parses valid JSON object', () => {
    expect(tryParseToolJson('{"a": 1, "b": "test"}')).toEqual({ a: 1, b: 'test' });
  });

  it('parses nested JSON object', () => {
    expect(tryParseToolJson('{"action": "set", "data": {"x": 1}}')).toEqual({
      action: 'set',
      data: { x: 1 },
    });
  });

  it('returns empty object for JSON array', () => {
    expect(tryParseToolJson('[1,2,3]')).toEqual({});
  });

  it('returns empty object for JSON null', () => {
    expect(tryParseToolJson('null')).toEqual({});
  });

  it('returns empty object for JSON number', () => {
    expect(tryParseToolJson('42')).toEqual({});
  });

  it('returns empty object for JSON boolean', () => {
    expect(tryParseToolJson('true')).toEqual({});
  });

  it('returns empty object for JSON string', () => {
    expect(tryParseToolJson('"hello"')).toEqual({});
  });

  it('returns empty object for invalid JSON', () => {
    expect(tryParseToolJson('not json')).toEqual({});
  });

  it('returns empty object for empty string', () => {
    expect(tryParseToolJson('')).toEqual({});
  });

  it('parses object with empty string values', () => {
    expect(tryParseToolJson('{"key": ""}')).toEqual({ key: '' });
  });

  it('parses object with null value', () => {
    expect(tryParseToolJson('{"key": null}')).toEqual({ key: null });
  });

  it('parses object with boolean value', () => {
    expect(tryParseToolJson('{"flag": true}')).toEqual({ flag: true });
  });
});

describe('parseIntDynamic', () => {
  it('returns number directly for number input', () => {
    expect(parseIntDynamic(42)).toBe(42);
  });

  it('returns float as-is for number input', () => {
    expect(parseIntDynamic(3.14)).toBe(3.14);
  });

  it('parses valid integer string', () => {
    expect(parseIntDynamic('42')).toBe(42);
  });

  it('parses float string with parseInt truncation', () => {
    expect(parseIntDynamic('3.14')).toBe(3);
  });

  it('returns null for non-numeric string', () => {
    expect(parseIntDynamic('abc')).toBeNull();
  });

  it('returns null for empty string', () => {
    expect(parseIntDynamic('')).toBeNull();
  });

  it('returns null for null input', () => {
    expect(parseIntDynamic(null)).toBeNull();
  });

  it('returns null for undefined input', () => {
    expect(parseIntDynamic(undefined)).toBeNull();
  });

  it('returns null for boolean input', () => {
    expect(parseIntDynamic(true as any)).toBeNull();
  });

  it('returns null for object input', () => {
    expect(parseIntDynamic({} as any)).toBeNull();
  });

  it('parses string with leading zeros', () => {
    expect(parseIntDynamic('007')).toBe(7);
  });

  it('parses negative number string', () => {
    expect(parseIntDynamic('-5')).toBe(-5);
  });

  it('parses zero', () => {
    expect(parseIntDynamic(0)).toBe(0);
  });

  it('parses "0" string', () => {
    expect(parseIntDynamic('0')).toBe(0);
  });
});
