import type { AgentStep } from '../types/agent';
import {
  Search,
  CheckCircle2,
  RefreshCw,
  MessageCircle,
  Wrench,
  Shield,
  Lock,
  Circle,
} from 'lucide-react';
import '../styles/system-annotation.css';

interface Props {
  step: AgentStep;
  retryCount?: number;
}

const HIDDEN_TYPES = ['thought', 'thinking_start', 'thinking_end', 'streaming_text'];

function getIcon(type: string) {
  switch (type) {
    case 'phase0_classifying': return Search;
    case 'phase0_result': return CheckCircle2;
    case 'phase0_retry': return RefreshCw;
    case 'phase1_retry': return RefreshCw;
    case 'phase_answer': return MessageCircle;
    case 'phase_answer_retry': return RefreshCw;
    case 'action': return Wrench;
    case 'tool_call_start': return Wrench;
    case 'continuation': return RefreshCw;
    case 'observation': return CheckCircle2;
    case 'confirmation_required': return Shield;
    case 'permission_required': return Lock;
    default: return Circle;
  }
}

function getRiskIconClass(step: AgentStep): string {
  if (step.type === 'confirmation_required') {
    if (step.riskLevel === 'critical') return 'risk-critical';
    if (step.riskLevel === 'high') return 'risk-high';
  }
  if (step.type === 'observation' && step.content.startsWith('Error:')) {
    return 'observation-error';
  }
  return '';
}

function getLabel(step: AgentStep, retryCount?: number): string {
  switch (step.type) {
    case 'phase0_classifying': return step.content || '분류 중...';
    case 'phase0_result': return step.content;
    case 'phase0_retry':
    case 'phase1_retry':
    case 'phase_answer_retry': {
      const base = step.content;
      if (retryCount && retryCount > 1) {
        return `${base} (${retryCount}회차)`;
      }
      return base;
    }
    case 'phase_answer': return step.content;
    case 'action': return `${step.toolName} 실행 중...`;
    case 'tool_call_start': return `${step.toolName} 준비 중...`;
    case 'continuation': return step.content || '계속 생성 중...';
    case 'observation': {
      if (step.content.startsWith('Error:')) {
        const msg = step.content.substring(7).trim();
        const display = msg.length > 100 ? msg.substring(0, 100) + '...' : msg;
        return `실패: ${display}`;
      }
      return step.content.length > 100
        ? `결과: ${step.content.substring(0, 100)}...`
        : `결과: ${step.content}`;
    }
    case 'confirmation_required':
      return `사용자 확인 대기 중... (${step.toolName})`;
    case 'permission_required':
      return `${step.toolName} 권한이 필요합니다`;
    default: return step.content;
  }
}

export function SystemAnnotation({ step, retryCount }: Props) {
  if (HIDDEN_TYPES.includes(step.type)) return null;

  const Icon = getIcon(step.type);
  const label = getLabel(step, retryCount);
  const riskClass = getRiskIconClass(step);

  return (
    <div className="system-annotation" role="status" aria-label={label}>
      <Icon size={12} className={`system-annotation-icon ${riskClass}`} aria-hidden="true" />
      <span className="system-annotation-text">{label}</span>
    </div>
  );
}
