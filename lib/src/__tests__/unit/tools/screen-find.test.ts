import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ScreenFindTool, _resetModuleCache } from '../../../tools/screen-find';

describe('ScreenFindTool', () => {
  const tool = new ScreenFindTool();

  it('has correct name', () => {
    expect(tool.name).toBe('screen_find');
  });

  describe('validate', () => {
    it('returns null for valid find_by_text action with text', async () => {
      expect(await tool.validate('{"action": "find_by_text", "text": "Submit"}')).toBeNull();
    });

    it('returns null for valid find_by_id action with id', async () => {
      expect(await tool.validate('{"action": "find_by_id", "id": "com.example:id/button"}')).toBeNull();
    });

    it('returns null case-insensitive for actions', async () => {
      expect(await tool.validate('{"action": "FIND_BY_TEXT", "text": "test"}')).toBeNull();
    });

    it('returns error for invalid action', async () => {
      expect(await tool.validate('{"action": "invalid"}')).toContain('not a valid action');
    });

    it('returns error for empty action', async () => {
      expect(await tool.validate('{}')).toContain('(empty)');
    });

    it('returns error for find_by_text without text', async () => {
      expect(await tool.validate('{"action": "find_by_text"}')).toContain("'text' required");
    });

    it('returns error for find_by_id without id', async () => {
      expect(await tool.validate('{"action": "find_by_id"}')).toContain("'id' required");
    });
  });

  describe('execute', () => {
    const mockClient = {
      findByText: vi.fn(),
      findById: vi.fn(),
      isAvailable: vi.fn(() => true),
      destroy: vi.fn(),
    };

    beforeEach(() => {
      _resetModuleCache();
      vi.resetModules();
      vi.doMock('@gyo-framework/screen-find', () => ({
        ScreenFind: vi.fn(() => mockClient),
      }));
      mockClient.findByText.mockReset();
      mockClient.findById.mockReset();
      mockClient.isAvailable.mockReturnValue(true);
      mockClient.destroy.mockReset();
    });

    afterEach(() => {
      vi.restoreAllMocks();
    });

    it('returns error when bridge not available', async () => {
      _resetModuleCache();
      vi.doMock('@gyo-framework/screen-find', () => ({
        ScreenFind: vi.fn(() => ({
          isAvailable: () => false,
          destroy: vi.fn(),
        })),
      }));
      const { ScreenFindTool: FreshTool, _resetModuleCache: freshReset } = await import('../../../tools/screen-find');
      freshReset();
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "find_by_text", "text": "test"}');
      expect(result.error).toContain('not available');
    });

    it('finds elements by text successfully', async () => {
      mockClient.findByText.mockResolvedValue({
        elements: [
          {
            text: 'Submit',
            contentDescription: '',
            className: 'Button',
            bounds: '[100,200][300,280]',
            centerX: 200,
            centerY: 240,
            isClickable: true,
            isFocusable: true,
            isEditable: false,
          },
        ],
        count: 1,
      });
      const { ScreenFindTool: FreshTool } = await import('../../../tools/screen-find');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "find_by_text", "text": "Submit"}');
      expect(result.output).toContain("1 elements matching 'Submit'");
      expect(result.output).toContain('Submit');
      expect(result.output).toContain('Button');
      expect(result.output).toContain('clickable');
      expect(result.output).toContain('focusable');
      expect(mockClient.findByText).toHaveBeenCalledWith({ text: 'Submit', exact: false });
      expect(mockClient.destroy).toHaveBeenCalled();
    });

    it('finds elements by text with exact=true', async () => {
      mockClient.findByText.mockResolvedValue({
        elements: [],
        count: 0,
      });
      const { ScreenFindTool: FreshTool } = await import('../../../tools/screen-find');
      const freshTool = new FreshTool();
      await freshTool.execute('{"action": "find_by_text", "text": "Exact", "exact": true}');
      expect(mockClient.findByText).toHaveBeenCalledWith({ text: 'Exact', exact: true });
    });

    it('handles no elements found by text', async () => {
      mockClient.findByText.mockResolvedValue({ elements: [], count: 0 });
      const { ScreenFindTool: FreshTool } = await import('../../../tools/screen-find');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "find_by_text", "text": "xyz"}');
      expect(result.output).toContain("No elements matching 'xyz'");
    });

    it('finds elements by id successfully', async () => {
      mockClient.findById.mockResolvedValue({
        elements: [
          {
            text: 'Login',
            contentDescription: '',
            className: 'Button',
            bounds: '[50,100][200,180]',
            centerX: 125,
            centerY: 140,
            isClickable: true,
            isFocusable: false,
            isEditable: false,
          },
        ],
        count: 1,
      });
      const { ScreenFindTool: FreshTool } = await import('../../../tools/screen-find');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "find_by_id", "id": "com.example:id/login"}');
      expect(result.output).toContain("1 elements with id 'com.example:id/login'");
      expect(result.output).toContain('Login');
      expect(result.output).toContain('Button');
      expect(result.output).toContain('clickable');
      expect(mockClient.findById).toHaveBeenCalledWith({ id: 'com.example:id/login' });
      expect(mockClient.destroy).toHaveBeenCalled();
    });

    it('handles no elements found by id', async () => {
      mockClient.findById.mockResolvedValue({ elements: [], count: 0 });
      const { ScreenFindTool: FreshTool } = await import('../../../tools/screen-find');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "find_by_id", "id": "nonexistent"}');
      expect(result.output).toContain("No elements with id 'nonexistent'");
    });

    it('returns error for unknown action', async () => {
      const { ScreenFindTool: FreshTool } = await import('../../../tools/screen-find');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "unknown"}');
      expect(result.error).toContain('Unknown action');
    });

    it('destroys client even on error', async () => {
      mockClient.findByText.mockRejectedValue(new Error('bridge error'));
      const { ScreenFindTool: FreshTool } = await import('../../../tools/screen-find');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "find_by_text", "text": "test"}');
      expect(result.error).toContain('bridge error');
      expect(mockClient.destroy).toHaveBeenCalled();
    });
  });
});
