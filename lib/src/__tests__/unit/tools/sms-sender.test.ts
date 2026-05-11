import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { SmsSenderTool, _resetModuleCache } from '../../../tools/sms-sender';

describe('SmsSenderTool', () => {
  const tool = new SmsSenderTool();

  it('has correct name', () => {
    expect(tool.name).toBe('sms_sender');
  });

  describe('validate', () => {
    it('returns null for valid send action', async () => {
      expect(await tool.validate('{"action": "send", "phoneNumber": "1234", "message": "hi"}')).toBeNull();
    });

    it('returns null for valid read action with limit', async () => {
      expect(await tool.validate('{"action": "read", "limit": 5}')).toBeNull();
    });

    it('returns null case-insensitive for actions', async () => {
      expect(await tool.validate('{"action": "SEND", "phoneNumber": "1234", "message": "hi"}')).toBeNull();
    });

    it('returns error for invalid action', async () => {
      expect(await tool.validate('{"action": "invalid"}')).toContain('not a valid action');
    });

    it('returns error for empty action', async () => {
      expect(await tool.validate('{}')).toContain('(empty)');
    });

    it('returns error for send without phoneNumber', async () => {
      expect(await tool.validate('{"action": "send", "message": "hi"}')).toContain("'phoneNumber' required");
    });

    it('returns error for send without message', async () => {
      expect(await tool.validate('{"action": "send", "phoneNumber": "1234"}')).toContain("'message' required");
    });

    it('returns error for read without limit', async () => {
      expect(await tool.validate('{"action": "read"}')).toContain("'limit' required");
    });
  });

  describe('execute', () => {
    const mockClient = {
      send: vi.fn(),
      read: vi.fn(),
      isAvailable: vi.fn(() => true),
      destroy: vi.fn(),
    };

    beforeEach(() => {
      _resetModuleCache();
      vi.resetModules();
      vi.doMock('@gyo-framework/sms-sender', () => ({
        SmsSender: vi.fn(() => mockClient),
      }));
      mockClient.send.mockReset();
      mockClient.read.mockReset();
      mockClient.isAvailable.mockReturnValue(true);
      mockClient.destroy.mockReset();
    });

    afterEach(() => {
      vi.restoreAllMocks();
    });

    it('returns error when bridge not available', async () => {
      _resetModuleCache();
      vi.doMock('@gyo-framework/sms-sender', () => ({
        SmsSender: vi.fn(() => ({
          isAvailable: () => false,
          destroy: vi.fn(),
        })),
      }));
      const { SmsSenderTool: FreshTool, _resetModuleCache: freshReset } = await import('../../../tools/sms-sender');
      freshReset();
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "send", "phoneNumber": "1234", "message": "hi"}');
      expect(result.error).toContain('not available');
    });

    it('sends SMS successfully', async () => {
      mockClient.send.mockResolvedValue(true);
      const { SmsSenderTool: FreshTool } = await import('../../../tools/sms-sender');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "send", "phoneNumber": "123-456-7890", "message": "Hello!"}');
      expect(result.output).toContain('SMS sent to 123-456-7890');
      expect(mockClient.send).toHaveBeenCalledWith({ phoneNumber: '123-456-7890', message: 'Hello!' });
      expect(mockClient.destroy).toHaveBeenCalled();
    });

    it('handles send failure', async () => {
      mockClient.send.mockResolvedValue(false);
      const { SmsSenderTool: FreshTool } = await import('../../../tools/sms-sender');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "send", "phoneNumber": "1234", "message": "hi"}');
      expect(result.error).toContain('Failed to send SMS');
    });

    it('reads SMS messages successfully', async () => {
      mockClient.read.mockResolvedValue({
        messages: [
          { type: 'inbox', address: '123-456-7890', body: 'Hey there', date: 1700000000000 },
          { type: 'sent', address: '098-765-4321', body: 'Reply', date: 1700000100000 },
        ],
        count: 2,
      });
      const { SmsSenderTool: FreshTool } = await import('../../../tools/sms-sender');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "read", "limit": 10}');
      expect(result.output).toContain('2 SMS messages');
      expect(result.output).toContain('inbox');
      expect(result.output).toContain('123-456-7890');
      expect(result.output).toContain('Hey there');
      expect(mockClient.read).toHaveBeenCalledWith({ limit: 10 });
      expect(mockClient.destroy).toHaveBeenCalled();
    });

    it('handles no SMS messages', async () => {
      mockClient.read.mockResolvedValue({ messages: [], count: 0 });
      const { SmsSenderTool: FreshTool } = await import('../../../tools/sms-sender');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "read", "limit": 5}');
      expect(result.output).toContain('No SMS messages found');
    });

    it('defaults limit to 10 when not provided', async () => {
      mockClient.read.mockResolvedValue({ messages: [], count: 0 });
      const { SmsSenderTool: FreshTool } = await import('../../../tools/sms-sender');
      const freshTool = new FreshTool();
      await freshTool.execute('{"action": "read", "limit": 0}');
      expect(mockClient.read).toHaveBeenCalledWith({ limit: 10 });
    });

    it('returns error for unknown action', async () => {
      const { SmsSenderTool: FreshTool } = await import('../../../tools/sms-sender');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "unknown"}');
      expect(result.error).toContain('Unknown action');
    });

    it('destroys client even on error', async () => {
      mockClient.send.mockRejectedValue(new Error('bridge error'));
      const { SmsSenderTool: FreshTool } = await import('../../../tools/sms-sender');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "send", "phoneNumber": "1234", "message": "hi"}');
      expect(result.error).toContain('bridge error');
      expect(mockClient.destroy).toHaveBeenCalled();
    });
  });
});
