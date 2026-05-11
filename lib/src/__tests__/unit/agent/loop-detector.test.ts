import { describe, it, expect } from 'vitest';
import { LoopDetector } from '../../../agent/loop-detector';
import { toolResultOk, toolResultErr } from '../../../types/agent';

describe('LoopDetector', () => {
  it('returns ok for first record', () => {
    const detector = new LoopDetector();
    const result = detector.record('calculator', '{"expression": "2+3"}', toolResultOk('5'));
    expect(result.type).toBe('ok');
  });

  it('returns ok for two identical actions with different observations', () => {
    const detector = new LoopDetector();
    detector.record('calculator', '{"expression": "2+3"}', toolResultOk('5.0000'));
    const result = detector.record('calculator', '{"expression": "2+3"}', toolResultOk('6.0000'));
    expect(result.type).toBe('ok');
  });

  it('returns warning on 2nd identical observation (same tool, same args)', () => {
    const detector = new LoopDetector();
    detector.record('calculator', '{}', toolResultOk('same'));
    const result = detector.record('calculator', '{}', toolResultOk('same'));
    expect(result.type).toBe('warning');
  });

  it('returns forceBreak on 3rd when warningGiven and identical observations', () => {
    const detector = new LoopDetector();
    detector.record('calculator', '{}', toolResultOk('same'));
    detector.record('calculator', '{}', toolResultOk('same'));
    const result = detector.record('calculator', '{}', toolResultOk('same'));
    expect(result.type).toBe('forceBreak');
  });

  it('returns ok for two identical actions with different observations', () => {
    const detector = new LoopDetector();
    detector.record('calculator', '{}', toolResultOk('r1'));
    detector.record('calculator', '{}', toolResultOk('r2'));
    expect(detector.record('calculator', '{}', toolResultOk('r3')).type).toBe('warning');
  });

  it('scroll override blocks isRepeatedAction but NOT consecutiveIdenticalObs', () => {
    const detector = new LoopDetector();
    const r1 = detector.record('screen_action', '{"action": "scroll"}', toolResultOk('same'));
    expect(r1.type).toBe('ok');
    const r2 = detector.record('screen_action', '{"action": "scroll"}', toolResultOk('same'));
    expect(r2.type).toBe('warning');
    const r3 = detector.record('screen_action', '{"action": "scroll"}', toolResultOk('same'));
    expect(r3.type).toBe('forceBreak');
  });

  it('scroll with different observations is always ok', () => {
    const detector = new LoopDetector();
    for (let i = 0; i < 5; i++) {
      const result = detector.record('screen_action', '{"action": "scroll"}', toolResultOk(`result_${i}`));
      expect(result.type).toBe('ok');
    }
  });

  it('swipe with different observations is always ok', () => {
    const detector = new LoopDetector();
    for (let i = 0; i < 5; i++) {
      const result = detector.record('screen_action', '{"action": "swipe"}', toolResultOk(`result_${i}`));
      expect(result.type).toBe('ok');
    }
  });

  it('global with different observations is always ok', () => {
    const detector = new LoopDetector();
    for (let i = 0; i < 5; i++) {
      const result = detector.record('screen_action', '{"action": "global"}', toolResultOk(`result_${i}`));
      expect(result.type).toBe('ok');
    }
  });

  it('canonicalizes args with different key order as same', () => {
    const detector = new LoopDetector();
    detector.record('tool', '{"a": 1, "b": 2}', toolResultOk('same'));
    detector.record('tool', '{"b": 2, "a": 1}', toolResultOk('same'));
    const result = detector.record('tool', '{"a": 1, "b": 2}', toolResultOk('same'));
    expect(result.type).toBe('forceBreak');
  });

  it('canonicalizes args with different observations avoids false positive', () => {
    const detector = new LoopDetector();
    detector.record('tool', '{"a": 1, "b": 2}', toolResultOk('r1'));
    const result = detector.record('tool', '{"b": 2, "a": 1}', toolResultOk('r2'));
    expect(result.type).toBe('ok');
  });

  it('detects loop from identical consecutive observations with different tools', () => {
    const detector = new LoopDetector();
    detector.record('tool_a', '{"x": 1}', toolResultOk('same result'));
    const result = detector.record('tool_b', '{"x": 2}', toolResultOk('same result'));
    expect(result.type).toBe('warning');
  });

  it('does not warn for different observations', () => {
    const detector = new LoopDetector();
    detector.record('tool_a', '{"x": 1}', toolResultOk('result 1'));
    const result = detector.record('tool_b', '{"x": 2}', toolResultOk('result 2'));
    expect(result.type).toBe('ok');
  });

  it('handles invalid JSON args', () => {
    const detector = new LoopDetector();
    const result = detector.record('tool', 'not json', toolResultOk('ok'));
    expect(result.type).toBe('ok');
  });

  it('resets all state', () => {
    const detector = new LoopDetector();
    for (let i = 0; i < 3; i++) detector.record('calculator', '{}', toolResultOk('same'));
    expect(detector.record('calculator', '{}', toolResultOk('same')).type).not.toBe('ok');
    detector.reset();
    const result = detector.record('calculator', '{}', toolResultOk('ok'));
    expect(result.type).toBe('ok');
  });

  it('handles different tools without triggering loop', () => {
    const detector = new LoopDetector();
    detector.record('calculator', '{}', toolResultOk('1'));
    detector.record('notepad', '{}', toolResultOk('2'));
    detector.record('timer', '{}', toolResultOk('3'));
    const result = detector.record('calculator', '{}', toolResultOk('4'));
    expect(result.type).toBe('ok');
  });

  it('handles error results in observations', () => {
    const detector = new LoopDetector();
    detector.record('tool', '{}', toolResultErr('same error'));
    const result = detector.record('tool', '{}', toolResultErr('same error'));
    expect(result.type).toBe('warning');
  });

  it('handles empty args string', () => {
    const detector = new LoopDetector();
    const result = detector.record('tool', '', toolResultOk('ok'));
    expect(result.type).toBe('ok');
  });
});
