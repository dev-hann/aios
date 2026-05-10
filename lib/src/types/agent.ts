export type ToolRisk = 'safe' | 'low' | 'medium' | 'high' | 'critical';

export interface AgentStep {
  type: string;
  content: string;
  toolName?: string;
  toolArgs?: string;
  toolResult?: string;
  riskLevel?: string;
}

export interface AgentResult {
  steps: AgentStep[];
  success: boolean;
}

export interface ToolResult {
  output?: string;
  error?: string;
  system?: string;
  observation?: string;
}

export function toolResultOk(output: string, system?: string, observation?: string): ToolResult {
  return { output, system, observation };
}

export function toolResultErr(error: string): ToolResult {
  return { error };
}

export function isToolError(result: ToolResult): boolean {
  return result.error != null;
}

export function toContent(result: ToolResult): string {
  const parts: string[] = [];
  if (result.system) parts.push(`<system>${result.system}</system>`);
  if (result.error) {
    parts.push(`Error: ${result.error}`);
  } else if (result.output) {
    parts.push(result.output);
  }
  if (result.observation) parts.push(`Screen: ${result.observation}`);
  return parts.join('\n');
}

export type PermissionChecker = (permissionKey: string) => Promise<boolean>;
