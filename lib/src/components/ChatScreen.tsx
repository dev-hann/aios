import { useState, useRef, useEffect } from 'react';
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
    sendMessage,
    cancelGeneration,
    resolveConfirmation,
    createConversation,
    initializeSession,
  } = useChatStore();

  const [drawerOpen, setDrawerOpen] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    initializeSession();
  }, [initializeSession]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, agentSteps]);

  const handleSend = (text: string) => {
    if (text.trim()) sendMessage(text.trim());
  };

  const isGenerating = serviceState.status === 'generating';
  const isThinking = isGenerating && agentSteps.length > 0 && !isConfirming;
  const visibleSteps = agentSteps.filter(
    (s) => !['thought', 'thinking_start', 'thinking_end'].includes(s.type),
  );

  return (
    <div className="chat-screen">
      <SessionDrawer open={drawerOpen} onClose={() => setDrawerOpen(false)} />

      <div className="chat-header">
        <div className="chat-header-left">
          <button className="icon-btn" onClick={() => setDrawerOpen(true)}>
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
          >
            <div className="connection-dot" />
            {providerConfig ? providerConfig.model : 'AI 설정 필요'}
          </div>
          <button
            className="icon-btn"
            onClick={() => createConversation()}
            title="새 대화"
          >
            <MessageSquarePlus size={20} />
          </button>
        </div>
      </div>

      {errorMessage && (
        <div className="error-bar">
          <AlertCircle size={16} style={{ color: 'var(--color-error)', flexShrink: 0 }} />
          <span style={{ color: 'var(--color-error)', fontSize: '13px' }}>{errorMessage}</span>
        </div>
      )}

      <div className="messages-area">
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

        {visibleSteps.map((step, i) => (
          <SystemAnnotation key={`step-${i}`} step={step} />
        ))}

        {isThinking && (
          <div className="thinking-indicator">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--color-primary)" strokeWidth="2" style={{ opacity: 0.7 }}>
              <path d="M21 12a9 9 0 1 1-6.219-8.56" />
            </svg>
            <span className="thinking-text">생각 중...</span>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      {isConfirming && (
        <div className="confirmation-overlay">
          <div className="confirmation-dialog">
            <div className="confirmation-title">
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
    </div>
  );
}
