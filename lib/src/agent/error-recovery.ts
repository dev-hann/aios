import type { ToolResult } from '../types/agent';
import { toContent, isToolError } from '../types/agent';

export enum ErrorType {
  ToolNotFound = 'toolNotFound',
  AppNotInstalled = 'appNotInstalled',
  ServiceUnavailable = 'serviceUnavailable',
  PermissionDenied = 'permissionDenied',
  InvalidAction = 'invalidAction',
  MissingParameter = 'missingParameter',
  Cancelled = 'cancelled',
  Generic = 'generic',
}

export interface RecoveryHint {
  type: ErrorType;
  userMessage: string;
  promptNudge: string;
  shouldRetry: boolean;
}

export class ErrorRecovery {
  private retryCount = new Map<string, number>();
  private _totalErrors = 0;
  private maxRetries = 1;

  reset(): void {
    this.retryCount.clear();
    this._totalErrors = 0;
  }

  get totalErrors(): number {
    return this._totalErrors;
  }

  canRetry(toolName: string): boolean {
    return (this.retryCount.get(toolName) ?? 0) < this.maxRetries;
  }

  analyze(toolName: string, _args: string, result: ToolResult): RecoveryHint | null {
    if (!isToolError(result) && !toContent(result).trimStart().startsWith('Error:')) return null;

    this._totalErrors++;
    const observation = toContent(result);
    const type = this.categorize(observation);
    const retryAvailable = this.canRetry(toolName);

    if (retryAvailable && this.isRetryable(type)) {
      this.retryCount.set(toolName, (this.retryCount.get(toolName) ?? 0) + 1);
      return {
        type,
        userMessage: this.userMessage(type),
        promptNudge: this.retryPromptNudge(toolName, type),
        shouldRetry: true,
      };
    }

    return {
      type,
      userMessage: this.userMessage(type),
      promptNudge: this.fallbackPromptNudge(type),
      shouldRetry: false,
    };
  }

  private categorize(observation: string): ErrorType {
    const lower = observation.toLowerCase();
    if (lower.includes('unknown tool')) return ErrorType.ToolNotFound;
    if (lower.includes('not installed') || lower.includes('no apps found')) return ErrorType.AppNotInstalled;
    if (lower.includes('accessibility') && lower.includes('not enabled')) return ErrorType.ServiceUnavailable;
    if (lower.includes('permission') || lower.includes('denied')) return ErrorType.PermissionDenied;
    if (lower.includes('unknown action')) return ErrorType.InvalidAction;
    if (lower.includes('required')) return ErrorType.MissingParameter;
    if (lower.includes('cancelled by user')) return ErrorType.Cancelled;
    return ErrorType.Generic;
  }

  private isRetryable(type: ErrorType): boolean {
    return [ErrorType.InvalidAction, ErrorType.MissingParameter, ErrorType.AppNotInstalled, ErrorType.Generic].includes(type);
  }

  private userMessage(type: ErrorType): string {
    const messages: Record<ErrorType, string> = {
      [ErrorType.ToolNotFound]: '요청한 도구를 찾을 수 없습니다.',
      [ErrorType.AppNotInstalled]: '해당 앱이 설치되어 있지 않습니다.',
      [ErrorType.ServiceUnavailable]: '필요한 서비스가 활성화되지 않았습니다.',
      [ErrorType.PermissionDenied]: '권한이 거부되었습니다.',
      [ErrorType.InvalidAction]: '잘못된 명령입니다.',
      [ErrorType.MissingParameter]: '필수 항목이 누락되었습니다.',
      [ErrorType.Cancelled]: '사용자가 작업을 취소했습니다.',
      [ErrorType.Generic]: '오류가 발생했습니다.',
    };
    return messages[type];
  }

  private retryPromptNudge(toolName: string, type: ErrorType): string {
    const nudges: Record<ErrorType, string> = {
      [ErrorType.AppNotInstalled]: 'RECOVERY: App not found. Try list_apps or explain it is not installed.',
      [ErrorType.InvalidAction]: `RECOVERY: Invalid action for ${toolName}. Check available actions and retry.`,
      [ErrorType.MissingParameter]: 'RECOVERY: Missing required parameter. Call the same tool again with correct parameters.',
      [ErrorType.Generic]: 'RECOVERY: Tool failed. Try different approach.',
      [ErrorType.ToolNotFound]: 'RECOVERY: Try again or Answer the user.',
      [ErrorType.ServiceUnavailable]: 'RECOVERY: Answer the user explaining they need to enable the service.',
      [ErrorType.PermissionDenied]: 'RECOVERY: Answer the user explaining they need to grant permission.',
      [ErrorType.Cancelled]: '',
    };
    return nudges[type];
  }

  private fallbackPromptNudge(type: ErrorType): string {
    const nudges: Record<ErrorType, string> = {
      [ErrorType.ToolNotFound]: 'RECOVERY: Unknown tool. Use available tools or Answer.',
      [ErrorType.ServiceUnavailable]: 'RECOVERY: Service unavailable. Explain to user.',
      [ErrorType.PermissionDenied]: 'RECOVERY: Permission denied. Explain to user.',
      [ErrorType.Cancelled]: '',
      [ErrorType.AppNotInstalled]: 'RECOVERY: Explain what happened.',
      [ErrorType.InvalidAction]: 'RECOVERY: Explain what happened.',
      [ErrorType.MissingParameter]: 'RECOVERY: Explain what happened.',
      [ErrorType.Generic]: 'RECOVERY: Explain what happened.',
    };
    return nudges[type];
  }
}
