import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Cloud, CloudOff, Settings, SlidersHorizontal, ShieldCheck, ExternalLink, ChevronRight } from 'lucide-react';
import { useChatStore } from '../stores/chat-store';
import { getProviderLabel } from '../constants/providers';
import '../styles/settings.css';

function goBack(navigate: ReturnType<typeof useNavigate>) {
  if (window.history.length > 1) navigate(-1);
  else navigate('/');
}

export function SettingsScreen() {
  const navigate = useNavigate();
  const { providerConfig, inferenceConfig } = useChatStore();

  const version = '3.0.0';
  const subtitle = `온도 ${inferenceConfig.temperature.toFixed(2)} · 최대토큰 ${inferenceConfig.maxTokens}`;

  return (
    <div className="settings-screen">
      <header className="settings-header">
        <button className="icon-btn" onClick={() => goBack(navigate)} aria-label="뒤로 가기">
          <ArrowLeft size={20} />
        </button>
        <h1>설정</h1>
      </header>

      <div className="settings-body">
        <section className="section-card provider-card">
          <div className="section-header">
            <Cloud size={20} className="section-header-icon" />
            <span className="section-header-title">AI 제공자</span>
            <div className={`connection-indicator ${providerConfig ? 'connected' : 'disconnected'}`}>
              <div className="connection-indicator-dot" />
              {providerConfig ? '연결됨' : '미연결'}
            </div>
          </div>

          {providerConfig ? (
            <div className="provider-summary" onClick={() => navigate('/settings/provider')}>
              <div className="provider-summary-info">
                <div className="provider-summary-model">{providerConfig.model}</div>
                <div className="provider-summary-type">{getProviderLabel(providerConfig.providerType)}</div>
              </div>
              <ChevronRight size={18} className="provider-summary-chevron" aria-hidden="true" />
            </div>
          ) : (
            <div className="provider-setup-prompt">
              <div className="provider-setup-text">
                <CloudOff size={18} style={{ color: 'var(--color-text-secondary)' }} aria-hidden="true" />
                <span>AI를 사용하려면 제공자를 설정하세요</span>
              </div>
              <button className="elevated-btn" onClick={() => navigate('/settings/provider')}>
                <Settings size={18} />
                AI 설정하기
              </button>
            </div>
          )}
        </section>

        <nav className="nav-tile">
          <button className="nav-tile-btn" onClick={() => navigate('/settings/inference')}>
            <SlidersHorizontal size={20} className="nav-tile-icon" />
            <div className="nav-tile-content">
              <div>추론 설정</div>
              <div className="nav-tile-subtitle">{subtitle}</div>
            </div>
            <ChevronRight size={20} className="nav-tile-chevron" aria-hidden="true" />
          </button>
        </nav>

        <nav className="nav-tile">
          <button className="nav-tile-btn" onClick={() => navigate('/settings/permissions')}>
            <ShieldCheck size={20} className="nav-tile-icon" />
            <div className="nav-tile-content">
              <div>권한 관리</div>
              <div className="nav-tile-subtitle nav-tile-subtitle-disabled">Gyo Bridge 연동 후 활성화</div>
            </div>
            <ChevronRight size={20} className="nav-tile-chevron" aria-hidden="true" />
          </button>
        </nav>
      </div>

      <footer className="settings-footer">
        <div className="footer-row">
          <span className="footer-label">AIOS v{version}</span>
          <a
            className="footer-link"
            href="https://github.com/dev-hann/aios"
            target="_blank"
            rel="noopener noreferrer"
          >
            GitHub <ExternalLink size={12} />
          </a>
        </div>
      </footer>
    </div>
  );
}

export { goBack };
