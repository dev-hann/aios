import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { PhoneCallerTool, _resetModuleCache } from '../../../tools/phone-caller';

describe('PhoneCallerTool', () => {
  const tool = new PhoneCallerTool();

  it('has correct name', () => {
    expect(tool.name).toBe('phone_caller');
  });

  describe('validate', () => {
    it('returns null for valid call action with phoneNumber', async () => {
      expect(await tool.validate('{"action": "call", "phoneNumber": "123-456-7890"}')).toBeNull();
    });

    it('returns null for valid get_call_log action with limit', async () => {
      expect(await tool.validate('{"action": "get_call_log", "limit": 5}')).toBeNull();
    });

    it('returns null case-insensitive for actions', async () => {
      expect(await tool.validate('{"action": "CALL", "phoneNumber": "1234"}')).toBeNull();
    });

    it('returns error for invalid action', async () => {
      expect(await tool.validate('{"action": "invalid"}')).toContain('not a valid action');
    });

    it('returns error for empty action', async () => {
      expect(await tool.validate('{}')).toContain('(empty)');
    });

    it('returns error for call without phoneNumber', async () => {
      expect(await tool.validate('{"action": "call"}')).toContain("'phoneNumber' required");
    });

    it('returns error for get_call_log without limit', async () => {
      expect(await tool.validate('{"action": "get_call_log"}')).toContain("'limit' required");
    });
  });

  describe('execute', () => {
    const mockClient = {
      call: vi.fn(),
      getCallLog: vi.fn(),
      isAvailable: vi.fn(() => true),
      destroy: vi.fn(),
    };

    beforeEach(() => {
      _resetModuleCache();
      vi.resetModules();
      vi.doMock('@gyo-framework/phone-caller', () => ({
        PhoneCaller: vi.fn(() => mockClient),
      }));
      mockClient.call.mockReset();
      mockClient.getCallLog.mockReset();
      mockClient.isAvailable.mockReturnValue(true);
      mockClient.destroy.mockReset();
    });

    afterEach(() => {
      vi.restoreAllMocks();
    });

    it('returns error when bridge not available', async () => {
      _resetModuleCache();
      vi.doMock('@gyo-framework/phone-caller', () => ({
        PhoneCaller: vi.fn(() => ({
          isAvailable: () => false,
          destroy: vi.fn(),
        })),
      }));
      const { PhoneCallerTool: FreshTool, _resetModuleCache: freshReset } = await import('../../../tools/phone-caller');
      freshReset();
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "call", "phoneNumber": "1234"}');
      expect(result.error).toContain('not available');
    });

    it('calls successfully', async () => {
      mockClient.call.mockResolvedValue(true);
      const { PhoneCallerTool: FreshTool } = await import('../../../tools/phone-caller');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "call", "phoneNumber": "123-456-7890"}');
      expect(result.output).toContain('Calling 123-456-7890');
      expect(mockClient.call).toHaveBeenCalledWith({ phoneNumber: '123-456-7890' });
      expect(mockClient.destroy).toHaveBeenCalled();
    });

    it('handles call failure', async () => {
      mockClient.call.mockResolvedValue(false);
      const { PhoneCallerTool: FreshTool } = await import('../../../tools/phone-caller');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "call", "phoneNumber": "1234"}');
      expect(result.error).toContain('Failed to call');
    });

    it('gets call log successfully', async () => {
      mockClient.getCallLog.mockResolvedValue({
        entries: [
          { type: 'incoming', name: 'John', number: '123-456-7890', duration: 125, date: 1700000000000 },
          { type: 'outgoing', name: '', number: '098-765-4321', duration: 60, date: 1700000100000 },
        ],
        count: 2,
      });
      const { PhoneCallerTool: FreshTool } = await import('../../../tools/phone-caller');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "get_call_log", "limit": 10}');
      expect(result.output).toContain('2 call log entries');
      expect(result.output).toContain('incoming');
      expect(result.output).toContain('John');
      expect(result.output).toContain('2m 5s');
      expect(result.output).toContain('098-765-4321');
      expect(mockClient.getCallLog).toHaveBeenCalledWith({ limit: 10 });
      expect(mockClient.destroy).toHaveBeenCalled();
    });

    it('handles no call log entries', async () => {
      mockClient.getCallLog.mockResolvedValue({ entries: [], count: 0 });
      const { PhoneCallerTool: FreshTool } = await import('../../../tools/phone-caller');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "get_call_log", "limit": 5}');
      expect(result.output).toContain('No call log entries found');
    });

    it('defaults limit to 10 when not provided', async () => {
      mockClient.getCallLog.mockResolvedValue({ entries: [], count: 0 });
      const { PhoneCallerTool: FreshTool } = await import('../../../tools/phone-caller');
      const freshTool = new FreshTool();
      await freshTool.execute('{"action": "get_call_log", "limit": 0}');
      expect(mockClient.getCallLog).toHaveBeenCalledWith({ limit: 10 });
    });

    it('returns error for unknown action', async () => {
      const { PhoneCallerTool: FreshTool } = await import('../../../tools/phone-caller');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "unknown"}');
      expect(result.error).toContain('Unknown action');
    });

    it('destroys client even on error', async () => {
      mockClient.call.mockRejectedValue(new Error('bridge error'));
      const { PhoneCallerTool: FreshTool } = await import('../../../tools/phone-caller');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "call", "phoneNumber": "1234"}');
      expect(result.error).toContain('bridge error');
      expect(mockClient.destroy).toHaveBeenCalled();
    });
  });
});
