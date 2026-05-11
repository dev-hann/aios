import type { ToolRisk } from '../types/agent';

export class RiskClassifier {
  classify(toolName: string, args: string): ToolRisk {
    const json = JSON.parse(args || '{}') as Record<string, unknown>;
    const action = (json['action'] as string)?.toLowerCase() ?? '';

    switch (toolName) {
      case 'calculator':
      case 'timer':
      case 'device_info':
      case 'notepad':
      case 'screen_reader':
      case 'screen_find':
      case 'notification_reader':
      case 'contact_search':
        return 'safe';
      case 'app_launcher':
        return this.classifyAppLauncher(action);
      case 'screen_action':
        return this.classifyScreenAction(action, json);
      case 'sms_sender':
        return action === 'send' ? 'critical' : 'high';
      case 'phone_caller':
        return action === 'call' ? 'critical' : 'high';
      default:
        return 'high';
    }
  }

  private classifyAppLauncher(action: string): ToolRisk {
    if (['open_settings', 'list_apps'].includes(action)) return 'low';
    if (['open_app', 'open_url'].includes(action)) return 'high';
    return 'low';
  }

  private classifyScreenAction(action: string, json: Record<string, unknown>): ToolRisk {
    if (action === 'global') return 'low';
    if (action === 'type') {
      const content = (json['content'] as string)?.toLowerCase() ?? '';
      const sensitive = ['password', 'pin', 'passcode', 'ssn', 'credit card', 'cvv', 'otp'];
      if (sensitive.some((s) => content.includes(s))) return 'critical';
      return 'low';
    }
    return 'low';
  }
}
