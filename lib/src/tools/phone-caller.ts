import type { ToolResult } from '../types/agent';
import { toolResultOk, toolResultErr } from '../types/agent';
import { tryParseToolJson } from '../agent/tool-json-parser';
import type { AgentTool } from './types';
import type { PhoneCaller as PhoneCallerClient } from '@gyo-framework/phone-caller';

type PhoneCallerModule = typeof import('@gyo-framework/phone-caller');

let cachedModule: PhoneCallerModule | null = null;

async function loadModule(): Promise<PhoneCallerModule | null> {
  if (cachedModule) return cachedModule;
  try {
    cachedModule = await import('@gyo-framework/phone-caller');
    return cachedModule;
  } catch {
    return null;
  }
}

export function _resetModuleCache(): void {
  cachedModule = null;
}

export class PhoneCallerTool implements AgentTool {
  readonly name = 'phone_caller';
  readonly description = 'Make phone calls and read call log. Args: {action, phoneNumber, limit}';
  readonly parameters =
    '{"action": "call|get_call_log", "phoneNumber": "string (for call)", "limit": "number (for get_call_log)"}';
  readonly toolPrompt =
    'Make phone calls and read call log on the device.\n\n' +
    'Parameters: ' + this.parameters + '\n\n' +
    'Actions:\n' +
    '- call: initiate a phone call (requires phoneNumber)\n' +
    '- get_call_log: get recent call log entries (requires limit)';

  async isAvailable(): Promise<boolean> {
    const client = await this.createClient();
    if (!client) return false;
    client.destroy();
    return true;
  }

  private async createClient(): Promise<PhoneCallerClient | null> {
    const mod = await loadModule();
    if (!mod) return null;
    const client = new mod.PhoneCaller();
    if (!client.isAvailable()) {
      client.destroy();
      return null;
    }
    return client;
  }

  async validate(args: string): Promise<string | null> {
    const json = tryParseToolJson(args);
    const action = (json['action'] as string)?.toLowerCase() ?? '';
    if (!['call', 'get_call_log'].includes(action))
      return `'${action || '(empty)'}' is not a valid action. Use call or get_call_log.`;
    if (action === 'call' && !json['phoneNumber'])
      return "'phoneNumber' required for call action";
    if (action === 'get_call_log' && !json['limit'])
      return "'limit' required for get_call_log action";
    return null;
  }

  async execute(args: string): Promise<ToolResult> {
    try {
      const client = await this.createClient();
      if (!client) return toolResultErr('Phone caller not available (requires native bridge)');

      const json = tryParseToolJson(args);
      const action = (json['action'] as string)?.toLowerCase() ?? '';

      try {
        switch (action) {
          case 'call': return await this.call(client, json);
          case 'get_call_log': return await this.getCallLog(client, json);
          default: return toolResultErr(`Unknown action '${action}'. Use call or get_call_log.`);
        }
      } finally {
        client.destroy();
      }
    } catch (e) {
      return toolResultErr(`${e}`);
    }
  }

  private async call(client: PhoneCallerClient, json: Record<string, unknown>): Promise<ToolResult> {
    const phoneNumber = (json['phoneNumber'] as string) ?? '';
    if (!phoneNumber) return toolResultErr("'phoneNumber' required");
    const ok = await client.call({ phoneNumber });
    return ok ? toolResultOk(`Calling ${phoneNumber}`) : toolResultErr(`Failed to call ${phoneNumber}`);
  }

  private async getCallLog(client: PhoneCallerClient, json: Record<string, unknown>): Promise<ToolResult> {
    const limit = Number(json['limit']) || 10;
    const result = await client.getCallLog({ limit });
    if (result.count === 0) return toolResultOk('No call log entries found');
    const lines = result.entries.map((e) => {
      const date = new Date(e.date).toLocaleString();
      const duration = `${Math.floor(e.duration / 60)}m ${e.duration % 60}s`;
      return `- [${e.type}] ${e.name || e.number} (${duration}) at ${date}`;
    });
    return toolResultOk(`${result.count} call log entries:\n${lines.join('\n')}`);
  }
}
