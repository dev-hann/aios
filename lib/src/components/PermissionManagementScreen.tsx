import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Folder, Bell, Contact, Phone, MessageSquare, Accessibility, Info } from 'lucide-react';
import { goBack } from './SettingsScreen';
import '../styles/settings.css';

interface PermissionDef {
  key: string;
  label: string;
  description: string;
  icon: typeof Folder;
}

const PERMISSIONS: PermissionDef[] = [
  { key: 'storage', label: '저장소', description: '파일 및 미디어 접근', icon: Folder },
  { key: 'notifications', label: '알림', description: '푸시 알림 수신', icon: Bell },
  { key: 'contacts', label: '연락처', description: '연락처 정보 접근', icon: Contact },
  { key: 'phone', label: '전화', description: '전화 걸기 및 상태 확인', icon: Phone },
  { key: 'sms', label: 'SMS', description: '문자 메시지 전송 및 수신', icon: MessageSquare },
  { key: 'accessibility', label: '접근성', description: '화면 읽기 및 제어', icon: Accessibility },
];

export function PermissionManagementScreen() {
  const navigate = useNavigate();

  return (
    <div className="settings-screen">
      <header className="settings-header">
        <button className="icon-btn" onClick={() => goBack(navigate)} aria-label="뒤로 가기">
          <ArrowLeft size={20} />
        </button>
        <h1>권한</h1>
      </header>

      <div className="settings-body">
        <div className="permission-banner info" role="status">
          <Info size={18} />
          <span>Gyo Bridge 연동 후 활성화됩니다</span>
        </div>

        {PERMISSIONS.map((perm) => {
          const Icon = perm.icon;
          return (
            <div key={perm.key} className="permission-card disabled" aria-disabled="true">
              <div className="permission-icon-wrap">
                <Icon size={20} />
              </div>
              <div className="permission-info">
                <div className="permission-label">{perm.label}</div>
                <div className="permission-desc">{perm.description}</div>
              </div>
              <span className="permission-pending-badge">준비 중</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
