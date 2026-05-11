import type { ToolResult } from '../types/agent';
import { toolResultOk, toolResultErr } from '../types/agent';
import { tryParseToolJson } from '../agent/tool-json-parser';
import type { AgentTool } from './types';
import type { SmsSender as SmsSenderClient } from '@gyo-framework/sms-sender';

type SmsSenderModule = typeof import('@gyo-framework/sms-sender');

let cachedModule: SmsSenderModule | null = null;

async function loadModule(): Promise<SmsSenderModule | null> {
  if (cachedModule) return cachedModule;
  try {
    cachedModule = await import('@gyo-framework/sms-sender');
    return cachedModule;
  } catch {
    return null;
  }
}

export function _resetModuleCache(): void {
  cachedModule = null;
}

export class SmsSenderTool implements AgentTool {
  readonly name = 'sms_sender';
  readonly description = 'Send and read SMS messages. Args: {action, phoneNumber, message, limit}';
  readonly parameters =
    '{"action": "send|read", "phoneNumber": "string (for send)", "message": "string (for send)", "limit": "number (for read)"}';
  readonly toolPrompt =
    'Send and read SMS messages on the device.\n\n' +
    'Parameters: ' + this.parameters + '\n\n' +
    'Actions:\n' +
    '- send: send an SMS message (requires phoneNumber and message)\n' +
    '- read: read recent SMS messages (requires limit)';

  async isAvailable(): Promise<boolean> {
    const client = await this.createClient();
    if (!client) return false;
    client.destroy();
    return true;
  }

  private async createClient(): Promise<SmsSenderClient | null> {
    const mod = await loadModule();
    if (!mod) return null;
    const client = new mod.SmsSender();
    if (!client.isAvailable()) {
      client.destroy();
      return null;
    }
    return client;
  }

  async validate(args: string): Promise<string | null> {
    const json = tryParseToolJson(args);
    const action = (json['action'] as string)?.toLowerCase() ?? '';
    if (!['send', 'read'].includes(action))
      return `'${action || '(empty)'}' is not a valid action. Use send or read.`;
    if (action === 'send' && !json['phoneNumber'])
      return "'phoneNumber' required for send action";
    if (action === 'send' && !json['message'])
      return "'message' required for send action";
    if (action === 'read' && !json['limit'])
      return "'limit' required for read action";
    return null;
  }

  async execute(args: string): Promise<ToolResult> {
    try {
      const client = await this.createClient();
      if (!client) return toolResultErr('SMS sender not available (requires native bridge)');

      const json = tryParseToolJson(args);
      const action = (json['action'] as string)?.toLowerCase() ?? '';

      try {
        switch (action) {
          case 'send': return await this.send(client, json);
          case 'read': return await this.read(client, json);
          default: return toolResultErr(`Unknown action '${action}'. Use send or read.`);
        }
      } finally {
        client.destroy();
      }
    } catch (e) {
      return toolResultErr(`${e}`);
    }
  }

  private async send(client: SmsSenderClient, json: Record<string, unknown>): Promise<ToolResult> {
    const phoneNumber = (json['phoneNumber'] as string) ?? '';
    const message = (json['message'] as string) ?? '';
    if (!phoneNumber) return toolResultErr("'phoneNumber' required");
    if (!message) return toolResultErr("'message' required");
    const ok = await client.send({ phoneNumber, message });
    return ok ? toolResultOk(`SMS sent to ${phoneNumber}`) : toolResultErr(`Failed to send SMS to ${phoneNumber}`);
  }

  private async read(client: SmsSenderClient, json: Record<string, unknown>): Promise<ToolResult> {
    const limit = Number(json['limit']) || 10;
    const result = await client.read({ limit });
    if (result.count === 0) return toolResultOk('No SMS messages found');
    const lines = result.messages.map((m) => {
      const date = new Date(m.date).toLocaleString();
      return `- [${m.type}] ${m.address}: ${m.body} (${date})`;
    });
    return toolResultOk(`${result.count} SMS messages:\n${lines.join('\n')}`);
  }
}
