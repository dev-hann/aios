import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ContactSearchTool, _resetModuleCache } from '../../../tools/contact-search';

describe('ContactSearchTool', () => {
  const tool = new ContactSearchTool();

  it('has correct name', () => {
    expect(tool.name).toBe('contact_search');
  });

  describe('validate', () => {
    it('returns null for valid search action with query', async () => {
      expect(await tool.validate('{"action": "search", "query": "John"}')).toBeNull();
    });

    it('returns null for search case-insensitive', async () => {
      expect(await tool.validate('{"action": "SEARCH", "query": "John"}')).toBeNull();
    });

    it('returns error for invalid action', async () => {
      expect(await tool.validate('{"action": "invalid"}')).toContain('not a valid action');
    });

    it('returns error for empty action', async () => {
      expect(await tool.validate('{}')).toContain('(empty)');
    });

    it('returns error for search without query', async () => {
      expect(await tool.validate('{"action": "search"}')).toContain("'query' required");
    });
  });

  describe('execute', () => {
    const mockClient = {
      search: vi.fn(),
      isAvailable: vi.fn(() => true),
      destroy: vi.fn(),
    };

    beforeEach(() => {
      _resetModuleCache();
      vi.resetModules();
      vi.doMock('@gyo-framework/contact-search', () => ({
        ContactSearch: vi.fn(() => mockClient),
      }));
      mockClient.search.mockReset();
      mockClient.isAvailable.mockReturnValue(true);
      mockClient.destroy.mockReset();
    });

    afterEach(() => {
      vi.restoreAllMocks();
    });

    it('returns error when bridge not available', async () => {
      _resetModuleCache();
      vi.doMock('@gyo-framework/contact-search', () => ({
        ContactSearch: vi.fn(() => ({
          isAvailable: () => false,
          destroy: vi.fn(),
        })),
      }));
      const { ContactSearchTool: FreshTool, _resetModuleCache: freshReset } = await import('../../../tools/contact-search');
      freshReset();
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "search", "query": "John"}');
      expect(result.error).toContain('not available');
    });

    it('searches contacts successfully', async () => {
      mockClient.search.mockResolvedValue({
        contacts: [
          { name: 'John Doe', phoneNumbers: ['123-456-7890'], emails: ['john@example.com'] },
          { name: 'John Smith', phoneNumbers: ['098-765-4321'], emails: [] },
        ],
        count: 2,
      });
      const { ContactSearchTool: FreshTool } = await import('../../../tools/contact-search');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "search", "query": "John"}');
      expect(result.output).toContain("2 contacts matching 'John'");
      expect(result.output).toContain('John Doe');
      expect(result.output).toContain('123-456-7890');
      expect(result.output).toContain('john@example.com');
      expect(result.output).toContain('John Smith');
      expect(mockClient.destroy).toHaveBeenCalled();
    });

    it('handles no matching contacts', async () => {
      mockClient.search.mockResolvedValue({ contacts: [], count: 0 });
      const { ContactSearchTool: FreshTool } = await import('../../../tools/contact-search');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "search", "query": "xyz"}');
      expect(result.output).toContain("No contacts matching 'xyz'");
    });

    it('returns error for unknown action', async () => {
      const { ContactSearchTool: FreshTool } = await import('../../../tools/contact-search');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "unknown"}');
      expect(result.error).toContain('Unknown action');
    });

    it('destroys client even on error', async () => {
      mockClient.search.mockRejectedValue(new Error('bridge error'));
      const { ContactSearchTool: FreshTool } = await import('../../../tools/contact-search');
      const freshTool = new FreshTool();
      const result = await freshTool.execute('{"action": "search", "query": "John"}');
      expect(result.error).toContain('bridge error');
      expect(mockClient.destroy).toHaveBeenCalled();
    });
  });
});
