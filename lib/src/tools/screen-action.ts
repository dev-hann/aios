import type { ToolResult } from '../types/agent';
import { toolResultOk, toolResultErr } from '../types/agent';
import { tryParseToolJson } from '../agent/tool-json-parser';
import type { AgentTool } from './types';
import type { ScreenAction as ScreenActionClient } from '@gyo-framework/screen-action';

type ScreenActionModule = typeof import('@gyo-framework/screen-action');

let cachedModule: ScreenActionModule | null = null;

async function loadModule(): Promise<ScreenActionModule | null> {
  if (cachedModule) return cachedModule;
  try {
    cachedModule = await import('@gyo-framework/screen-action');
    return cachedModule;
  } catch {
    return null;
  }
}

export function _resetModuleCache(): void {
  cachedModule = null;
}

export class ScreenActionTool implements AgentTool {
  readonly name = 'screen_action';
  readonly description = 'Perform screen actions: tap, type, swipe, global. Args: {action, x, y, text, startX, startY, endX, endY, duration}';
  readonly parameters =
    '{"action": "tap|type|swipe|global", ' +
    '"x": "number, y: number (for tap)", ' +
    '"text": "string (for type)", ' +
    '"startX": "number, startY: number, endX: number, endY: number, duration: number (for swipe)", ' +
    '"globalAction": "string (for global: back, home, recents, notifications, quick_settings)"}';
  readonly toolPrompt =
    'Perform screen interaction actions via accessibility.\n\n' +
    'Parameters: ' + this.parameters + '\n\n' +
    'Actions:\n' +
    '- tap: tap at coordinates (requires x, y)\n' +
    '- type: type text into focused field (requires text)\n' +
    '- swipe: swipe from start to end (requires startX, startY, endX, endY, duration)\n' +
    '- global: perform global action via globalAction param (back, home, recents, notifications, quick_settings)';

  async isAvailable(): Promise<boolean> {
    const client = await this.createClient();
    if (!client) return false;
    client.destroy();
    return true;
  }

  private async createClient(): Promise<ScreenActionClient | null> {
    const mod = await loadModule();
    if (!mod) return null;
    const client = new mod.ScreenAction();
    if (!client.isAvailable()) {
      client.destroy();
      return null;
    }
    return client;
  }

  async validate(args: string): Promise<string | null> {
    const json = tryParseToolJson(args);
    const action = (json['action'] as string)?.toLowerCase() ?? '';
    if (!['tap', 'type', 'swipe', 'global'].includes(action))
      return `'${action || '(empty)'}' is not a valid action. Use tap, type, swipe, or global.`;
    if (action === 'tap' && (json['x'] == null || json['y'] == null))
      return "'x' and 'y' required for tap action";
    if (action === 'type' && !json['text'])
      return "'text' required for type action";
    if (action === 'swipe' && (json['startX'] == null || json['startY'] == null || json['endX'] == null || json['endY'] == null))
      return "'startX', 'startY', 'endX', 'endY' required for swipe action";
    if (action === 'global' && !json['globalAction'])
      return "'globalAction' required for global action";
    return null;
  }

  async execute(args: string): Promise<ToolResult> {
    try {
      const client = await this.createClient();
      if (!client) return toolResultErr('Screen action not available (requires native bridge)');

      const json = tryParseToolJson(args);
      const action = (json['action'] as string)?.toLowerCase() ?? '';

      try {
        switch (action) {
          case 'tap': return await this.tap(client, json);
          case 'type': return await this.type(client, json);
          case 'swipe': return await this.swipe(client, json);
          case 'global': return await this.globalAction(client, json);
          default: return toolResultErr(`Unknown action '${action}'. Use tap, type, swipe, or global.`);
        }
      } finally {
        client.destroy();
      }
    } catch (e) {
      return toolResultErr(`${e}`);
    }
  }

  private async tap(client: ScreenActionClient, json: Record<string, unknown>): Promise<ToolResult> {
    const x = Number(json['x']);
    const y = Number(json['y']);
    if (isNaN(x) || isNaN(y)) return toolResultErr("'x' and 'y' must be numbers");
    const ok = await client.tap({ x, y });
    return ok ? toolResultOk(`Tapped at (${x}, ${y})`) : toolResultErr(`Failed to tap at (${x}, ${y})`);
  }

  private async type(client: ScreenActionClient, json: Record<string, unknown>): Promise<ToolResult> {
    const text = (json['text'] as string) ?? '';
    if (!text) return toolResultErr("'text' required");
    const ok = await client.type({ text });
    return ok ? toolResultOk(`Typed: "${text}"`) : toolResultErr(`Failed to type text`);
  }

  private async swipe(client: ScreenActionClient, json: Record<string, unknown>): Promise<ToolResult> {
    const startX = Number(json['startX']);
    const startY = Number(json['startY']);
    const endX = Number(json['endX']);
    const endY = Number(json['endY']);
    const duration = Number(json['duration']) || 300;
    if (isNaN(startX) || isNaN(startY) || isNaN(endX) || isNaN(endY))
      return toolResultErr("'startX', 'startY', 'endX', 'endY' must be numbers");
    const ok = await client.swipe({ startX, startY, endX, endY, duration });
    return ok
      ? toolResultOk(`Swiped from (${startX}, ${startY}) to (${endX}, ${endY})`)
      : toolResultErr(`Failed to swipe`);
  }

  private async globalAction(client: ScreenActionClient, json: Record<string, unknown>): Promise<ToolResult> {
    const globalAction = (json['globalAction'] as string) ?? '';
    if (!globalAction) return toolResultErr("'globalAction' required");
    const ok = await client.globalAction({ action: globalAction });
    return ok ? toolResultOk(`Global action: ${globalAction}`) : toolResultErr(`Failed to perform global action: ${globalAction}`);
  }
}
