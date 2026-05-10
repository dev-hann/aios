import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Sparkles, PlusCircle, MessageCircle, X, Settings } from 'lucide-react';
import { useChatStore } from '../stores/chat-store';
import '../styles/drawer.css';

interface Props {
  open: boolean;
  onClose: () => void;
}

function formatDate(ts: number): string {
  const now = Date.now();
  const diff = now - ts;
  const d = new Date(ts);
  const today = new Date();
  const isToday = d.toDateString() === today.toDateString();

  if (isToday) {
    return d.getHours().toString().padStart(2, '0') + ':' + d.getMinutes().toString().padStart(2, '0');
  }

  const days = Math.floor(diff / (1000 * 60 * 60 * 24));
  if (days < 7) return `${days}일 전`;

  return `${d.getMonth() + 1}/${d.getDate()}`;
}

export function SessionDrawer({ open, onClose }: Props) {
  const navigate = useNavigate();
  const {
    conversations,
    currentConversationId,
    switchConversation,
    deleteConversation,
    createConversation,
  } = useChatStore();

  const [deleteTarget, setDeleteTarget] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [open, onClose]);

  useEffect(() => {
    if (!deleteTarget) return;
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setDeleteTarget(null);
    };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [deleteTarget]);

  const handleNewChat = async () => {
    await createConversation();
    onClose();
  };

  const handleSelect = async (id: string) => {
    await switchConversation(id);
    onClose();
  };

  const handleDelete = async () => {
    if (!deleteTarget) return;
    await deleteConversation(deleteTarget);
    setDeleteTarget(null);
  };

  return (
    <>
      {open && (
        <div
          className="drawer-overlay"
          onClick={onClose}
          aria-hidden="true"
        />
      )}
      <nav
        className={`session-drawer ${open ? 'open' : ''}`}
        aria-label="세션 목록"
        aria-hidden={!open}
      >
        <div className="drawer-header">
          <div className="drawer-logo">
            <Sparkles size={20} />
          </div>
          <span className="drawer-title">AIOS</span>
          <button className="drawer-new-btn" onClick={handleNewChat} aria-label="새 대화 만들기">
            <PlusCircle size={24} />
          </button>
        </div>

        <div className="drawer-divider" />

        <ul className="session-list" role="list" style={{ listStyle: 'none' }}>
          {conversations.length === 0 && (
            <li className="session-empty">대화가 없습니다</li>
          )}
          {conversations.map((conv) => {
            const isActive = conv.id === currentConversationId;
            return (
              <li
                key={conv.id}
                className={`session-item ${isActive ? 'active' : ''}`}
                onClick={() => handleSelect(conv.id)}
                role="button"
                tabIndex={0}
                aria-current={isActive ? 'true' : undefined}
              >
                <span className={`session-icon ${isActive ? 'active-icon' : 'inactive-icon'}`}>
                  <MessageCircle size={18} />
                </span>
                <div className="session-content">
                  <div className="session-title">{conv.title}</div>
                  <div className="session-date">{formatDate(conv.updatedAt)}</div>
                </div>
                {!isActive && (
                  <button
                    className="delete-btn"
                    onClick={(e) => { e.stopPropagation(); setDeleteTarget(conv.id); }}
                    aria-label={`"${conv.title}" 대화 삭제`}
                  >
                    <X size={16} />
                  </button>
                )}
              </li>
            );
          })}
        </ul>

        <div className="drawer-divider" />
        <div className="drawer-footer">
          <button className="drawer-footer-btn" onClick={() => { onClose(); navigate('/settings'); }} aria-label="설정 열기">
            <Settings size={20} />
            설정
          </button>
        </div>
      </nav>

      {deleteTarget && (
        <div
          className="delete-dialog-overlay"
          onClick={() => setDeleteTarget(null)}
          role="dialog"
          aria-modal="true"
          aria-labelledby="delete-dialog-title"
        >
          <div className="delete-dialog" onClick={(e) => e.stopPropagation()}>
            <h3 id="delete-dialog-title">대화 삭제</h3>
            <p>"{conversations.find(c => c.id === deleteTarget)?.title}" 대화를 삭제하시겠습니까?</p>
            <div className="delete-dialog-actions">
              <button className="dialog-cancel" onClick={() => setDeleteTarget(null)}>취소</button>
              <button className="dialog-delete" onClick={handleDelete}>삭제</button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
