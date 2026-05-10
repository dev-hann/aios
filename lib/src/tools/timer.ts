import type { ToolResult } from '../types/agent';
import { toolResultOk, toolResultErr } from '../types/agent';
import { tryParseToolJson, parseIntDynamic } from '../agent/tool-json-parser';
import type { AgentTool } from './types';

interface TimerEntry {
  startedAt: number;
  durationSeconds: number;
}

export class TimerTool implements AgentTool {
  readonly name = 'timer';
  readonly description = 'Set/check/cancel countdown timers. Args: {action, seconds, name}';
  readonly parameters = '{"action": "set|check|cancel|list", "seconds": "int 1-300", "name": "string (optional)"}';
  readonly toolPrompt =
    'Manage timers (max 300s).\n\n' +
    'Parameters: ' + this.parameters + '\n\n' +
    'Actions:\n- set: start timer. Requires "seconds" (1-300)\n- check: show remaining\n- cancel: stop\n- list: show active';

  private timers = new Map<string, TimerEntry>();

  async execute(args: string): Promise<ToolResult> {
    try {
      const json = tryParseToolJson(args);
      const action = (json['action'] as string)?.toLowerCase() ?? '';
      switch (action) {
        case 'set': return this.set(json);
        case 'check': return this.check(json);
        case 'cancel': return this.cancel(json);
        case 'list': return this.list();
        case '': return toolResultErr("'action' required. Use set, check, cancel, or list.");
        default: return toolResultErr(`Unknown action '${action}'`);
      }
    } catch (e) {
      return toolResultErr(`${e}`);
    }
  }

  private set(json: Record<string, unknown>): ToolResult {
    const secs = parseIntDynamic(json['seconds']) ?? 0;
    if (secs <= 0 || secs > 300) return toolResultErr("'seconds' must be 1-300");
    const name = (json['name'] as string) ?? 'default';
    this.timers.set(name, { startedAt: Date.now(), durationSeconds: secs });
    return toolResultOk(`Timer "${name}" set for ${secs} seconds`);
  }

  private check(json: Record<string, unknown>): ToolResult {
    const name = (json['name'] as string) ?? 'default';
    const timer = this.timers.get(name);
    if (!timer) return toolResultErr('No timer found');
    const remaining = this.getRemaining(timer);
    if (remaining <= 0) {
      this.timers.delete(name);
      return toolResultOk(`Timer "${name}" has expired`);
    }
    return toolResultOk(`Timer "${name}": ${remaining} seconds remaining`);
  }

  private cancel(json: Record<string, unknown>): ToolResult {
    const name = (json['name'] as string) ?? 'default';
    if (this.timers.delete(name)) return toolResultOk(`Cancelled timer "${name}"`);
    return toolResultErr('No timer found');
  }

  private list(): ToolResult {
    const expired: string[] = [];
    for (const [name, entry] of this.timers) {
      if (this.getRemaining(entry) <= 0) expired.push(name);
    }
    for (const name of expired) this.timers.delete(name);
    if (this.timers.size === 0) return toolResultOk('No active timers');
    const lines = [...this.timers.entries()].map(
      ([name, entry]) => `- ${name}: ${this.getRemaining(entry)}s remaining (${entry.durationSeconds}s total)`,
    );
    return toolResultOk(lines.join('\n'));
  }

  private getRemaining(entry: TimerEntry): number {
    const elapsed = Math.floor((Date.now() - entry.startedAt) / 1000);
    return Math.max(0, entry.durationSeconds - elapsed);
  }
}
