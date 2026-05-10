import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Cloud, CloudOff, CheckCircle, Settings, SlidersHorizontal, ShieldCheck, Info, ExternalLink, ChevronRight } from 'lucide-react';
import { useChatStore } from '../stores/chat-store';
import '../styles/settings.css';

export function SettingsScreen() {
  const navigate = useNavigate();
  const { providerConfig } = useChatStore();

  const version = '3.0.0';

  return (
    <div className="settings-screen">
      <div className="settings-header">
        <button className="icon-btn" onClick={() => navigate(-1)}>
          <ArrowLeft size={20} />
        </button>
        <h1>설정</h1>
      </div>

      <div className="settings-body">
        <div className="section-card">
          <div className="section-header">
            <Cloud size={20} className="section-header-icon" />
            <span className="section-header-title">AI 제공자</span>
          </div>
          {providerConfig ? (
            <div className="provider-status">
              <div className="provider-info">
                <div className="provider-model">{providerConfig.model}</div>
                <div className="provider-type">{providerConfig.providerType}</div>
              </div>
              <CheckCircle size={20} style={{ color: 'var(--color-success)' }} />
            </div>
          ) : (
            <div className="provider-disconnected">
              <div className="provider-disconnected-text">AI 제공자가 설정되지 않았습니다</div>
              <div className="provider-disconnected-text">AI를 사용하려면 설정이 필요합니다</div>
              <CloudOff size={20} style={{ color: 'var(--color-text-secondary)' }} />
            </div>
          )}
          <div style={{ marginTop: 'var(--spacing-m)' }}>
            <button className="outlined-btn" onClick={() => navigate('/settings/provider')}>
              <Settings size={18} />
              {providerConfig ? '제공자 설정' : 'AI 설정하기'}
            </button>
          </div>
        </div>

        <div className="nav-tile">
          <button className="nav-tile-btn" onClick={() => {}}>
            <SlidersHorizontal size={20} className="nav-tile-icon" />
            <div className="nav-tile-content">
              <div>추론 설정</div>
              <div className="nav-tile-subtitle">온도 0.7 · 최대토큰 4096</div>
            </div>
            <ChevronRight size={20} className="nav-tile-chevron" />
          </button>
        </div>

        <div className="nav-tile">
          <button className="nav-tile-btn" onClick={() => {}}>
            <ShieldCheck size={20} className="nav-tile-icon" />
            <div className="nav-tile-content">
              <div>권한 관리</div>
              <div className="nav-tile-subtitle">앱 권한 관리</div>
            </div>
            <ChevronRight size={20} className="nav-tile-chevron" />
          </button>
        </div>

        <div className="section-card">
          <div className="section-header">
            <Info size={20} className="section-header-icon" />
            <span className="section-header-title">앱 정보</span>
          </div>
          <div className="app-info-row">
            <span className="app-info-label">버전</span>
            <span className="app-info-label">{version}</span>
          </div>
          <div className="app-info-row" style={{ justifyContent: 'flex-start' }}>
            <a
              className="github-link"
              href="https://github.com/dev-hann/aios"
              target="_blank"
              rel="noopener noreferrer"
            >
              GitHub
              <ExternalLink size={16} className="github-link-icon" />
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}
