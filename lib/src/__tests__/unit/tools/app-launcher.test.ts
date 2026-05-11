import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { AppLauncherTool, _resetModuleCache } from '../../../tools/app-launcher';

describe('AppLauncherTool', () => {
  const tool = new AppLauncherTool();

  it('has correct name', () => {
    expect(tool.name).toBe('app_launcher');
  });

  describe('validate', () => {
    it('returns null for valid list_apps action', async () => {
      expect(await tool.validate('{"action": "list_apps"}')).toBeNull();
    });

    it('returns null for valid open_app action with packageName', async () => {
      expect(await tool.validate('{"action": "open_app", "packageName": "com.example"}')).toBeNull();
    });

    it('returns null for valid open_url action with url', async () => {
      expect(await tool.validate('{"action": "open_url", "url": "https://example.com"}')).toBeNull();
    });

    it('returns null for valid search_apps action with query', async () => {
      expect(await tool.validate('{"action": "search_apps", "query": "chrome"}')).toBeNull();
    });

    it('returns error for invalid action', async () => {
      expect(await tool.validate('{"action": "invalid"}')).toContain('not a valid action');
    });

    it('returns error for empty action', async () => {
      expect(await tool.validate('{}')).toContain('(empty)');
    });

    it('returns error for open_app without packageName', async () => {
      expect(await tool.validate('{"action": "open_app"}')).toContain("'packageName' required");
    });

    it('returns error for open_url without url', async () => {
      expect(await tool.validate('{"action": "open_url"}')).toContain("'url' required");
    });

    it('returns error for search_apps without query', async () => {
      expect(await tool.validate('{"action": "search_apps"}')).toContain("'query' required");
    });

    it('is case-insensitive for actions', async () => {
      expect(await tool.validate('{"action": "LIST_APPS"}')).toBeNull();
    });
  });

  describe('execute', () => {
    const mockLauncher = {
      listApps: vi.fn(),
      openApp: vi.fn(),
      openUrl: vi.fn(),
      searchApps: vi.fn(),
      isAvailable: vi.fn(() => true),
      destroy: vi.fn(),
    };

    beforeEach(() => {
      _resetModuleCache();
      vi.resetModules();
      vi.doMock('@gyo-framework/app-launcher', () => ({
        AppLauncher: vi.fn(() => mockLauncher),
      }));
      mockLauncher.listApps.mockReset();
      mockLauncher.openApp.mockReset();
      mockLauncher.openUrl.mockReset();
      mockLauncher.searchApps.mockReset();
      mockLauncher.isAvailable.mockReturnValue(true);
      mockLauncher.destroy.mockReset();
    });

    afterEach(() => {
      vi.restoreAllMocks();
    });

    it('returns error when bridge not available', async () => {
      _resetModuleCache();
      vi.doMock('@gyo-framework/app-launcher', () => ({
        AppLauncher: vi.fn(() => ({
          isAvailable: () => false,
          destroy: vi.fn(),
        })),
      }));
      const { AppLauncherTool: FreshTool, _resetModuleCache: freshReset } = await import('../../../tools/app-launcher');
      freshReset();
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "list_apps"}');
      expect(result.error).toContain('not available');
    });

    it('lists apps successfully', async () => {
      mockLauncher.listApps.mockResolvedValue({
        apps: [
          { packageName: 'com.chrome', name: 'Chrome' },
          { packageName: 'com.gmail', name: 'Gmail' },
        ],
        count: 2,
      });
      const { AppLauncherTool: FreshTool } = await import('../../../tools/app-launcher');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "list_apps"}');
      expect(result.output).toContain('2 apps installed');
      expect(result.output).toContain('Chrome');
      expect(result.output).toContain('Gmail');
      expect(mockLauncher.destroy).toHaveBeenCalled();
    });

    it('handles empty app list', async () => {
      mockLauncher.listApps.mockResolvedValue({ apps: [], count: 0 });
      const { AppLauncherTool: FreshTool } = await import('../../../tools/app-launcher');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "list_apps"}');
      expect(result.output).toContain('No apps found');
    });

    it('opens app successfully', async () => {
      mockLauncher.openApp.mockResolvedValue(true);
      const { AppLauncherTool: FreshTool } = await import('../../../tools/app-launcher');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "open_app", "packageName": "com.chrome"}');
      expect(result.output).toContain('Opened com.chrome');
      expect(mockLauncher.openApp).toHaveBeenCalledWith({ packageName: 'com.chrome' });
    });

    it('handles open app failure', async () => {
      mockLauncher.openApp.mockResolvedValue(false);
      const { AppLauncherTool: FreshTool } = await import('../../../tools/app-launcher');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "open_app", "packageName": "com.unknown"}');
      expect(result.error).toContain('Failed to open');
    });

    it('opens url successfully', async () => {
      mockLauncher.openUrl.mockResolvedValue(true);
      const { AppLauncherTool: FreshTool } = await import('../../../tools/app-launcher');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "open_url", "url": "https://google.com"}');
      expect(result.output).toContain('Opened https://google.com');
    });

    it('handles open url failure', async () => {
      mockLauncher.openUrl.mockResolvedValue(false);
      const { AppLauncherTool: FreshTool } = await import('../../../tools/app-launcher');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "open_url", "url": "invalid"}');
      expect(result.error).toContain('Failed to open');
    });

    it('searches apps successfully', async () => {
      mockLauncher.searchApps.mockResolvedValue({
        apps: [{ packageName: 'com.chrome', name: 'Chrome' }],
        count: 1,
      });
      const { AppLauncherTool: FreshTool } = await import('../../../tools/app-launcher');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "search_apps", "query": "chr"}');
      expect(result.output).toContain("1 apps matching 'chr'");
      expect(result.output).toContain('Chrome');
    });

    it('handles no search results', async () => {
      mockLauncher.searchApps.mockResolvedValue({ apps: [], count: 0 });
      const { AppLauncherTool: FreshTool } = await import('../../../tools/app-launcher');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "search_apps", "query": "xyz"}');
      expect(result.output).toContain("No apps matching 'xyz'");
    });

    it('returns error for unknown action', async () => {
      const { AppLauncherTool: FreshTool } = await import('../../../tools/app-launcher');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "unknown"}');
      expect(result.error).toContain('Unknown action');
    });

    it('destroys launcher even on error', async () => {
      mockLauncher.listApps.mockRejectedValue(new Error('bridge error'));
      const { AppLauncherTool: FreshTool } = await import('../../../tools/app-launcher');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "list_apps"}');
      expect(result.error).toContain('bridge error');
      expect(mockLauncher.destroy).toHaveBeenCalled();
    });
  });
});
