import type { ToolResult } from '../types/agent';
import { toolResultOk, toolResultErr } from '../types/agent';
import { tryParseToolJson } from '../agent/tool-json-parser';
import type { AgentTool } from './types';
import type { DeviceInfo as DeviceInfoClient, DeviceInfoType } from '@gyo-framework/device-info';

type DeviceInfoModule = typeof import('@gyo-framework/device-info');

let cachedModule: DeviceInfoModule | null = null;

async function loadModule(): Promise<DeviceInfoModule | null> {
  if (cachedModule) return cachedModule;
  try {
    cachedModule = await import('@gyo-framework/device-info');
    return cachedModule;
  } catch {
    return null;
  }
}

export function _resetModuleCache(): void {
  cachedModule = null;
}

export class DeviceInfoTool implements AgentTool {
  readonly name = 'device_info';
  readonly description = 'Get device information. Args: {action}';
  readonly parameters =
    '{"action": "get_info"}';
  readonly toolPrompt =
    'Get information about the device.\n\n' +
    'Parameters: ' + this.parameters + '\n\n' +
    'Actions:\n' +
    '- get_info: get device hardware and software info';

  async isAvailable(): Promise<boolean> {
    const client = await this.createClient();
    if (!client) return false;
    client.destroy();
    return true;
  }

  private async createClient(): Promise<DeviceInfoClient | null> {
    const mod = await loadModule();
    if (!mod) return null;
    const client = new mod.DeviceInfo();
    if (!client.isAvailable()) {
      client.destroy();
      return null;
    }
    return client;
  }

  async validate(args: string): Promise<string | null> {
    const json = tryParseToolJson(args);
    const action = (json['action'] as string)?.toLowerCase() ?? '';
    if (!['get_info'].includes(action))
      return `'${action || '(empty)'}' is not a valid action. Use get_info.`;
    return null;
  }

  async execute(args: string): Promise<ToolResult> {
    try {
      const client = await this.createClient();
      if (!client) return toolResultErr('Device info not available (requires native bridge)');

      const json = tryParseToolJson(args);
      const action = (json['action'] as string)?.toLowerCase() ?? '';

      try {
        switch (action) {
          case 'get_info': return await this.getInfo(client);
          default: return toolResultErr(`Unknown action '${action}'. Use get_info.`);
        }
      } finally {
        client.destroy();
      }
    } catch (e) {
      return toolResultErr(`${e}`);
    }
  }

  private async getInfo(client: DeviceInfoClient): Promise<ToolResult> {
    const result = await client.getInfo();
    const info: DeviceInfoType = result.info;
    const lines = [
      `Manufacturer: ${info.manufacturer}`,
      `Model: ${info.model}`,
      `Brand: ${info.brand}`,
      `Device: ${info.device}`,
      `Android Version: ${info.androidVersion}`,
      `SDK Version: ${info.sdkVersion}`,
      `Security Patch: ${info.securityPatch}`,
      `Screen: ${info.screenWidth}x${info.screenHeight} (${info.screenDensity}dpi)`,
      `Battery: ${info.batteryLevel}%${info.isCharging ? ' (charging)' : ''}`,
    ];
    return toolResultOk(`Device Info:\n${lines.join('\n')}`);
  }
}
