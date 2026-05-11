import type { ToolResult } from '../types/agent';
import { toolResultOk, toolResultErr } from '../types/agent';
import { tryParseToolJson } from '../agent/tool-json-parser';
import type { AgentTool } from './types';
import type { ScreenFind as ScreenFindClient } from '@gyo-framework/screen-find';

type ScreenFindModule = typeof import('@gyo-framework/screen-find');

let cachedModule: ScreenFindModule | null = null;

async function loadModule(): Promise<ScreenFindModule | null> {
  if (cachedModule) return cachedModule;
  try {
    cachedModule = await import('@gyo-framework/screen-find');
    return cachedModule;
  } catch {
    return null;
  }
}

export function _resetModuleCache(): void {
  cachedModule = null;
}

export class ScreenFindTool implements AgentTool {
  readonly name = 'screen_find';
  readonly description = 'Find screen elements by text or resource ID. Args: {action, text, id, exact}';
  readonly parameters =
    '{"action": "find_by_text|find_by_id", "text": "string (for find_by_text)", "exact": "boolean (for find_by_text)", "id": "string (for find_by_id)"}';
  readonly toolPrompt =
    'Find UI elements on screen by text or resource ID.\n\n' +
    'Parameters: ' + this.parameters + '\n\n' +
    'Actions:\n' +
    '- find_by_text: find elements matching text (optional exact boolean)\n' +
    '- find_by_id: find elements by resource ID';

  async isAvailable(): Promise<boolean> {
    const client = await this.createClient();
    if (!client) return false;
    client.destroy();
    return true;
  }

  private async createClient(): Promise<ScreenFindClient | null> {
    const mod = await loadModule();
    if (!mod) return null;
    const client = new mod.ScreenFind();
    if (!client.isAvailable()) {
      client.destroy();
      return null;
    }
    return client;
  }

  async validate(args: string): Promise<string | null> {
    const json = tryParseToolJson(args);
    const action = (json['action'] as string)?.toLowerCase() ?? '';
    if (!['find_by_text', 'find_by_id'].includes(action))
      return `'${action || '(empty)'}' is not a valid action. Use find_by_text or find_by_id.`;
    if (action === 'find_by_text' && !json['text'])
      return "'text' required for find_by_text action";
    if (action === 'find_by_id' && !json['id'])
      return "'id' required for find_by_id action";
    return null;
  }

  async execute(args: string): Promise<ToolResult> {
    try {
      const client = await this.createClient();
      if (!client) return toolResultErr('Screen find not available (requires native bridge)');

      const json = tryParseToolJson(args);
      const action = (json['action'] as string)?.toLowerCase() ?? '';

      try {
        switch (action) {
          case 'find_by_text': return await this.findByText(client, json);
          case 'find_by_id': return await this.findById(client, json);
          default: return toolResultErr(`Unknown action '${action}'. Use find_by_text or find_by_id.`);
        }
      } finally {
        client.destroy();
      }
    } catch (e) {
      return toolResultErr(`${e}`);
    }
  }

  private async findByText(client: ScreenFindClient, json: Record<string, unknown>): Promise<ToolResult> {
    const text = (json['text'] as string) ?? '';
    const exact = json['exact'] === true;
    if (!text) return toolResultErr("'text' required");
    const result = await client.findByText({ text, exact });
    if (result.count === 0) return toolResultOk(`No elements matching '${text}'`);
    const lines = result.elements.map((el) => {
      const content = el.text || el.contentDescription || '(no text)';
      const flags = [
        el.isClickable ? 'clickable' : '',
        el.isFocusable ? 'focusable' : '',
        el.isEditable ? 'editable' : '',
      ].filter(Boolean).join(', ');
      return `- "${content}" [${el.className}] at (${el.centerX}, ${el.centerY}) (${el.bounds})${flags ? ` [${flags}]` : ''}`;
    });
    return toolResultOk(`${result.count} elements matching '${text}':\n${lines.join('\n')}`);
  }

  private async findById(client: ScreenFindClient, json: Record<string, unknown>): Promise<ToolResult> {
    const id = (json['id'] as string) ?? '';
    if (!id) return toolResultErr("'id' required");
    const result = await client.findById({ id });
    if (result.count === 0) return toolResultOk(`No elements with id '${id}'`);
    const lines = result.elements.map((el) => {
      const content = el.text || el.contentDescription || '(no text)';
      const flags = [
        el.isClickable ? 'clickable' : '',
        el.isFocusable ? 'focusable' : '',
        el.isEditable ? 'editable' : '',
      ].filter(Boolean).join(', ');
      return `- "${content}" [${el.className}] at (${el.centerX}, ${el.centerY}) (${el.bounds})${flags ? ` [${flags}]` : ''}`;
    });
    return toolResultOk(`${result.count} elements with id '${id}':\n${lines.join('\n')}`);
  }
}
