import type { ToolResult } from '../types/agent';

export interface AgentTool {
  readonly name: string;
  readonly description: string;
  readonly parameters: string;
  readonly toolPrompt: string;
  execute(args: string): Promise<ToolResult>;
  validate?(args: string): Promise<string | null>;
}
