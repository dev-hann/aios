import { useState, useRef, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Menu, MessageSquarePlus, Sparkles, Cloud, AlertCircle, Shield } from 'lucide-react';
import { useChatStore } from '../stores/chat-store';
import { MessageBubble } from './MessageBubble';
import { InputBar } from './InputBar';
import { SessionDrawer } from './SessionDrawer';
import { SystemAnnotation } from './SystemAnnotation';
import '../styles/chat.css';
import '../styles/confirmation-dialog.css';

const SUGGESTIONS = [
  '오늘 날씨 어때?',
  '123 x 456 계산해줘',
  '메모해줘: 내일 회의 2시',
  '타이머 5분 설정해줘',
  '스크린샷 찍어줘',
];

export function ChatScreen() {
  const navigate = useNavigate();
  const {
    messages,
    agentSteps,
    serviceState,
    isConfirming,
    pendingToolName,
    pendingToolArgs,
    providerConfig,
    errorMessage,
    currentConversationTitle,
    streamingContent,
    isStreamingText,
    sendMessage,
    cancelGeneration,
    resolveConfirmation,
    createConversation,
    initializeSession,
  } = useChatStore();

  const [drawerOpen, setDrawerOpen] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const messagesAreaRef = useRef<HTMLElement>(null);
  const userScrolledUp = useRef(false);

  const handleScroll = useCallback(() => {
    const el = messagesAreaRef.current;
    if (!el) return;
    const distFromBottom = el.scrollHeight - el.scrollTop - el.clientHeight;
    userScrolledUp.current = distFromBottom > 80;
  }, []);

  useEffect(() => {
    initializeSession();
  }, [initializeSession]);

  useEffect(() => {
    if (userScrolledUp.current) return;
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, agentSteps, streamingContent]);

  useEffect(() => {
    if (!isConfirming) return;
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') resolveConfirmation(false);
    };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [isConfirming, resolveConfirmation]);

  const handleSend = (text: string) => {
    if (text.trim()) sendMessage(text.trim());
  };

  const isGenerating = serviceState.status === 'generating';
  const visibleSteps = agentSteps.filter(
    (s) => !['thought', 'thinking_start', 'thinking_end', 'streaming_text'].includes(s.type),
  );
  const isThinking = isGenerating && !isConfirming && !isStreamingText;
  const thoughtSteps = agentSteps.filter((s) => s.type === 'thought');
  const latestThought = thoughtSteps.length > 0 ? thoughtSteps[thoughtSteps.length - 1] : null;
  const thinkingLabel = latestThought?.content ?? '생각 중...';

  return (
    <main className="chat-screen">
      <SessionDrawer open={drawerOpen} onClose={() => setDrawerOpen(false)} />

      <header className="chat-header">
        <div className="chat-header-left">
          <button className="icon-btn" onClick={() => setDrawerOpen(true)} aria-label="메뉴 열기">
            <Menu size={20} />
          </button>
          <span className="chat-header-title">
            {currentConversationTitle || 'AIOS'}
          </span>
        </div>
        <div className="chat-header-actions">
          <div
            className={`connection-badge ${providerConfig ? 'connected' : 'disconnected'}`}
            onClick={() => navigate('/settings/provider')}
            role="status"
            aria-label={providerConfig ? `연결됨: ${providerConfig.model}` : 'AI 설정 필요'}
          >
            <div className="connection-dot" />
            {providerConfig ? providerConfig.model : 'AI 설정 필요'}
          </div>
          <button
            className="icon-btn"
            onClick={() => createConversation()}
            aria-label="새 대화"
          >
            <MessageSquarePlus size={20} />
          </button>
        </div>
      </header>

      {errorMessage && (
        <div className="error-bar" role="alert">
          <AlertCircle size={16} style={{ color: 'var(--color-error)', flexShrink: 0 }} />
          <span style={{ color: 'var(--color-error)', fontSize: '13px' }}>{errorMessage}</span>
        </div>
      )}

      <section className="messages-area" ref={messagesAreaRef} onScroll={handleScroll} aria-label="메시지">
        {messages.length === 0 && providerConfig && (
          <div className="empty-state">
            <div className="welcome-icon">
              <Sparkles size={36} />
            </div>
            <h2>AIOS</h2>
            <span className="subtitle">무엇을 도와드릴까요?</span>
            <div className="suggestions">
              {SUGGESTIONS.map((s) => (
                <button key={s} className="suggestion-chip" onClick={() => handleSend(s)}>
                  {s}
                </button>
              ))}
            </div>
          </div>
        )}

        {messages.length === 0 && !providerConfig && (
          <div className="empty-state">
            <div className="welcome-icon">
              <Sparkles size={36} />
            </div>
            <h2>AIOS</h2>
            <span className="subtitle">AI 어시스턴트</span>
            <div className="setup-prompt">
              <button className="elevated-btn" onClick={() => navigate('/settings/provider')}>
                <Cloud size={18} />
                AI 설정하기
              </button>
            </div>
          </div>
        )}

        {messages.map((msg) => (
          <MessageBubble
            key={msg.id}
            role={msg.role}
            content={msg.content}
            createdAt={msg.createdAt}
            toolName={msg.toolName}
            toolArgs={msg.toolArgs}
            toolResult={msg.toolResult}
          />
        ))}

        {isStreamingText && streamingContent && (
          <MessageBubble
            role="assistant"
            content={streamingContent}
            createdAt={Date.now()}
            isStreaming={true}
          />
        )}

        {visibleSteps.map((step, i) => (
          <SystemAnnotation key={`step-${i}`} step={step} />
        ))}

        {isThinking && (
          <div className="thinking-indicator" role="status" aria-label="AI가 생각 중입니다">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--color-primary)" strokeWidth="2">
              <path d="M21 12a9 9 0 1 1-6.219-8.56" />
            </svg>
            <span className="thinking-text">{thinkingLabel}</span>
          </div>
        )}

        <div ref={messagesEndRef} />
      </section>

      {isConfirming && (
        <div
          className="confirmation-overlay"
          role="dialog"
          aria-modal="true"
          aria-labelledby="confirm-title"
        >
          <div className="confirmation-dialog">
            <div className="confirmation-title" id="confirm-title">
              <Shield size={20} style={{ color: 'var(--color-warning)' }} />
              실행 확인
            </div>
            <div className="confirmation-tool">도구: {pendingToolName}</div>
            <div className="confirmation-args">{pendingToolArgs}</div>
            <div className="confirmation-actions">
              <button className="btn-deny" onClick={() => resolveConfirmation(false)}>
                거부
              </button>
              <button className="btn-approve" onClick={() => resolveConfirmation(true)}>
                승인
              </button>
            </div>
          </div>
        </div>
      )}

      <InputBar
        onSend={handleSend}
        onStop={cancelGeneration}
        disabled={!providerConfig}
        isGenerating={isGenerating}
        placeholder={serviceState.label}
      />
    </main>
  );
}
