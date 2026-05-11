import type { ToolResult } from '../types/agent';
import { toolResultOk, toolResultErr } from '../types/agent';
import { tryParseToolJson } from '../agent/tool-json-parser';
import type { AgentTool } from './types';
import type { ContactSearch as ContactSearchClient } from '@gyo-framework/contact-search';

type ContactSearchModule = typeof import('@gyo-framework/contact-search');

let cachedModule: ContactSearchModule | null = null;

async function loadModule(): Promise<ContactSearchModule | null> {
  if (cachedModule) return cachedModule;
  try {
    cachedModule = await import('@gyo-framework/contact-search');
    return cachedModule;
  } catch {
    return null;
  }
}

export function _resetModuleCache(): void {
  cachedModule = null;
}

export class ContactSearchTool implements AgentTool {
  readonly name = 'contact_search';
  readonly description = 'Search contacts on device. Args: {action, query}';
  readonly parameters =
    '{"action": "search", "query": "string (search term)"}';
  readonly toolPrompt =
    'Search contacts on the device.\n\n' +
    'Parameters: ' + this.parameters + '\n\n' +
    'Actions:\n' +
    '- search: search contacts by name or phone number';

  async isAvailable(): Promise<boolean> {
    const client = await this.createClient();
    if (!client) return false;
    client.destroy();
    return true;
  }

  private async createClient(): Promise<ContactSearchClient | null> {
    const mod = await loadModule();
    if (!mod) return null;
    const client = new mod.ContactSearch();
    if (!client.isAvailable()) {
      client.destroy();
      return null;
    }
    return client;
  }

  async validate(args: string): Promise<string | null> {
    const json = tryParseToolJson(args);
    const action = (json['action'] as string)?.toLowerCase() ?? '';
    if (!['search'].includes(action))
      return `'${action || '(empty)'}' is not a valid action. Use search.`;
    if (action === 'search' && !json['query'])
      return "'query' required for search action";
    return null;
  }

  async execute(args: string): Promise<ToolResult> {
    try {
      const client = await this.createClient();
      if (!client) return toolResultErr('Contact search not available (requires native bridge)');

      const json = tryParseToolJson(args);
      const action = (json['action'] as string)?.toLowerCase() ?? '';

      try {
        switch (action) {
          case 'search': return await this.searchContacts(client, json);
          default: return toolResultErr(`Unknown action '${action}'. Use search.`);
        }
      } finally {
        client.destroy();
      }
    } catch (e) {
      return toolResultErr(`${e}`);
    }
  }

  private async searchContacts(client: ContactSearchClient, json: Record<string, unknown>): Promise<ToolResult> {
    const query = (json['query'] as string) ?? '';
    if (!query) return toolResultErr("'query' required");
    const result = await client.search({ query });
    if (result.count === 0) return toolResultOk(`No contacts matching '${query}'`);
    const lines = result.contacts.map((c) => {
      const phones = c.phoneNumbers.length > 0 ? ` [${c.phoneNumbers.join(', ')}]` : '';
      const emails = c.emails.length > 0 ? ` {${c.emails.join(', ')}}` : '';
      return `- ${c.name}${phones}${emails}`;
    });
    return toolResultOk(`${result.count} contacts matching '${query}':\n${lines.join('\n')}`);
  }
}
