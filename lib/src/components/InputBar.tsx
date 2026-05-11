import { useState, useRef } from 'react';
import { ArrowUp, Square } from 'lucide-react';
import '../styles/input-bar.css';

interface Props {
  onSend: (text: string) => void;
  onStop: () => void;
  disabled?: boolean;
  isGenerating?: boolean;
  placeholder?: string;
}

export function InputBar({ onSend, onStop, disabled, isGenerating, placeholder }: Props) {
  const [text, setText] = useState('');
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const handleSubmit = () => {
    if (!text.trim() || disabled) return;
    onSend(text.trim());
    setText('');
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
  };

  const handleInput = () => {
    const el = textareaRef.current;
    if (el) {
      el.style.height = 'auto';
      el.style.height = Math.min(el.scrollHeight, 120) + 'px';
    }
  };

  return (
    <div className="input-bar" role="form" aria-label="메시지 입력">
      <textarea
        ref={textareaRef}
        value={text}
        onChange={(e) => setText(e.target.value)}
        onKeyDown={handleKeyDown}
        onInput={handleInput}
        placeholder={isGenerating ? '생성 중...' : (placeholder || '메시지를 입력하세요...')}
        disabled={disabled}
        rows={1}
        aria-label="메시지 입력"
      />
      {isGenerating ? (
        <button className="send-btn stop-btn" onClick={onStop} title="정지" aria-label="생성 중지">
          <Square size={20} />
        </button>
      ) : (
        <button
          className="send-btn"
          onClick={handleSubmit}
          disabled={disabled || !text.trim()}
          title="전송"
          aria-label="메시지 전송"
        >
          <ArrowUp size={20} />
        </button>
      )}
    </div>
  );
}
