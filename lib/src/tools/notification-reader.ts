import type { ToolResult } from '../types/agent';
import { toolResultOk, toolResultErr } from '../types/agent';
import { tryParseToolJson } from '../agent/tool-json-parser';
import type { AgentTool } from './types';
import type { NotificationReader as NotificationReaderClient } from '@gyo-framework/notification-reader';

type NotificationReaderModule = typeof import('@gyo-framework/notification-reader');

let cachedModule: NotificationReaderModule | null = null;

async function loadModule(): Promise<NotificationReaderModule | null> {
  if (cachedModule) return cachedModule;
  try {
    cachedModule = await import('@gyo-framework/notification-reader');
    return cachedModule;
  } catch {
    return null;
  }
}

export function _resetModuleCache(): void {
  cachedModule = null;
}

export class NotificationReaderTool implements AgentTool {
  readonly name = 'notification_reader';
  readonly description = 'Read notifications on device. Args: {action}';
  readonly parameters =
    '{"action": "list"}';
  readonly toolPrompt =
    'Read notifications on the device.\n\n' +
    'Parameters: ' + this.parameters + '\n\n' +
    'Actions:\n' +
    '- list: list all active notifications';

  async isAvailable(): Promise<boolean> {
    const client = await this.createClient();
    if (!client) return false;
    client.destroy();
    return true;
  }

  private async createClient(): Promise<NotificationReaderClient | null> {
    const mod = await loadModule();
    if (!mod) return null;
    const client = new mod.NotificationReader();
    if (!client.isAvailable()) {
      client.destroy();
      return null;
    }
    return client;
  }

  async validate(args: string): Promise<string | null> {
    const json = tryParseToolJson(args);
    const action = (json['action'] as string)?.toLowerCase() ?? '';
    if (!['list'].includes(action))
      return `'${action || '(empty)'}' is not a valid action. Use list.`;
    return null;
  }

  async execute(args: string): Promise<ToolResult> {
    try {
      const client = await this.createClient();
      if (!client) return toolResultErr('Notification reader not available (requires native bridge)');

      const json = tryParseToolJson(args);
      const action = (json['action'] as string)?.toLowerCase() ?? '';

      try {
        switch (action) {
          case 'list': return await this.listNotifications(client);
          default: return toolResultErr(`Unknown action '${action}'. Use list.`);
        }
      } finally {
        client.destroy();
      }
    } catch (e) {
      return toolResultErr(`${e}`);
    }
  }

  private async listNotifications(client: NotificationReaderClient): Promise<ToolResult> {
    const result = await client.list();
    if (result.count === 0) return toolResultOk('No active notifications');
    const lines = result.notifications.map((n) => {
      const time = new Date(n.postTime).toLocaleTimeString();
      return `- [${n.packageName}] ${n.title}: ${n.text} (${time})`;
    });
    return toolResultOk(`${result.count} notifications:\n${lines.join('\n')}`);
  }
}
