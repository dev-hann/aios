import { describe, it, expect } from 'vitest';
import { CalculatorTool } from '../../../tools/calculator';

describe('CalculatorTool', () => {
  const calc = new CalculatorTool();

  it('has correct name', () => {
    expect(calc.name).toBe('calculator');
  });

  describe('basic arithmetic', () => {
    it('adds two numbers', async () => {
      const result = await calc.execute('{"expression": "2+3"}');
      expect(result.output).toBe('5.0000');
    });

    it('subtracts two numbers', async () => {
      const result = await calc.execute('{"expression": "10-4"}');
      expect(result.output).toBe('6.0000');
    });

    it('multiplies two numbers', async () => {
      const result = await calc.execute('{"expression": "3*7"}');
      expect(result.output).toBe('21.0000');
    });

    it('divides two numbers', async () => {
      const result = await calc.execute('{"expression": "10/3"}');
      expect(result.output).toBe('3.3333');
    });

    it('handles division by zero', async () => {
      const result = await calc.execute('{"expression": "1/0"}');
      expect(result.output).toBe('Infinity');
    });
  });

  describe('operator precedence', () => {
    it('respects multiplication precedence', async () => {
      const result = await calc.execute('{"expression": "2+3*4"}');
      expect(result.output).toBe('14.0000');
    });

    it('respects division precedence', async () => {
      const result = await calc.execute('{"expression": "10-6/2"}');
      expect(result.output).toBe('7.0000');
    });
  });

  describe('parentheses', () => {
    it('evaluates parentheses first', async () => {
      const result = await calc.execute('{"expression": "(2+3)*4"}');
      expect(result.output).toBe('20.0000');
    });

    it('handles nested parentheses', async () => {
      const result = await calc.execute('{"expression": "((2+3)*2)+1"}');
      expect(result.output).toBe('11.0000');
    });
  });

  describe('decimal numbers', () => {
    it('handles decimal input', async () => {
      const result = await calc.execute('{"expression": "3.14+1"}');
      expect(result.output).toBe('4.1400');
    });

    it('handles decimal result', async () => {
      const result = await calc.execute('{"expression": "1/8"}');
      expect(result.output).toBe('0.1250');
    });
  });

  describe('expression with spaces', () => {
    it('handles spaces in expression', async () => {
      const result = await calc.execute('{"expression": " 2 + 3 "}');
      expect(result.output).toBe('5.0000');
    });
  });

  describe('sanitization', () => {
    it('strips invalid characters', async () => {
      const result = await calc.execute('{"expression": "2+abc3"}');
      expect(result.output).toBe('5.0000');
    });

    it('strips letters from expression', async () => {
      const result = await calc.execute('{"expression": "hello2world+3test"}');
      expect(result.output).toBe('5.0000');
    });
  });

  describe('error handling', () => {
    it('returns error for empty expression', async () => {
      const result = await calc.execute('{"expression": ""}');
      expect(result.error).toContain("'expression' required");
    });

    it('returns error for missing expression field', async () => {
      const result = await calc.execute('{}');
      expect(result.error).toContain("'expression' required");
    });

    it('returns error for invalid JSON', async () => {
      const result = await calc.execute('not json');
      expect(result.error).toBeDefined();
    });

    it('returns error for expression that becomes empty after sanitize', async () => {
      const result = await calc.execute('{"expression": "abc"}');
      expect(result.error).toContain("'expression' required");
    });
  });

  describe('edge cases', () => {
    it('handles single number', async () => {
      const result = await calc.execute('{"expression": "42"}');
      expect(result.output).toBe('42.0000');
    });

    it('handles zero', async () => {
      const result = await calc.execute('{"expression": "0+0"}');
      expect(result.output).toBe('0.0000');
    });

    it('handles large numbers', async () => {
      const result = await calc.execute('{"expression": "999999*999999"}');
      expect(result.output).toBe('999998000001.0000');
    });

    it('handles consecutive operations', async () => {
      const result = await calc.execute('{"expression": "1+2+3+4"}');
      expect(result.output).toBe('10.0000');
    });
  });

  describe('validate', () => {
    it('returns null for valid expression', async () => {
      expect(await calc.validate('{"expression": "2+3"}')).toBeNull();
    });

    it('returns error for missing expression', async () => {
      expect(await calc.validate('{}')).toBe("'expression' required");
    });

    it('returns error for empty expression', async () => {
      expect(await calc.validate('{"expression": ""}')).toBe("'expression' required");
    });

    it('returns error for expression with only special chars', async () => {
      expect(await calc.validate('{"expression": "abc"}')).toBe("'expression' must contain valid math operators");
    });

    it('returns null for expression with spaces and numbers', async () => {
      expect(await calc.validate('{"expression": "1 + 2"}')).toBeNull();
    });
  });
});
