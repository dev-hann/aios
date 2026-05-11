import { describe, it, expect } from 'vitest';
import { NotepadTool } from '../../../tools/notepad';

describe('NotepadTool', () => {
  const notepad = new NotepadTool();

  it('has correct name', () => {
    expect(notepad.name).toBe('notepad');
  });

  describe('save', () => {
    it('saves a note', async () => {
      const result = await notepad.execute('{"action": "save", "key": "test", "value": "hello"}');
      expect(result.output).toBe("Saved note 'test'");
    });

    it('returns error for empty key', async () => {
      const result = await notepad.execute('{"action": "save", "key": "", "value": "hello"}');
      expect(result.error).toContain("'key' required");
    });

    it('returns error for missing key', async () => {
      const result = await notepad.execute('{"action": "save", "value": "hello"}');
      expect(result.error).toContain("'key' required");
    });

    it('overwrites existing note', async () => {
      await notepad.execute('{"action": "save", "key": "dup", "value": "first"}');
      const result = await notepad.execute('{"action": "save", "key": "dup", "value": "second"}');
      expect(result.output).toBe("Saved note 'dup'");
      const get = await notepad.execute('{"action": "get", "key": "dup"}');
      expect(get.output).toBe('second');
    });

    it('saves empty value', async () => {
      const result = await notepad.execute('{"action": "save", "key": "empty", "value": ""}');
      expect(result.output).toBe("Saved note 'empty'");
      const get = await notepad.execute('{"action": "get", "key": "empty"}');
      expect(get.output).toBe('');
    });
  });

  describe('get', () => {
    it('returns saved note value', async () => {
      await notepad.execute('{"action": "save", "key": "fetch", "value": "data"}');
      const result = await notepad.execute('{"action": "get", "key": "fetch"}');
      expect(result.output).toBe('data');
    });

    it('returns not found for missing key', async () => {
      const result = await notepad.execute('{"action": "get", "key": "nonexistent"}');
      expect(result.output).toContain('not found');
      expect(result.error).toBeUndefined();
    });

    it('returns error for missing key field', async () => {
      const result = await notepad.execute('{"action": "get"}');
      expect(result.output).toContain('not found');
    });
  });

  describe('list', () => {
    it('returns no notes message when empty', async () => {
      const fresh = new NotepadTool();
      const result = await fresh.execute('{"action": "list"}');
      expect(result.output).toBe('No notes saved');
    });

    it('lists all saved notes', async () => {
      const fresh = new NotepadTool();
      await fresh.execute('{"action": "save", "key": "a", "value": "1"}');
      await fresh.execute('{"action": "save", "key": "b", "value": "2"}');
      const result = await fresh.execute('{"action": "list"}');
      expect(result.output).toContain('- a: 1');
      expect(result.output).toContain('- b: 2');
    });
  });

  describe('delete', () => {
    it('deletes existing note', async () => {
      await notepad.execute('{"action": "save", "key": "del", "value": "data"}');
      const result = await notepad.execute('{"action": "delete", "key": "del"}');
      expect(result.output).toBe("Deleted note 'del'");
    });

    it('returns not found for missing key on delete', async () => {
      const result = await notepad.execute('{"action": "delete", "key": "nonexistent"}');
      expect(result.output).toContain('not found');
    });

    it('actually removes the note', async () => {
      await notepad.execute('{"action": "save", "key": "temp", "value": "data"}');
      await notepad.execute('{"action": "delete", "key": "temp"}');
      const result = await notepad.execute('{"action": "get", "key": "temp"}');
      expect(result.output).toContain('not found');
    });
  });

  describe('action handling', () => {
    it('is case-insensitive for action', async () => {
      const result = await notepad.execute('{"action": "SAVE", "key": "ci", "value": "test"}');
      expect(result.output).toBe("Saved note 'ci'");
    });

    it('returns error for unknown action', async () => {
      const result = await notepad.execute('{"action": "unknown"}');
      expect(result.error).toContain("Unknown action 'unknown'");
    });

    it('returns error for empty action', async () => {
      const result = await notepad.execute('{"action": ""}');
      expect(result.error).toContain("Unknown action ''");
    });

    it('returns error for missing action', async () => {
      const result = await notepad.execute('{}');
      expect(result.error).toContain("Unknown action ''");
    });

    it('returns error for invalid JSON', async () => {
      const result = await notepad.execute('not json');
      expect(result.error).toBeDefined();
    });
  });

  describe('save-list-delete cycle', () => {
    it('full cycle works correctly', async () => {
      const fresh = new NotepadTool();
      await fresh.execute('{"action": "save", "key": "x", "value": "1"}');
      await fresh.execute('{"action": "save", "key": "y", "value": "2"}');
      const list1 = await fresh.execute('{"action": "list"}');
      expect(list1.output).toContain('x: 1');
      expect(list1.output).toContain('y: 2');
      await fresh.execute('{"action": "delete", "key": "x"}');
      const list2 = await fresh.execute('{"action": "list"}');
      expect(list2.output).not.toContain('x: 1');
      expect(list2.output).toContain('y: 2');
    });
  });

  describe('validate', () => {
    it('returns null for valid save', async () => {
      expect(await notepad.validate('{"action": "save", "key": "test", "value": "v"}')).toBeNull();
    });

    it('returns null for valid list', async () => {
      expect(await notepad.validate('{"action": "list"}')).toBeNull();
    });

    it('returns error for empty action', async () => {
      expect(await notepad.validate('{}')).toContain('not a valid action');
    });

    it('returns error for invalid action', async () => {
      expect(await notepad.validate('{"action": "create"}')).toContain('not a valid action');
    });

    it('returns error for save without key', async () => {
      expect(await notepad.validate('{"action": "save", "value": "v"}')).toBe("'key' required for save action");
    });

    it('returns error for get without key', async () => {
      expect(await notepad.validate('{"action": "get"}')).toBe("'key' required for get action");
    });

    it('returns error for delete without key', async () => {
      expect(await notepad.validate('{"action": "delete"}')).toBe("'key' required for delete action");
    });
  });
});
