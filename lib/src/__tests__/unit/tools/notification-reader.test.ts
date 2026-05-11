import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { NotificationReaderTool, _resetModuleCache } from '../../../tools/notification-reader';

describe('NotificationReaderTool', () => {
  const tool = new NotificationReaderTool();

  it('has correct name', () => {
    expect(tool.name).toBe('notification_reader');
  });

  describe('validate', () => {
    it('returns null for valid list action', async () => {
      expect(await tool.validate('{"action": "list"}')).toBeNull();
    });

    it('returns null for list case-insensitive', async () => {
      expect(await tool.validate('{"action": "LIST"}')).toBeNull();
    });

    it('returns error for invalid action', async () => {
      expect(await tool.validate('{"action": "invalid"}')).toContain('not a valid action');
    });

    it('returns error for empty action', async () => {
      expect(await tool.validate('{}')).toContain('(empty)');
    });
  });

  describe('execute', () => {
    const mockClient = {
      list: vi.fn(),
      isAvailable: vi.fn(() => true),
      destroy: vi.fn(),
    };

    beforeEach(() => {
      _resetModuleCache();
      vi.resetModules();
      vi.doMock('@gyo-framework/notification-reader', () => ({
        NotificationReader: vi.fn(() => mockClient),
      }));
      mockClient.list.mockReset();
      mockClient.isAvailable.mockReturnValue(true);
      mockClient.destroy.mockReset();
    });

    afterEach(() => {
      vi.restoreAllMocks();
    });

    it('returns error when bridge not available', async () => {
      _resetModuleCache();
      vi.doMock('@gyo-framework/notification-reader', () => ({
        NotificationReader: vi.fn(() => ({
          isAvailable: () => false,
          destroy: vi.fn(),
        })),
      }));
      const { NotificationReaderTool: FreshTool, _resetModuleCache: freshReset } = await import('../../../tools/notification-reader');
      freshReset();
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "list"}');
      expect(result.error).toContain('not available');
    });

    it('lists notifications successfully', async () => {
      mockClient.list.mockResolvedValue({
        notifications: [
          { packageName: 'com.whatsapp', title: 'John', text: 'Hello!', postTime: 1700000000000 },
          { packageName: 'com.gmail', title: 'New email', text: 'Meeting tomorrow', postTime: 1700000100000 },
        ],
        count: 2,
      });
      const { NotificationReaderTool: FreshTool } = await import('../../../tools/notification-reader');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "list"}');
      expect(result.output).toContain('2 notifications');
      expect(result.output).toContain('com.whatsapp');
      expect(result.output).toContain('John');
      expect(result.output).toContain('Hello!');
      expect(result.output).toContain('com.gmail');
      expect(mockClient.destroy).toHaveBeenCalled();
    });

    it('handles no notifications', async () => {
      mockClient.list.mockResolvedValue({ notifications: [], count: 0 });
      const { NotificationReaderTool: FreshTool } = await import('../../../tools/notification-reader');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "list"}');
      expect(result.output).toContain('No active notifications');
    });

    it('returns error for unknown action', async () => {
      const { NotificationReaderTool: FreshTool } = await import('../../../tools/notification-reader');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "unknown"}');
      expect(result.error).toContain('Unknown action');
    });

    it('destroys client even on error', async () => {
      mockClient.list.mockRejectedValue(new Error('bridge error'));
      const { NotificationReaderTool: FreshTool } = await import('../../../tools/notification-reader');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "list"}');
      expect(result.error).toContain('bridge error');
      expect(mockClient.destroy).toHaveBeenCalled();
    });
  });
});
