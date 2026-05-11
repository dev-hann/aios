import type { ToolResult } from '../types/agent';
import { toolResultOk, toolResultErr } from '../types/agent';
import { tryParseToolJson } from '../agent/tool-json-parser';
import type { AgentTool } from './types';
import type { AppLauncher } from '@gyo-framework/app-launcher';

type AppLauncherModule = typeof import('@gyo-framework/app-launcher');

let cachedModule: AppLauncherModule | null = null;

async function loadModule(): Promise<AppLauncherModule | null> {
  if (cachedModule) return cachedModule;
  try {
    cachedModule = await import('@gyo-framework/app-launcher');
    return cachedModule;
  } catch {
    return null;
  }
}

export function _resetModuleCache(): void {
  cachedModule = null;
}

export class AppLauncherTool implements AgentTool {
  readonly name = 'app_launcher';
  readonly description = 'List/open/search apps on device. Args: {action, packageName, url, query}';
  readonly parameters =
    '{"action": "list_apps|open_app|open_url|search_apps", ' +
    '"packageName": "string (for open_app)", ' +
    '"url": "string (for open_url)", ' +
    '"query": "string (for search_apps)"}';
  readonly toolPrompt =
    'Manage apps on the device.\n\n' +
    'Parameters: ' + this.parameters + '\n\n' +
    'Actions:\n' +
    '- list_apps: list all installed apps\n' +
    '- open_app: open an app by packageName\n' +
    '- open_url: open a URL in browser\n' +
    '- search_apps: search apps by name';

  async isAvailable(): Promise<boolean> {
    const launcher = await this.createLauncher();
    if (!launcher) return false;
    launcher.destroy();
    return true;
  }

  private async createLauncher(): Promise<AppLauncher | null> {
    const mod = await loadModule();
    if (!mod) return null;
    const launcher = new mod.AppLauncher();
    if (!launcher.isAvailable()) {
      launcher.destroy();
      return null;
    }
    return launcher;
  }

  async validate(args: string): Promise<string | null> {
    const json = tryParseToolJson(args);
    const action = (json['action'] as string)?.toLowerCase() ?? '';
    if (!['list_apps', 'open_app', 'open_url', 'search_apps'].includes(action))
      return `'${action || '(empty)'}' is not a valid action. Use list_apps, open_app, open_url, or search_apps.`;
    if (action === 'open_app' && !json['packageName'])
      return "'packageName' required for open_app action";
    if (action === 'open_url' && !json['url'])
      return "'url' required for open_url action";
    if (action === 'search_apps' && !json['query'])
      return "'query' required for search_apps action";
    return null;
  }

  async execute(args: string): Promise<ToolResult> {
    try {
      const launcher = await this.createLauncher();
      if (!launcher) return toolResultErr('App launcher not available (requires native bridge)');

      const json = tryParseToolJson(args);
      const action = (json['action'] as string)?.toLowerCase() ?? '';

      try {
        switch (action) {
          case 'list_apps': return await this.listApps(launcher);
          case 'open_app': return await this.openApp(launcher, json);
          case 'open_url': return await this.openUrl(launcher, json);
          case 'search_apps': return await this.searchApps(launcher, json);
          default: return toolResultErr(`Unknown action '${action}'. Use list_apps, open_app, open_url, or search_apps.`);
        }
      } finally {
        launcher.destroy();
      }
    } catch (e) {
      return toolResultErr(`${e}`);
    }
  }

  private async listApps(launcher: AppLauncher): Promise<ToolResult> {
    const result = await launcher.listApps();
    if (result.count === 0) return toolResultOk('No apps found');
    const lines = result.apps.map((app) => `- ${app.name} (${app.packageName})`);
    return toolResultOk(`${result.count} apps installed:\n${lines.join('\n')}`);
  }

  private async openApp(launcher: AppLauncher, json: Record<string, unknown>): Promise<ToolResult> {
    const packageName = (json['packageName'] as string) ?? '';
    if (!packageName) return toolResultErr("'packageName' required");
    const ok = await launcher.openApp({ packageName });
    return ok ? toolResultOk(`Opened ${packageName}`) : toolResultErr(`Failed to open ${packageName}`);
  }

  private async openUrl(launcher: AppLauncher, json: Record<string, unknown>): Promise<ToolResult> {
    const url = (json['url'] as string) ?? '';
    if (!url) return toolResultErr("'url' required");
    const ok = await launcher.openUrl({ url });
    return ok ? toolResultOk(`Opened ${url}`) : toolResultErr(`Failed to open ${url}`);
  }

  private async searchApps(launcher: AppLauncher, json: Record<string, unknown>): Promise<ToolResult> {
    const query = (json['query'] as string) ?? '';
    if (!query) return toolResultErr("'query' required");
    const result = await launcher.searchApps({ query });
    if (result.count === 0) return toolResultOk(`No apps matching '${query}'`);
    const lines = result.apps.map((app) => `- ${app.name} (${app.packageName})`);
    return toolResultOk(`${result.count} apps matching '${query}':\n${lines.join('\n')}`);
  }
}
