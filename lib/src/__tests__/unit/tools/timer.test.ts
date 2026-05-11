import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { TimerTool } from '../../../tools/timer';

describe('TimerTool', () => {
  let timer: TimerTool;

  beforeEach(() => {
    timer = new TimerTool();
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2025-01-01T00:00:00Z'));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('has correct name', () => {
    expect(timer.name).toBe('timer');
  });

  describe('set', () => {
    it('sets a timer with seconds', async () => {
      const result = await timer.execute('{"action": "set", "seconds": 30}');
      expect(result.output).toBe('Timer "default" set for 30 seconds');
    });

    it('sets a timer with custom name', async () => {
      const result = await timer.execute('{"action": "set", "seconds": 60, "name": "alarm"}');
      expect(result.output).toBe('Timer "alarm" set for 60 seconds');
    });

    it('uses "default" as default name', async () => {
      const result = await timer.execute('{"action": "set", "seconds": 10}');
      expect(result.output).toContain('"default"');
    });

    it('rejects seconds <= 0', async () => {
      const result = await timer.execute('{"action": "set", "seconds": 0}');
      expect(result.error).toContain("'seconds' must be 1-300");
    });

    it('rejects seconds > 300', async () => {
      const result = await timer.execute('{"action": "set", "seconds": 301}');
      expect(result.error).toContain("'seconds' must be 1-300");
    });

    it('accepts seconds = 1 (boundary)', async () => {
      const result = await timer.execute('{"action": "set", "seconds": 1}');
      expect(result.output).toContain('1 seconds');
    });

    it('accepts seconds = 300 (boundary)', async () => {
      const result = await timer.execute('{"action": "set", "seconds": 300}');
      expect(result.output).toContain('300 seconds');
    });

    it('handles seconds as string', async () => {
      const result = await timer.execute('{"action": "set", "seconds": "30"}');
      expect(result.output).toContain('30 seconds');
    });

    it('handles missing seconds', async () => {
      const result = await timer.execute('{"action": "set"}');
      expect(result.error).toContain("'seconds' must be 1-300");
    });

    it('overwrites existing timer with same name', async () => {
      await timer.execute('{"action": "set", "seconds": 60, "name": "dup"}');
      const result = await timer.execute('{"action": "set", "seconds": 30, "name": "dup"}');
      expect(result.output).toContain('30 seconds');
    });
  });

  describe('check', () => {
    it('returns remaining seconds for active timer', async () => {
      await timer.execute('{"action": "set", "seconds": 60}');
      const result = await timer.execute('{"action": "check"}');
      expect(result.output).toContain('60 seconds remaining');
    });

    it('returns remaining after partial elapsed', async () => {
      await timer.execute('{"action": "set", "seconds": 60}');
      vi.advanceTimersByTime(30_000);
      const result = await timer.execute('{"action": "check"}');
      expect(result.output).toContain('30 seconds remaining');
    });

    it('detects expired timer', async () => {
      await timer.execute('{"action": "set", "seconds": 10}');
      vi.advanceTimersByTime(15_000);
      const result = await timer.execute('{"action": "check"}');
      expect(result.output).toContain('expired');
    });

    it('returns error for non-existent timer', async () => {
      const result = await timer.execute('{"action": "check", "name": "nonexistent"}');
      expect(result.error).toContain('No timer found');
    });

    it('checks timer by name', async () => {
      await timer.execute('{"action": "set", "seconds": 30, "name": "alarm"}');
      const result = await timer.execute('{"action": "check", "name": "alarm"}');
      expect(result.output).toContain('"alarm"');
    });
  });

  describe('cancel', () => {
    it('cancels an active timer', async () => {
      await timer.execute('{"action": "set", "seconds": 60}');
      const result = await timer.execute('{"action": "cancel"}');
      expect(result.output).toContain('Cancelled timer "default"');
    });

    it('returns error for non-existent timer', async () => {
      const result = await timer.execute('{"action": "cancel", "name": "nope"}');
      expect(result.error).toContain('No timer found');
    });

    it('timer is gone after cancel', async () => {
      await timer.execute('{"action": "set", "seconds": 60}');
      await timer.execute('{"action": "cancel"}');
      const result = await timer.execute('{"action": "check"}');
      expect(result.error).toContain('No timer found');
    });
  });

  describe('list', () => {
    it('returns no active timers when empty', async () => {
      const result = await timer.execute('{"action": "list"}');
      expect(result.output).toBe('No active timers');
    });

    it('lists active timers', async () => {
      await timer.execute('{"action": "set", "seconds": 60, "name": "a"}');
      await timer.execute('{"action": "set", "seconds": 30, "name": "b"}');
      const result = await timer.execute('{"action": "list"}');
      expect(result.output).toContain('- a:');
      expect(result.output).toContain('- b:');
      expect(result.output).toContain('60s total');
      expect(result.output).toContain('30s total');
    });

    it('cleans up expired timers in list', async () => {
      await timer.execute('{"action": "set", "seconds": 5, "name": "expired"}');
      await timer.execute('{"action": "set", "seconds": 60, "name": "active"}');
      vi.advanceTimersByTime(10_000);
      const result = await timer.execute('{"action": "list"}');
      expect(result.output).toContain('active');
      expect(result.output).not.toContain('expired');
    });
  });

  describe('action handling', () => {
    it('returns error for empty action', async () => {
      const result = await timer.execute('{"action": ""}');
      expect(result.error).toContain("'action' required");
    });

    it('returns error for unknown action', async () => {
      const result = await timer.execute('{"action": "unknown"}');
      expect(result.error).toContain("Unknown action 'unknown'");
    });

    it('returns error for missing action', async () => {
      const result = await timer.execute('{}');
      expect(result.error).toContain("'action' required");
    });

    it('returns error for invalid JSON', async () => {
      const result = await timer.execute('not json');
      expect(result.error).toBeDefined();
    });

    it('is case-insensitive for action', async () => {
      const result = await timer.execute('{"action": "SET", "seconds": 30}');
      expect(result.output).toContain('30 seconds');
    });
  });

  describe('multiple timers', () => {
    it('manages multiple timers independently', async () => {
      await timer.execute('{"action": "set", "seconds": 60, "name": "a"}');
      await timer.execute('{"action": "set", "seconds": 30, "name": "b"}');
      vi.advanceTimersByTime(40_000);
      const checkA = await timer.execute('{"action": "check", "name": "a"}');
      expect(checkA.output).toContain('20 seconds remaining');
      const checkB = await timer.execute('{"action": "check", "name": "b"}');
      expect(checkB.output).toContain('expired');
    });
  });

  describe('validate', () => {
    it('returns null for valid set', async () => {
      expect(await timer.validate('{"action": "set", "seconds": 60}')).toBeNull();
    });

    it('returns null for valid list', async () => {
      expect(await timer.validate('{"action": "list"}')).toBeNull();
    });

    it('returns error for empty action', async () => {
      expect(await timer.validate('{}')).toContain('not a valid action');
    });

    it('returns error for invalid action', async () => {
      expect(await timer.validate('{"action": "start"}')).toContain('not a valid action');
    });

    it('returns error for set without seconds', async () => {
      expect(await timer.validate('{"action": "set"}')).toBe("'seconds' must be 1-300");
    });

    it('returns error for set with seconds out of range', async () => {
      expect(await timer.validate('{"action": "set", "seconds": 500}')).toBe("'seconds' must be 1-300");
    });

    it('returns error for set with zero seconds', async () => {
      expect(await timer.validate('{"action": "set", "seconds": 0}')).toBe("'seconds' must be 1-300");
    });
  });
});
