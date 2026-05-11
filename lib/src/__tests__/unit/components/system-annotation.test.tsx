/**
 * @vitest-environment jsdom
 */
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { SystemAnnotation } from '../../../components/SystemAnnotation';
import type { AgentStep } from '../../../types/agent';

describe('SystemAnnotation', () => {
  it('hides thought type', () => {
    const step: AgentStep = { type: 'thought', content: 'thinking...' };
    const { container } = render(<SystemAnnotation step={step} />);
    expect(container.innerHTML).toBe('');
  });

  it('hides thinking_start type', () => {
    const step: AgentStep = { type: 'thinking_start', content: '' };
    const { container } = render(<SystemAnnotation step={step} />);
    expect(container.innerHTML).toBe('');
  });

  it('hides streaming_text type', () => {
    const step: AgentStep = { type: 'streaming_text', content: 'partial' };
    const { container } = render(<SystemAnnotation step={step} />);
    expect(container.innerHTML).toBe('');
  });

  it('renders action step with tool name', () => {
    const step: AgentStep = { type: 'action', content: 'Using tool: calculator', toolName: 'calculator' };
    const { getByText } = render(<SystemAnnotation step={step} />);
    expect(getByText('calculator 실행 중...')).toBeDefined();
  });

  it('renders observation with 결과 prefix', () => {
    const step: AgentStep = { type: 'observation', content: '42' };
    const { getByText } = render(<SystemAnnotation step={step} />);
    expect(getByText('결과: 42')).toBeDefined();
  });

  it('renders observation error with 실패 prefix', () => {
    const step: AgentStep = { type: 'observation', content: 'Error: division by zero' };
    const { getByText } = render(<SystemAnnotation step={step} />);
    expect(getByText('실패: division by zero')).toBeDefined();
  });

  it('renders observation error with icon error class', () => {
    const step: AgentStep = { type: 'observation', content: 'Error: something failed' };
    const { container } = render(<SystemAnnotation step={step} />);
    const icon = container.querySelector('.observation-error');
    expect(icon).not.toBeNull();
  });

  it('renders confirmation_required with risk-critical class', () => {
    const step: AgentStep = { type: 'confirmation_required', content: 'Confirm: sms_sender', toolName: 'sms_sender', riskLevel: 'critical' };
    const { container } = render(<SystemAnnotation step={step} />);
    const icon = container.querySelector('.risk-critical');
    expect(icon).not.toBeNull();
  });

  it('renders confirmation_required with risk-high class', () => {
    const step: AgentStep = { type: 'confirmation_required', content: 'Confirm: screen_action', toolName: 'screen_action', riskLevel: 'high' };
    const { container } = render(<SystemAnnotation step={step} />);
    const icon = container.querySelector('.risk-high');
    expect(icon).not.toBeNull();
  });

  it('renders confirmation_required without risk class for safe', () => {
    const step: AgentStep = { type: 'confirmation_required', content: 'Confirm: tool', toolName: 'tool', riskLevel: 'safe' };
    const { container } = render(<SystemAnnotation step={step} />);
    expect(container.querySelector('.risk-high')).toBeNull();
    expect(container.querySelector('.risk-critical')).toBeNull();
  });

  it('renders retry without count when retryCount is 1', () => {
    const step: AgentStep = { type: 'phase1_retry', content: '재시도 중...' };
    const { getByText } = render(<SystemAnnotation step={step} retryCount={1} />);
    expect(getByText('재시도 중...')).toBeDefined();
  });

  it('renders retry with count when retryCount > 1', () => {
    const step: AgentStep = { type: 'phase1_retry', content: '재시도 중...' };
    const { getByText } = render(<SystemAnnotation step={step} retryCount={3} />);
    expect(getByText('재시도 중... (3회차)')).toBeDefined();
  });

  it('truncates long observation content', () => {
    const longContent = 'a'.repeat(150);
    const step: AgentStep = { type: 'observation', content: longContent };
    const { getByText } = render(<SystemAnnotation step={step} />);
    const text = getByText(/결과: a+\.\.\./);
    expect(text).toBeDefined();
    expect(text.textContent!.length).toBeLessThan(120);
  });

  it('truncates long error content in observation', () => {
    const longError = 'Error: ' + 'b'.repeat(150);
    const step: AgentStep = { type: 'observation', content: longError };
    const { getByText } = render(<SystemAnnotation step={step} />);
    const text = getByText(/실패: b+\.\.\./);
    expect(text).toBeDefined();
  });

  it('renders confirmation_required with tool name', () => {
    const step: AgentStep = { type: 'confirmation_required', content: 'Confirm: calculator', toolName: 'calculator' };
    const { getByText } = render(<SystemAnnotation step={step} />);
    expect(getByText('사용자 확인 대기 중... (calculator)')).toBeDefined();
  });

  it('renders permission_required with tool name', () => {
    const step: AgentStep = { type: 'permission_required', content: '', toolName: 'screen_reader' };
    const { getByText } = render(<SystemAnnotation step={step} />);
    expect(getByText('screen_reader 권한이 필요합니다')).toBeDefined();
  });
});
