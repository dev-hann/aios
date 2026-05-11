import { describe, it, expect } from 'vitest';
import { inferToolArgs } from '../../../agent/tool-arg-inference';

describe('inferToolArgs', () => {
  describe('calculator - inline expressions', () => {
    it('infers simple addition', () => {
      expect(inferToolArgs('calculator', '2+3')).toEqual({ expression: '2+3' });
    });

    it('infers subtraction', () => {
      expect(inferToolArgs('calculator', '10-4')).toEqual({ expression: '10-4' });
    });

    it('infers multiplication with *', () => {
      expect(inferToolArgs('calculator', '3*7')).toEqual({ expression: '3*7' });
    });

    it('infers division with /', () => {
      expect(inferToolArgs('calculator', '10/2')).toEqual({ expression: '10/2' });
    });

    it('converts x to *', () => {
      expect(inferToolArgs('calculator', '3x5')).toEqual({ expression: '3*5' });
    });

    it('converts X to *', () => {
      expect(inferToolArgs('calculator', '3X5')).toEqual({ expression: '3*5' });
    });

    it('converts ÷ to /', () => {
      expect(inferToolArgs('calculator', '10÷2')).toEqual({ expression: '10/2' });
    });

    it('handles spaces around operators', () => {
      expect(inferToolArgs('calculator', '2 + 3')).toEqual({ expression: '2 + 3' });
    });

    it('handles decimal numbers', () => {
      expect(inferToolArgs('calculator', '3.14/2')).toEqual({ expression: '3.14/2' });
    });
  });

  describe('calculator - word operators', () => {
    it('infers Korean 더하기', () => {
      expect(inferToolArgs('calculator', '2 더하기 3')).toEqual({ expression: '2+3' });
    });

    it('infers Korean 빼기', () => {
      expect(inferToolArgs('calculator', '10 빼기 4')).toEqual({ expression: '10-4' });
    });

    it('infers Korean 곱하기', () => {
      expect(inferToolArgs('calculator', '3 곱하기 7')).toEqual({ expression: '3*7' });
    });

    it('infers Korean 나누기', () => {
      expect(inferToolArgs('calculator', '10 나누기 2')).toEqual({ expression: '10/2' });
    });

    it('infers English plus', () => {
      expect(inferToolArgs('calculator', '2 plus 3')).toEqual({ expression: '2+3' });
    });

    it('infers English minus', () => {
      expect(inferToolArgs('calculator', '10 minus 4')).toEqual({ expression: '10-4' });
    });

    it('infers English times', () => {
      expect(inferToolArgs('calculator', '3 times 7')).toEqual({ expression: '3*7' });
    });

    it('infers English divided', () => {
      expect(inferToolArgs('calculator', '10 divided 2')).toEqual({ expression: '10/2' });
    });
  });

  describe('calculator - no match', () => {
    it('returns null for non-math message', () => {
      expect(inferToolArgs('calculator', 'hello world')).toBeNull();
    });

    it('returns null for empty string', () => {
      expect(inferToolArgs('calculator', '')).toBeNull();
    });
  });

  describe('notepad', () => {
    it('infers Korean 메모', () => {
      expect(inferToolArgs('notepad', '메모 buy milk')).toEqual({
        action: 'save',
        key: 'memo',
        value: 'buy milk',
      });
    });

    it('infers Korean 기록', () => {
      expect(inferToolArgs('notepad', '기록 some content')).toEqual({
        action: 'save',
        key: 'memo',
        value: 'some content',
      });
    });

    it('infers Korean 저장', () => {
      expect(inferToolArgs('notepad', '저장 important data')).toEqual({
        action: 'save',
        key: 'memo',
        value: 'important data',
      });
    });

    it('infers English memo', () => {
      expect(inferToolArgs('notepad', 'memo: buy eggs')).toEqual({
        action: 'save',
        key: 'memo',
        value: 'buy eggs',
      });
    });

    it('infers English note', () => {
      expect(inferToolArgs('notepad', 'note remember this')).toEqual({
        action: 'save',
        key: 'memo',
        value: 'remember this',
      });
    });

    it('infers English save', () => {
      expect(inferToolArgs('notepad', 'save my data')).toEqual({
        action: 'save',
        key: 'memo',
        value: 'my data',
      });
    });

    it('returns null for non-memo message', () => {
      expect(inferToolArgs('notepad', 'hello world')).toBeNull();
    });
  });

  describe('timer', () => {
    it('infers minutes', () => {
      expect(inferToolArgs('timer', '5분 알람')).toEqual({ action: 'set', seconds: 300 });
    });

    it('infers seconds', () => {
      expect(inferToolArgs('timer', '30초 타이머')).toEqual({ action: 'set', seconds: 30 });
    });

    it('infers single minute', () => {
      expect(inferToolArgs('timer', '1분')).toEqual({ action: 'set', seconds: 60 });
    });

    it('returns null for non-timer message', () => {
      expect(inferToolArgs('timer', 'hello')).toBeNull();
    });
  });

  describe('unknown tool', () => {
    it('returns null for unknown tool name', () => {
      expect(inferToolArgs('unknown_tool', 'do something')).toBeNull();
    });

    it('returns null for empty tool name', () => {
      expect(inferToolArgs('', 'anything')).toBeNull();
    });
  });
});
