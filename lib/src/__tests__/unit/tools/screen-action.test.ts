import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ScreenActionTool, _resetModuleCache } from '../../../tools/screen-action';

describe('ScreenActionTool', () => {
  const tool = new ScreenActionTool();

  it('has correct name', () => {
    expect(tool.name).toBe('screen_action');
  });

  describe('validate', () => {
    it('returns null for valid tap action with x and y', async () => {
      expect(await tool.validate('{"action": "tap", "x": 100, "y": 200}')).toBeNull();
    });

    it('returns null for valid type action with text', async () => {
      expect(await tool.validate('{"action": "type", "text": "hello"}')).toBeNull();
    });

    it('returns null for valid swipe action with all coords', async () => {
      expect(await tool.validate('{"action": "swipe", "startX": 0, "startY": 0, "endX": 100, "endY": 100}')).toBeNull();
    });

    it('returns null for valid global action with globalAction', async () => {
      expect(await tool.validate('{"action": "global", "globalAction": "back"}')).toBeNull();
    });

    it('returns null case-insensitive for actions', async () => {
      expect(await tool.validate('{"action": "TAP", "x": 1, "y": 2}')).toBeNull();
    });

    it('returns error for invalid action', async () => {
      expect(await tool.validate('{"action": "invalid"}')).toContain('not a valid action');
    });

    it('returns error for empty action', async () => {
      expect(await tool.validate('{}')).toContain('(empty)');
    });

    it('returns error for tap without x', async () => {
      expect(await tool.validate('{"action": "tap", "y": 200}')).toContain("'x' and 'y' required");
    });

    it('returns error for tap without y', async () => {
      expect(await tool.validate('{"action": "tap", "x": 100}')).toContain("'x' and 'y' required");
    });

    it('returns error for type without text', async () => {
      expect(await tool.validate('{"action": "type"}')).toContain("'text' required");
    });

    it('returns error for swipe without required coords', async () => {
      expect(await tool.validate('{"action": "swipe", "startX": 0, "startY": 0}')).toContain("'startX', 'startY', 'endX', 'endY' required");
    });

    it('returns error for global without globalAction', async () => {
      expect(await tool.validate('{"action": "global"}')).toContain("'globalAction' required");
    });
  });

  describe('execute', () => {
    const mockClient = {
      tap: vi.fn(),
      type: vi.fn(),
      swipe: vi.fn(),
      globalAction: vi.fn(),
      isAvailable: vi.fn(() => true),
      destroy: vi.fn(),
    };

    beforeEach(() => {
      _resetModuleCache();
      vi.resetModules();
      vi.doMock('@gyo-framework/screen-action', () => ({
        ScreenAction: vi.fn(() => mockClient),
      }));
      mockClient.tap.mockReset();
      mockClient.type.mockReset();
      mockClient.swipe.mockReset();
      mockClient.globalAction.mockReset();
      mockClient.isAvailable.mockReturnValue(true);
      mockClient.destroy.mockReset();
    });

    afterEach(() => {
      vi.restoreAllMocks();
    });

    it('returns error when bridge not available', async () => {
      _resetModuleCache();
      vi.doMock('@gyo-framework/screen-action', () => ({
        ScreenAction: vi.fn(() => ({
          isAvailable: () => false,
          destroy: vi.fn(),
        })),
      }));
      const { ScreenActionTool: FreshTool, _resetModuleCache: freshReset } = await import('../../../tools/screen-action');
      freshReset();
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "tap", "x": 1, "y": 2}');
      expect(result.error).toContain('not available');
    });

    it('taps successfully', async () => {
      mockClient.tap.mockResolvedValue(true);
      const { ScreenActionTool: FreshTool } = await import('../../../tools/screen-action');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "tap", "x": 100, "y": 200}');
      expect(result.output).toContain('Tapped at (100, 200)');
      expect(mockClient.tap).toHaveBeenCalledWith({ x: 100, y: 200 });
      expect(mockClient.destroy).toHaveBeenCalled();
    });

    it('handles tap failure', async () => {
      mockClient.tap.mockResolvedValue(false);
      const { ScreenActionTool: FreshTool } = await import('../../../tools/screen-action');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "tap", "x": 100, "y": 200}');
      expect(result.error).toContain('Failed to tap');
    });

    it('types text successfully', async () => {
      mockClient.type.mockResolvedValue(true);
      const { ScreenActionTool: FreshTool } = await import('../../../tools/screen-action');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "type", "text": "hello world"}');
      expect(result.output).toContain('Typed: "hello world"');
      expect(mockClient.type).toHaveBeenCalledWith({ text: 'hello world' });
      expect(mockClient.destroy).toHaveBeenCalled();
    });

    it('handles type failure', async () => {
      mockClient.type.mockResolvedValue(false);
      const { ScreenActionTool: FreshTool } = await import('../../../tools/screen-action');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "type", "text": "hello"}');
      expect(result.error).toContain('Failed to type');
    });

    it('swipes successfully', async () => {
      mockClient.swipe.mockResolvedValue(true);
      const { ScreenActionTool: FreshTool } = await import('../../../tools/screen-action');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "swipe", "startX": 0, "startY": 100, "endX": 0, "endY": 500, "duration": 500}');
      expect(result.output).toContain('Swiped from (0, 100) to (0, 500)');
      expect(mockClient.swipe).toHaveBeenCalledWith({ startX: 0, startY: 100, endX: 0, endY: 500, duration: 500 });
      expect(mockClient.destroy).toHaveBeenCalled();
    });

    it('defaults swipe duration to 300', async () => {
      mockClient.swipe.mockResolvedValue(true);
      const { ScreenActionTool: FreshTool } = await import('../../../tools/screen-action');
      const freshTool = new FreshTool();
      await freshTool.execute('{"action": "swipe", "startX": 0, "startY": 0, "endX": 100, "endY": 100}');
      expect(mockClient.swipe).toHaveBeenCalledWith({ startX: 0, startY: 0, endX: 100, endY: 100, duration: 300 });
    });

    it('handles swipe failure', async () => {
      mockClient.swipe.mockResolvedValue(false);
      const { ScreenActionTool: FreshTool } = await import('../../../tools/screen-action');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "swipe", "startX": 0, "startY": 0, "endX": 100, "endY": 100}');
      expect(result.error).toContain('Failed to swipe');
    });

    it('performs global action successfully', async () => {
      mockClient.globalAction.mockResolvedValue(true);
      const { ScreenActionTool: FreshTool } = await import('../../../tools/screen-action');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "global", "globalAction": "back"}');
      expect(result.output).toContain('Global action: back');
      expect(mockClient.globalAction).toHaveBeenCalledWith({ action: 'back' });
      expect(mockClient.destroy).toHaveBeenCalled();
    });

    it('handles global action failure', async () => {
      mockClient.globalAction.mockResolvedValue(false);
      const { ScreenActionTool: FreshTool } = await import('../../../tools/screen-action');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "global", "globalAction": "home"}');
      expect(result.error).toContain('Failed to perform global action');
    });

    it('returns error for unknown action', async () => {
      const { ScreenActionTool: FreshTool } = await import('../../../tools/screen-action');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "unknown"}');
      expect(result.error).toContain('Unknown action');
    });

    it('destroys client even on error', async () => {
      mockClient.tap.mockRejectedValue(new Error('bridge error'));
      const { ScreenActionTool: FreshTool } = await import('../../../tools/screen-action');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "tap", "x": 1, "y": 2}');
      expect(result.error).toContain('bridge error');
      expect(mockClient.destroy).toHaveBeenCalled();
    });
  });
});
