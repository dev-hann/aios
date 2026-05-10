import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { Wrench, Sparkles } from 'lucide-react';
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
      <article className="message-bubble user" role="log">
        {content}
      </article>
    );
  }

  return (
    <article className="message-bubble assistant" role="log">
      <div className="assistant-avatar" aria-hidden="true">
        <Sparkles size={14} />
      </div>

      {content && (
        <div className="message-text markdown-body">
          <ReactMarkdown remarkPlugins={[remarkGfm]}>
            {content}
          </ReactMarkdown>
          {isStreaming && <span className="streaming-cursor" aria-hidden="true" />}
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
    </article>
  );
}
