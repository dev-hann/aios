import { describe, it, expect } from 'vitest';
import { ErrorRecovery, ErrorType } from '../../../agent/error-recovery';
import { toolResultOk, toolResultErr } from '../../../types/agent';

describe('ErrorRecovery', () => {
  it('returns null for non-error result', () => {
    const er = new ErrorRecovery();
    const result = er.analyze('tool', '{}', toolResultOk('success'));
    expect(result).toBeNull();
  });

  it('returns null for non-error result with output', () => {
    const er = new ErrorRecovery();
    const result = er.analyze('tool', '{}', { output: 'data' });
    expect(result).toBeNull();
  });

  it('detects error from ToolResult.error', () => {
    const er = new ErrorRecovery();
    const result = er.analyze('tool', '{}', toolResultErr('something failed'));
    expect(result).not.toBeNull();
    expect(result!.type).toBe(ErrorType.Generic);
  });

  it('detects error from output starting with "Error:"', () => {
    const er = new ErrorRecovery();
    const result = er.analyze('tool', '{}', { output: 'Error: something failed' });
    expect(result).not.toBeNull();
    expect(result!.type).toBe(ErrorType.Generic);
  });

  describe('error categorization', () => {
    it('categorizes "unknown tool" as ToolNotFound', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('Unknown tool xyz'));
      expect(result!.type).toBe(ErrorType.ToolNotFound);
    });

    it('categorizes "not installed" as AppNotInstalled', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('App not installed'));
      expect(result!.type).toBe(ErrorType.AppNotInstalled);
    });

    it('categorizes "no apps found" as AppNotInstalled', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('No apps found'));
      expect(result!.type).toBe(ErrorType.AppNotInstalled);
    });

    it('categorizes accessibility not enabled as ServiceUnavailable', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('Accessibility service not enabled'));
      expect(result!.type).toBe(ErrorType.ServiceUnavailable);
    });

    it('does not categorize accessibility alone as ServiceUnavailable', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('Accessibility is running'));
      expect(result!.type).not.toBe(ErrorType.ServiceUnavailable);
    });

    it('categorizes "permission" as PermissionDenied', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('Permission not granted'));
      expect(result!.type).toBe(ErrorType.PermissionDenied);
    });

    it('categorizes "denied" as PermissionDenied', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('Access denied'));
      expect(result!.type).toBe(ErrorType.PermissionDenied);
    });

    it('categorizes "unknown action" as InvalidAction', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('Unknown action xyz'));
      expect(result!.type).toBe(ErrorType.InvalidAction);
    });

    it('categorizes "required" as MissingParameter', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr("'expression' required"));
      expect(result!.type).toBe(ErrorType.MissingParameter);
    });

    it('categorizes "cancelled by user" as Cancelled', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('Action cancelled by user'));
      expect(result!.type).toBe(ErrorType.Cancelled);
    });

    it('categorizes unmatched error as Generic', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('Something went wrong'));
      expect(result!.type).toBe(ErrorType.Generic);
    });

    it('first match wins for multiple patterns', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('Unknown tool permission denied'));
      expect(result!.type).toBe(ErrorType.ToolNotFound);
    });

    it('is case-insensitive', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('UNKNOWN TOOL'));
      expect(result!.type).toBe(ErrorType.ToolNotFound);
    });
  });

  describe('retry logic', () => {
    it('allows retry on first error for retryable types', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('Unknown action xyz'));
      expect(result!.shouldRetry).toBe(true);
    });

    it('denies retry on second error for same tool', () => {
      const er = new ErrorRecovery();
      er.analyze('tool', '{}', toolResultErr('Unknown action xyz'));
      const result = er.analyze('tool', '{}', toolResultErr('Unknown action abc'));
      expect(result!.shouldRetry).toBe(false);
    });

    it('allows different tools independently', () => {
      const er = new ErrorRecovery();
      er.analyze('tool_a', '{}', toolResultErr('fail'));
      const result = er.analyze('tool_b', '{}', toolResultErr('fail'));
      expect(result!.shouldRetry).toBe(true);
    });

    it('does not retry Cancelled errors', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('cancelled by user'));
      expect(result!.shouldRetry).toBe(false);
    });

    it('does not retry PermissionDenied errors', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('Permission denied'));
      expect(result!.shouldRetry).toBe(false);
    });

    it('does not retry ServiceUnavailable errors', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('Accessibility service not enabled'));
      expect(result!.shouldRetry).toBe(false);
    });

    it('retries Generic errors', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('Something went wrong'));
      expect(result!.shouldRetry).toBe(true);
    });

    it('retries MissingParameter errors', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr("'expression' required"));
      expect(result!.shouldRetry).toBe(true);
    });
  });

  describe('user messages', () => {
    it('returns Korean user message for each error type', () => {
      const er = new ErrorRecovery();
      const cases: Array<[string, ErrorType]> = [
        ['Unknown tool x', ErrorType.ToolNotFound],
        ['App not installed', ErrorType.AppNotInstalled],
        ['Accessibility not enabled', ErrorType.ServiceUnavailable],
        ['Permission denied', ErrorType.PermissionDenied],
        ['Unknown action x', ErrorType.InvalidAction],
        ["'x' required", ErrorType.MissingParameter],
        ['cancelled by user', ErrorType.Cancelled],
        ['generic error', ErrorType.Generic],
      ];
      for (const [msg, expectedType] of cases) {
        const result = er.analyze('tool', '{}', toolResultErr(msg));
        expect(result!.type).toBe(expectedType);
        expect(result!.userMessage).toBeTruthy();
      }
    });
  });

  describe('prompt nudges', () => {
    it('includes RECOVERY prefix in retry nudge', () => {
      const er = new ErrorRecovery();
      const result = er.analyze('tool', '{}', toolResultErr('Unknown action xyz'));
      expect(result!.promptNudge).toContain('RECOVERY:');
    });

    it('includes RECOVERY prefix in fallback nudge', () => {
      const er = new ErrorRecovery();
      er.analyze('tool', '{}', toolResultErr('Unknown action xyz'));
      const result = er.analyze('tool', '{}', toolResultErr('Unknown action abc'));
      expect(result!.promptNudge).toContain('RECOVERY:');
    });
  });

  describe('totalErrors tracking', () => {
    it('counts total errors across tools', () => {
      const er = new ErrorRecovery();
      expect(er.totalErrors).toBe(0);
      er.analyze('tool_a', '{}', toolResultErr('fail'));
      expect(er.totalErrors).toBe(1);
      er.analyze('tool_b', '{}', toolResultErr('fail'));
      expect(er.totalErrors).toBe(2);
    });

    it('does not count non-errors', () => {
      const er = new ErrorRecovery();
      er.analyze('tool', '{}', toolResultOk('success'));
      expect(er.totalErrors).toBe(0);
    });
  });

  describe('reset', () => {
    it('resets all state', () => {
      const er = new ErrorRecovery();
      er.analyze('tool', '{}', toolResultErr('fail'));
      er.analyze('tool', '{}', toolResultErr('fail'));
      er.reset();
      expect(er.totalErrors).toBe(0);
      expect(er.canRetry('tool')).toBe(true);
    });
  });

  describe('canRetry', () => {
    it('returns true for fresh tool', () => {
      const er = new ErrorRecovery();
      expect(er.canRetry('unknown_tool')).toBe(true);
    });

    it('returns false after maxRetries exhausted', () => {
      const er = new ErrorRecovery();
      er.analyze('tool', '{}', toolResultErr('Unknown action xyz'));
      expect(er.canRetry('tool')).toBe(false);
    });
  });
});
