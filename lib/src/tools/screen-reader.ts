import type { ToolResult } from '../types/agent';
import { toolResultOk, toolResultErr } from '../types/agent';
import { tryParseToolJson } from '../agent/tool-json-parser';
import type { AgentTool } from './types';
import type { ScreenReader as ScreenReaderClient, NodeInfo } from '@gyo-framework/screen-reader';

type ScreenReaderModule = typeof import('@gyo-framework/screen-reader');

let cachedModule: ScreenReaderModule | null = null;

async function loadModule(): Promise<ScreenReaderModule | null> {
  if (cachedModule) return cachedModule;
  try {
    cachedModule = await import('@gyo-framework/screen-reader');
    return cachedModule;
  } catch {
    return null;
  }
}

export function _resetModuleCache(): void {
  cachedModule = null;
}

function formatNode(node: NodeInfo, indent: number = 0): string {
  const prefix = ' '.repeat(indent);
  const text = node.text || node.contentDescription || '';
  const clickable = node.isClickable ? ' [clickable]' : '';
  const editable = node.isEditable ? ' [editable]' : '';
  const line = text
    ? `${prefix}- ${node.className}${clickable}${editable}: "${text}" (${node.bounds})`
    : `${prefix}- ${node.className}${clickable}${editable} (${node.bounds})`;
  const childLines = node.children.map((c) => formatNode(c, indent + 2));
  return [line, ...childLines].join('\n');
}

export class ScreenReaderTool implements AgentTool {
  readonly name = 'screen_reader';
  readonly description = 'Read screen content and find elements. Args: {action, text}';
  readonly parameters =
    '{"action": "read|find", "text": "string (for find)"}';
  readonly toolPrompt =
    'Read screen content and find UI elements via accessibility.\n\n' +
    'Parameters: ' + this.parameters + '\n\n' +
    'Actions:\n' +
    '- read: read the full screen accessibility tree\n' +
    '- find: find elements matching text';

  async isAvailable(): Promise<boolean> {
    const client = await this.createClient();
    if (!client) return false;
    client.destroy();
    return true;
  }

  private async createClient(): Promise<ScreenReaderClient | null> {
    const mod = await loadModule();
    if (!mod) return null;
    const client = new mod.ScreenReader();
    if (!client.isAvailable()) {
      client.destroy();
      return null;
    }
    return client;
  }

  async validate(args: string): Promise<string | null> {
    const json = tryParseToolJson(args);
    const action = (json['action'] as string)?.toLowerCase() ?? '';
    if (!['read', 'find'].includes(action))
      return `'${action || '(empty)'}' is not a valid action. Use read or find.`;
    if (action === 'find' && !json['text'])
      return "'text' required for find action";
    return null;
  }

  async execute(args: string): Promise<ToolResult> {
    try {
      const client = await this.createClient();
      if (!client) return toolResultErr('Screen reader not available (requires native bridge)');

      const json = tryParseToolJson(args);
      const action = (json['action'] as string)?.toLowerCase() ?? '';

      try {
        switch (action) {
          case 'read': return await this.readScreen(client);
          case 'find': return await this.findNodes(client, json);
          default: return toolResultErr(`Unknown action '${action}'. Use read or find.`);
        }
      } finally {
        client.destroy();
      }
    } catch (e) {
      return toolResultErr(`${e}`);
    }
  }

  private async readScreen(client: ScreenReaderClient): Promise<ToolResult> {
    const result = await client.read();
    if (!result.root) return toolResultOk('Screen is empty or no accessibility tree available');
    const header = `Package: ${result.packageName} | Window: ${result.windowName}`;
    const tree = formatNode(result.root);
    return toolResultOk(`${header}\n${tree}`);
  }

  private async findNodes(client: ScreenReaderClient, json: Record<string, unknown>): Promise<ToolResult> {
    const text = (json['text'] as string) ?? '';
    if (!text) return toolResultErr("'text' required");
    const result = await client.find({ text });
    if (result.count === 0) return toolResultOk(`No elements matching '${text}'`);
    const lines = result.nodes.map((n) => {
      const content = n.text || n.contentDescription || '(no text)';
      return `- ${content} [${n.className}] (${n.bounds})${n.isClickable ? ' clickable' : ''}${n.isEditable ? ' editable' : ''}`;
    });
    return toolResultOk(`${result.count} elements matching '${text}':\n${lines.join('\n')}`);
  }
}
