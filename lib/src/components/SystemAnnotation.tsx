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

function getLabel(step: AgentStep): string {
  switch (step.type) {
    case 'phase0_classifying': return step.content || '분류 중...';
    case 'phase0_result': return step.content;
    case 'phase0_retry': return step.content;
    case 'phase1_retry': return step.content;
    case 'phase_answer': return step.content;
    case 'phase_answer_retry': return step.content;
    case 'action': return `${step.toolName} 실행 중...`;
    case 'tool_call_start': return `${step.toolName} 준비 중...`;
    case 'continuation': return step.content || '계속 생성 중...';
    case 'observation':
      return step.content.length > 100
        ? `결과: ${step.content.substring(0, 100)}...`
        : `결과: ${step.content}`;
    case 'confirmation_required':
      return `사용자 확인 대기 중... (${step.toolName})`;
    case 'permission_required':
      return `${step.toolName} 권한이 필요합니다`;
    default: return step.content;
  }
}

export function SystemAnnotation({ step }: Props) {
  if (HIDDEN_TYPES.includes(step.type)) return null;

  const Icon = getIcon(step.type);
  const label = getLabel(step);

  return (
    <div className="system-annotation" role="status" aria-label={label}>
      <Icon size={12} className="system-annotation-icon" aria-hidden="true" />
      <span className="system-annotation-text">{label}</span>
    </div>
  );
}
