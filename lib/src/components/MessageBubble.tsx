import { Wrench } from 'lucide-react';
import '../styles/message-bubble.css';

interface Props {
  role: string;
  content: string;
  createdAt: number;
  toolName?: string;
  toolArgs?: string;
  toolResult?: string;
  isStreaming?: boolean;
}

function formatTime(timestamp: number): string {
  const d = new Date(timestamp);
  const h = d.getHours().toString().padStart(2, '0');
  const m = d.getMinutes().toString().padStart(2, '0');
  return `${h}:${m}`;
}

export function MessageBubble({ role, content, createdAt, toolName, toolArgs, toolResult, isStreaming }: Props) {
  if (role === 'user') {
    return (
      <div className="message-bubble user">
        {content}
      </div>
    );
  }

  return (
    <div className="message-bubble assistant">
      {content && (
        <div className="message-text">
          {content}
          {isStreaming && <span className="streaming-cursor">▎</span>}
        </div>
      )}

      {toolName && (
        <div className="tool-info">
          <div className="tool-info-header">
            <Wrench size={14} style={{ color: 'var(--color-secondary)' }} />
            <span className="tool-info-name">{toolName}</span>
          </div>
          {toolArgs && (
            <div className="tool-info-args">{toolArgs}</div>
          )}
          {toolResult && (
            <div className="tool-info-result">
              <pre>{toolResult}</pre>
            </div>
          )}
        </div>
      )}

      <div className="message-timestamp">{formatTime(createdAt)}</div>
    </div>
  );
}
