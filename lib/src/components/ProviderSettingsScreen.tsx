import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Cloud, KeyRound, Link, Wifi, BrainCircuit, CloudOff } from 'lucide-react';
import { useChatStore } from '../stores/chat-store';
import '../styles/settings.css';

const PROVIDER_TYPES = [
  { value: 'zai', label: 'Z.AI' },
  { value: 'zaiCoding', label: 'Z.AI (Coding)' },
  { value: 'custom', label: 'Custom' },
];

export function ProviderSettingsScreen() {
  const navigate = useNavigate();
  const {
    providerConfig,
    apiKey: savedApiKey,
    providerType: savedType,
    model: savedModel,
    availableModels,
    connectionTestResult,
    setProvider,
    disconnectProvider,
    fetchModels,
  } = useChatStore();

  const [type, setType] = useState(savedType || 'zaiCoding');
  const [apiKey, setApiKey] = useState(savedApiKey || '');
  const [baseUrl, setBaseUrl] = useState('');
  const [selectedModel, setSelectedModel] = useState(savedModel || '');
  const [testing, setTesting] = useState(false);

  useEffect(() => {
    if (providerConfig && availableModels.length === 0) {
      fetchModels();
    }
  }, []);

  const handleTest = async () => {
    if (!apiKey || !type) return;
    setTesting(true);

    const tempConfig = {
      providerType: type,
      apiKey,
      baseUrl: '',
      model: selectedModel || 'glm-4-flash',
    };

    const { createProviderConfig: create } = await import('../llm/types');
    const config = create(tempConfig.providerType, tempConfig.apiKey, tempConfig.baseUrl, tempConfig.model);

    const { OpenAiClient } = await import('../llm/openai-client');
    const client = new OpenAiClient(config);
    const ok = await client.testConnection();
    useChatStore.setState({
      connectionTestResult: { success: ok, message: ok ? '연결 성공' : '연결 실패' },
    });
    setTesting(false);
  };

  const handleSave = () => {
    if (!apiKey || !selectedModel) return;
    setProvider(type, apiKey, baseUrl, selectedModel);
    navigate(-1);
  };

  const handleDisconnect = () => {
    disconnectProvider();
    navigate(-1);
  };

  const handleFetchModels = async () => {
    if (!apiKey || !type) return;
    const { createProviderConfig: create } = await import('../llm/types');
    const config = create(type, apiKey, '', selectedModel || 'glm-4-flash');
    const { OpenAiClient } = await import('../llm/openai-client');
    const client = new OpenAiClient(config);
    const models = await client.fetchModels();
    useChatStore.setState({ availableModels: models });
  };

  return (
    <div className="settings-screen">
      <div className="settings-header">
        <button className="icon-btn" onClick={() => navigate(-1)}>
          <ArrowLeft size={20} />
        </button>
        <h1>AI 제공자 설정</h1>
      </div>

      <div className="provider-settings-body">
        <div className="section-card">
          <div className="section-header">
            <Cloud size={20} className="section-header-icon" />
            <span className="section-header-title">제공자 선택</span>
          </div>
          {PROVIDER_TYPES.map((pt) => (
            <label key={pt.value} className="radio-item" onClick={() => setType(pt.value)}>
              <div className={`radio-dot ${type === pt.value ? 'active' : ''}`} />
              <span>{pt.label}</span>
            </label>
          ))}
        </div>

        <div className="section-card">
          <div className="section-header">
            <KeyRound size={20} className="section-header-icon" />
            <span className="section-header-title">API 키</span>
          </div>
          <input
            type="password"
            className="settings-input"
            placeholder="API 키를 입력하세요"
            value={apiKey}
            onChange={(e) => setApiKey(e.target.value)}
          />
        </div>

        {type === 'custom' && (
          <div className="section-card">
            <div className="section-header">
              <Link size={20} className="section-header-icon" />
              <span className="section-header-title">Base URL</span>
            </div>
            <input
              type="text"
              className="settings-input"
              placeholder="https://api.example.com/v1"
              value={baseUrl}
              onChange={(e) => setBaseUrl(e.target.value)}
            />
          </div>
        )}

        <div className="section-card">
          <div className="section-header">
            <Wifi size={20} className="section-header-icon" />
            <span className="section-header-title">연결 테스트</span>
          </div>
          <button
            className="outlined-btn"
            onClick={handleTest}
            disabled={!apiKey || testing}
          >
            {testing ? '확인 중...' : '연결 테스트'}
          </button>
          {connectionTestResult && (
            <div className={`test-result ${connectionTestResult.success ? 'success' : 'failure'}`}>
              {connectionTestResult.message}
            </div>
          )}
        </div>

        <div className="section-card">
          <div className="section-header">
            <BrainCircuit size={20} className="section-header-icon" />
            <span className="section-header-title">모델</span>
          </div>
          <button className="outlined-btn" onClick={handleFetchModels} disabled={!apiKey} style={{ marginBottom: 'var(--spacing-s)' }}>
            모델 목록 새로고침
          </button>
          {availableModels.length === 0 && (
            <div style={{ color: 'var(--color-text-secondary)', fontSize: '13px' }}>
              API 키를 입력하면 모델을 불러옵니다
            </div>
          )}
          {availableModels.map((m) => (
            <label key={m.id} className="model-item" onClick={() => setSelectedModel(m.id)}>
              <div className={`radio-dot ${selectedModel === m.id ? 'active' : ''}`} />
              <div>
                <div className={`model-item-name ${selectedModel === m.id ? 'selected' : ''}`}>
                  {m.id}
                </div>
              </div>
            </label>
          ))}
          {!selectedModel && availableModels.length === 0 && (
            <input
              type="text"
              className="settings-input"
              placeholder="모델명 입력 (예: glm-4-flash)"
              value={selectedModel}
              onChange={(e) => setSelectedModel(e.target.value)}
              style={{ marginTop: 'var(--spacing-s)' }}
            />
          )}
        </div>

        {providerConfig && (
          <div className="section-card">
            <button className="disconnect-btn" onClick={handleDisconnect}>
              <CloudOff size={18} />
              연결 끊기
            </button>
          </div>
        )}

        <div style={{ padding: '0 var(--spacing-l) var(--spacing-xxl)' }}>
          <button
            className="elevated-btn"
            onClick={handleSave}
            disabled={!apiKey || !selectedModel}
          >
            {providerConfig ? '저장' : '연결'}
          </button>
        </div>
      </div>
    </div>
  );
}
