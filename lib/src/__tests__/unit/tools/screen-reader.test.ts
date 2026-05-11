import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ScreenReaderTool, _resetModuleCache } from '../../../tools/screen-reader';

describe('ScreenReaderTool', () => {
  const tool = new ScreenReaderTool();

  it('has correct name', () => {
    expect(tool.name).toBe('screen_reader');
  });

  describe('validate', () => {
    it('returns null for valid read action', async () => {
      expect(await tool.validate('{"action": "read"}')).toBeNull();
    });

    it('returns null for valid find action with text', async () => {
      expect(await tool.validate('{"action": "find", "text": "Submit"}')).toBeNull();
    });

    it('returns null case-insensitive for actions', async () => {
      expect(await tool.validate('{"action": "READ"}')).toBeNull();
    });

    it('returns error for invalid action', async () => {
      expect(await tool.validate('{"action": "invalid"}')).toContain('not a valid action');
    });

    it('returns error for empty action', async () => {
      expect(await tool.validate('{}')).toContain('(empty)');
    });

    it('returns error for find without text', async () => {
      expect(await tool.validate('{"action": "find"}')).toContain("'text' required");
    });
  });

  describe('execute', () => {
    const mockClient = {
      read: vi.fn(),
      find: vi.fn(),
      isAvailable: vi.fn(() => true),
      destroy: vi.fn(),
    };

    beforeEach(() => {
      _resetModuleCache();
      vi.resetModules();
      vi.doMock('@gyo-framework/screen-reader', () => ({
        ScreenReader: vi.fn(() => mockClient),
      }));
      mockClient.read.mockReset();
      mockClient.find.mockReset();
      mockClient.isAvailable.mockReturnValue(true);
      mockClient.destroy.mockReset();
    });

    afterEach(() => {
      vi.restoreAllMocks();
    });

    it('returns error when bridge not available', async () => {
      _resetModuleCache();
      vi.doMock('@gyo-framework/screen-reader', () => ({
        ScreenReader: vi.fn(() => ({
          isAvailable: () => false,
          destroy: vi.fn(),
        })),
      }));
      const { ScreenReaderTool: FreshTool, _resetModuleCache: freshReset } = await import('../../../tools/screen-reader');
      freshReset();
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "read"}');
      expect(result.error).toContain('not available');
    });

    it('reads screen successfully', async () => {
      mockClient.read.mockResolvedValue({
        packageName: 'com.example',
        windowName: 'MainActivity',
        root: {
          className: 'FrameLayout',
          bounds: '[0,0][1080,2340]',
          text: '',
          contentDescription: '',
          isClickable: false,
          isEditable: false,
          children: [
            {
              className: 'TextView',
              bounds: '[100,200][500,300]',
              text: 'Hello',
              contentDescription: '',
              isClickable: true,
              isEditable: false,
              children: [],
            },
          ],
        },
      });
      const { ScreenReaderTool: FreshTool } = await import('../../../tools/screen-reader');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "read"}');
      expect(result.output).toContain('com.example');
      expect(result.output).toContain('MainActivity');
      expect(result.output).toContain('FrameLayout');
      expect(result.output).toContain('Hello');
      expect(result.output).toContain('[clickable]');
      expect(mockClient.destroy).toHaveBeenCalled();
    });

    it('handles empty screen', async () => {
      mockClient.read.mockResolvedValue({
        packageName: 'com.example',
        windowName: 'MainActivity',
        root: null,
      });
      const { ScreenReaderTool: FreshTool } = await import('../../../tools/screen-reader');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "read"}');
      expect(result.output).toContain('Screen is empty');
    });

    it('finds nodes successfully', async () => {
      mockClient.find.mockResolvedValue({
        nodes: [
          { className: 'Button', text: 'Submit', contentDescription: '', bounds: '[100,200][300,280]', isClickable: true, isEditable: false },
          { className: 'Button', text: 'Submit All', contentDescription: '', bounds: '[100,300][300,380]', isClickable: true, isEditable: false },
        ],
        count: 2,
      });
      const { ScreenReaderTool: FreshTool } = await import('../../../tools/screen-reader');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "find", "text": "Submit"}');
      expect(result.output).toContain("2 elements matching 'Submit'");
      expect(result.output).toContain('Submit');
      expect(result.output).toContain('clickable');
      expect(mockClient.find).toHaveBeenCalledWith({ text: 'Submit' });
      expect(mockClient.destroy).toHaveBeenCalled();
    });

    it('handles no matching elements', async () => {
      mockClient.find.mockResolvedValue({ nodes: [], count: 0 });
      const { ScreenReaderTool: FreshTool } = await import('../../../tools/screen-reader');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "find", "text": "xyz"}');
      expect(result.output).toContain("No elements matching 'xyz'");
    });

    it('returns error for unknown action', async () => {
      const { ScreenReaderTool: FreshTool } = await import('../../../tools/screen-reader');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "unknown"}');
      expect(result.error).toContain('Unknown action');
    });

    it('destroys client even on error', async () => {
      mockClient.read.mockRejectedValue(new Error('bridge error'));
      const { ScreenReaderTool: FreshTool } = await import('../../../tools/screen-reader');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "read"}');
      expect(result.error).toContain('bridge error');
      expect(mockClient.destroy).toHaveBeenCalled();
    });
  });
});
