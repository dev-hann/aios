import type { ToolResult } from '../types/agent';
import { toolResultOk, toolResultErr } from '../types/agent';
import { tryParseToolJson } from '../agent/tool-json-parser';
import type { AgentTool } from './types';

export class NotepadTool implements AgentTool {
  readonly name = 'notepad';
  readonly description = 'Save/get/list/delete notes. Args: {action, key, value}';
  readonly parameters = '{"action": "save|get|list|delete", "key": "string", "value": "string (for save)"}';
  readonly toolPrompt =
    'Manage notes (save, get, list, delete).\n\n' +
    'Parameters: ' + this.parameters + '\n\n' +
    'Rules:\n- "action" is required\n- save: requires "key" and "value"\n- get: requires "key"\n- list: no params\n- delete: requires "key"';

  private notes = new Map<string, string>();

  async validate(args: string): Promise<string | null> {
    const json = tryParseToolJson(args);
    const action = (json['action'] as string)?.toLowerCase() ?? '';
    if (!['save', 'get', 'list', 'delete'].includes(action))
      return `'${action || '(empty)'}' is not a valid action. Use save, get, list, or delete.`;
    if (action === 'save' && !json['key']) return "'key' required for save action";
    if ((action === 'get' || action === 'delete') && !json['key'])
      return `'key' required for ${action} action`;
    return null;
  }

  async execute(args: string): Promise<ToolResult> {
    try {
      const json = tryParseToolJson(args);
      const action = (json['action'] as string)?.toLowerCase() ?? '';
      switch (action) {
        case 'save': return this.save(json);
        case 'get': return this.get(json);
        case 'list': return this.list();
        case 'delete': return this.delete(json);
        default: return toolResultErr(`Unknown action '${action}'. Use save, get, list, or delete.`);
      }
    } catch (e) {
      return toolResultErr(`${e}`);
    }
  }

  private save(json: Record<string, unknown>): ToolResult {
    const key = (json['key'] as string) ?? '';
    const value = (json['value'] as string) ?? '';
    if (!key) return toolResultErr("'key' required");
    this.notes.set(key, value);
    return toolResultOk(`Saved note '${key}'`);
  }

  private get(json: Record<string, unknown>): ToolResult {
    const key = (json['key'] as string) ?? '';
    const value = this.notes.get(key);
    if (value == null) return toolResultOk(`Note '${key}' not found`);
    return toolResultOk(value);
  }

  private list(): ToolResult {
    if (this.notes.size === 0) return toolResultOk('No notes saved');
    const lines = [...this.notes.entries()].map(([k, v]) => `- ${k}: ${v}`);
    return toolResultOk(lines.join('\n'));
  }

  private delete(json: Record<string, unknown>): ToolResult {
    const key = (json['key'] as string) ?? '';
    const deleted = this.notes.delete(key);
    if (deleted) return toolResultOk(`Deleted note '${key}'`);
    return toolResultOk(`Note '${key}' not found`);
  }
}
