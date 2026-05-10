import type { ToolResult } from '../types/agent';
import { toContent } from '../types/agent';

export type LoopCheckResult = LoopOk | LoopWarning | LoopForceBreak;

export interface LoopOk { type: 'ok' }
export interface LoopWarning { type: 'warning'; count: number; toolName: string }
export interface LoopForceBreak { type: 'forceBreak' }

export class LoopDetector {
  private actionHistory: Array<{ tool: string; argsCanonical: string }> = [];
  private observationHistory: string[] = [];
  private warningGiven = false;

  private loopOverrides: Record<string, string[]> = {
    screen_action: ['scroll', 'swipe', 'global'],
  };

  reset(): void {
    this.actionHistory = [];
    this.observationHistory = [];
    this.warningGiven = false;
  }

  record(toolName: string, args: string, result: ToolResult): LoopCheckResult {
    const canonical = this.canonicalizeArgs(args);
    const observation = toContent(result);
    this.actionHistory.push({ tool: toolName, argsCanonical: canonical });
    this.observationHistory.push(observation);

    const recentActions = this.actionHistory.slice(-3);
    const consecutiveDuplicates = recentActions.filter(
      (a) => a.tool === toolName && a.argsCanonical === canonical,
    ).length;

    const isRepeatedAction =
      consecutiveDuplicates >= 3 && !this.isActionAllowedRepeated(toolName, canonical);

    const consecutiveIdenticalObs =
      this.observationHistory.length >= 2 &&
      new Set(this.observationHistory.slice(-2)).size < 2;

    if (isRepeatedAction || consecutiveIdenticalObs) {
      if (this.warningGiven) {
        return { type: 'forceBreak' };
      }
      this.warningGiven = true;
      return { type: 'warning', count: consecutiveDuplicates, toolName };
    }

    return { type: 'ok' };
  }

  private canonicalizeArgs(args: string): string {
    try {
      const decoded = JSON.parse(args);
      if (typeof decoded !== 'object' || decoded === null) return args;
      const obj = decoded as Record<string, unknown>;
      return Object.keys(obj)
        .sort()
        .map((k) => `${k}=${obj[k]}`)
        .join(',');
    } catch {
      return args;
    }
  }

  private isActionAllowedRepeated(tool: string, argsCanonical: string): boolean {
    const overrides = this.loopOverrides[tool];
    if (!overrides) return false;
    return overrides.some((o) => argsCanonical.includes(o));
  }
}
