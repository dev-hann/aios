import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { DeviceInfoTool, _resetModuleCache } from '../../../tools/device-info';

describe('DeviceInfoTool', () => {
  const tool = new DeviceInfoTool();

  it('has correct name', () => {
    expect(tool.name).toBe('device_info');
  });

  describe('validate', () => {
    it('returns null for valid get_info action', async () => {
      expect(await tool.validate('{"action": "get_info"}')).toBeNull();
    });

    it('returns null for get_info case-insensitive', async () => {
      expect(await tool.validate('{"action": "GET_INFO"}')).toBeNull();
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
      getInfo: vi.fn(),
      isAvailable: vi.fn(() => true),
      destroy: vi.fn(),
    };

    beforeEach(() => {
      _resetModuleCache();
      vi.resetModules();
      vi.doMock('@gyo-framework/device-info', () => ({
        DeviceInfo: vi.fn(() => mockClient),
      }));
      mockClient.getInfo.mockReset();
      mockClient.isAvailable.mockReturnValue(true);
      mockClient.destroy.mockReset();
    });

    afterEach(() => {
      vi.restoreAllMocks();
    });

    it('returns error when bridge not available', async () => {
      _resetModuleCache();
      vi.doMock('@gyo-framework/device-info', () => ({
        DeviceInfo: vi.fn(() => ({
          isAvailable: () => false,
          destroy: vi.fn(),
        })),
      }));
      const { DeviceInfoTool: FreshTool, _resetModuleCache: freshReset } = await import('../../../tools/device-info');
      freshReset();
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "get_info"}');
      expect(result.error).toContain('not available');
    });

    it('gets device info successfully', async () => {
      mockClient.getInfo.mockResolvedValue({
        info: {
          manufacturer: 'Samsung',
          model: 'Galaxy S24',
          brand: 'samsung',
          device: 'e1q',
          androidVersion: '14',
          sdkVersion: 34,
          securityPatch: '2024-01-05',
          screenWidth: 1080,
          screenHeight: 2340,
          screenDensity: 420,
          batteryLevel: 85,
          isCharging: false,
        },
      });
      const { DeviceInfoTool: FreshTool } = await import('../../../tools/device-info');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "get_info"}');
      expect(result.output).toContain('Device Info');
      expect(result.output).toContain('Samsung');
      expect(result.output).toContain('Galaxy S24');
      expect(result.output).toContain('Android Version: 14');
      expect(result.output).toContain('Battery: 85%');
      expect(mockClient.destroy).toHaveBeenCalled();
    });

    it('shows charging status when charging', async () => {
      mockClient.getInfo.mockResolvedValue({
        info: {
          manufacturer: 'Google',
          model: 'Pixel 8',
          brand: 'google',
          device: 'shiba',
          androidVersion: '14',
          sdkVersion: 34,
          securityPatch: '2024-02-01',
          screenWidth: 1080,
          screenHeight: 2400,
          screenDensity: 420,
          batteryLevel: 50,
          isCharging: true,
        },
      });
      const { DeviceInfoTool: FreshTool } = await import('../../../tools/device-info');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "get_info"}');
      expect(result.output).toContain('50% (charging)');
      expect(mockClient.destroy).toHaveBeenCalled();
    });

    it('returns error for unknown action', async () => {
      const { DeviceInfoTool: FreshTool } = await import('../../../tools/device-info');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "unknown"}');
      expect(result.error).toContain('Unknown action');
    });

    it('destroys client even on error', async () => {
      mockClient.getInfo.mockRejectedValue(new Error('bridge error'));
      const { DeviceInfoTool: FreshTool } = await import('../../../tools/device-info');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "get_info"}');
      expect(result.error).toContain('bridge error');
      expect(mockClient.destroy).toHaveBeenCalled();
    });
  });
});
