import { useState, useEffect, useRef, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Cloud, KeyRound, Link, BrainCircuit, CloudOff, Eye, EyeOff, Loader2 } from 'lucide-react';
import { useChatStore } from '../stores/chat-store';
import { PROVIDER_TYPES } from '../constants/providers';
import { goBack } from './SettingsScreen';
import '../styles/settings.css';


export function ProviderSettingsScreen() {
  const navigate = useNavigate();
  const {
    providerConfig,
    apiKey: savedApiKey,
    providerType: savedType,
    model: savedModel,
    availableModels,
    setProvider,
    disconnectProvider,
  } = useChatStore();

  const [type, setType] = useState(savedType || 'zaiCoding');
  const [apiKey, setApiKey] = useState(savedApiKey || '');
  const [showKey, setShowKey] = useState(false);
  const [baseUrl, setBaseUrl] = useState('');
  const [selectedModel, setSelectedModel] = useState(savedModel || '');
  const [testing, setTesting] = useState(false);
  const [modelsLoading, setModelsLoading] = useState(false);
  const [modelsError, setModelsError] = useState('');
  const [saveError, setSaveError] = useState('');
  const debounceRef = useRef<ReturnType<typeof setTimeout>>();

  const fetchModelList = useCallback(async (key: string, providerType: string) => {
    if (!key || !providerType) return;
    setModelsLoading(true);
    setModelsError('');
    try {
      const { createProviderConfig: create } = await import('../llm/types');
      const config = create(providerType, key, '', 'glm-4-flash');
      const { OpenAiClient } = await import('../llm/openai-client');
      const client = new OpenAiClient(config);
      const models = await client.fetchModels();
      useChatStore.setState({ availableModels: models });
      if (models.length > 0 && !selectedModel) {
        setSelectedModel(models[0].id);
      }
      if (models.length === 0) {
        setModelsError('사용 가능한 모델이 없습니다. API 키를 확인하세요.');
      }
    } catch {
      useChatStore.setState({ availableModels: [] });
      setModelsError('모델 목록을 불러오지 못했습니다. 네트워크를 확인하세요.');
    } finally {
      setModelsLoading(false);
    }
  }, [selectedModel]);

  useEffect(() => {
    if (providerConfig && availableModels.length === 0) {
      fetchModelList(savedApiKey || '', savedType || 'zaiCoding');
    }
  }, []);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (!apiKey || !type) return;
    debounceRef.current = setTimeout(() => {
      fetchModelList(apiKey, type);
    }, 500);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [apiKey, type]);

  const handleSave = async () => {
    if (!apiKey || !selectedModel) return;
    setSaveError('');
    setTesting(true);

    try {
      const { createProviderConfig: create } = await import('../llm/types');
      const config = create(type, apiKey, baseUrl, selectedModel);
      const { OpenAiClient } = await import('../llm/openai-client');
      const client = new OpenAiClient(config);
      const ok = await client.testConnection();

      if (!ok) {
        setSaveError('연결 테스트에 실패했습니다. API 키와 모델을 확인하세요.');
        setTesting(false);
        return;
      }

      setProvider(type, apiKey, baseUrl, selectedModel);
      setTesting(false);
      goBack(navigate);
    } catch {
      setSaveError('연결 중 오류가 발생했습니다.');
      setTesting(false);
    }
  };

  const handleDisconnect = () => {
    disconnectProvider();
    goBack(navigate);
  };

  return (
    <div className="settings-screen">
      <header className="settings-header">
        <button className="icon-btn" onClick={() => goBack(navigate)} aria-label="뒤로 가기">
          <ArrowLeft size={20} />
        </button>
        <h1>AI 제공자 설정</h1>
      </header>

      <div className="provider-settings-body">
        <section className="section-card">
          <div className="section-header">
            <Cloud size={20} className="section-header-icon" />
            <span className="section-header-title">제공자 선택</span>
          </div>
          {PROVIDER_TYPES.map((pt) => (
            <label key={pt.value} className="radio-item" onClick={() => setType(pt.value)}>
              <div className={`radio-dot ${type === pt.value ? 'active' : ''}`} role="radio" aria-checked={type === pt.value} />
              <span>{pt.label}</span>
            </label>
          ))}
        </section>

        <section className="section-card">
          <div className="section-header">
            <KeyRound size={20} className="section-header-icon" />
            <span className="section-header-title">API 키</span>
          </div>
          <div className="api-key-input-wrap">
            <input
              type={showKey ? 'text' : 'password'}
              className="settings-input api-key-input"
              placeholder="API 키를 입력하세요"
              value={apiKey}
              onChange={(e) => setApiKey(e.target.value)}
              aria-label="API 키"
            />
            <button
              className="api-key-toggle"
              onClick={() => setShowKey(!showKey)}
              aria-label={showKey ? 'API 키 숨기기' : 'API 키 보기'}
              type="button"
            >
              {showKey ? <EyeOff size={18} /> : <Eye size={18} />}
            </button>
          </div>
        </section>

        {type === 'custom' && (
          <section className="section-card">
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
              aria-label="Base URL"
            />
          </section>
        )}

        <section className="section-card">
          <div className="section-header">
            <BrainCircuit size={20} className="section-header-icon" />
            <span className="section-header-title">모델</span>
            {modelsLoading && <Loader2 size={16} className="spin-icon" />}
          </div>
          {modelsLoading && availableModels.length === 0 && (
            <div className="model-loading">
              <Loader2 size={16} className="spin-icon" />
              <span>모델 목록을 불러오는 중...</span>
            </div>
          )}
          {!modelsLoading && !apiKey && (
            <div className="model-hint">
              API 키를 입력하면 모델을 자동으로 불러옵니다
            </div>
          )}
          {!modelsLoading && apiKey && availableModels.length === 0 && modelsError && (
            <div className="model-error" role="alert">
              {modelsError}
            </div>
          )}
          {!modelsLoading && apiKey && availableModels.length === 0 && !modelsError && (
            <div className="model-hint">
              사용 가능한 모델이 없습니다
            </div>
          )}
          {availableModels.map((m) => (
            <label key={m.id} className="model-item" onClick={() => setSelectedModel(m.id)}>
              <div className={`radio-dot ${selectedModel === m.id ? 'active' : ''}`} role="radio" aria-checked={selectedModel === m.id} />
              <div>
                <div className={`model-item-name ${selectedModel === m.id ? 'selected' : ''}`}>
                  {m.id}
                </div>
              </div>
            </label>
          ))}
          {availableModels.length === 0 && apiKey && !modelsLoading && (
            <input
              type="text"
              className="settings-input"
              placeholder="모델명 입력 (예: glm-4-flash)"
              value={selectedModel}
              onChange={(e) => setSelectedModel(e.target.value)}
              style={{ marginTop: 'var(--spacing-s)' }}
              aria-label="모델명"
            />
          )}
        </section>

        {providerConfig && (
          <section className="section-card">
            <button className="disconnect-btn" onClick={handleDisconnect}>
              <CloudOff size={18} />
              연결 끊기
            </button>
          </section>
        )}

        {saveError && (
          <div className="save-error" role="alert">
            {saveError}
          </div>
        )}

        <div className="sticky-save-bar">
          <button
            className="elevated-btn"
            onClick={handleSave}
            disabled={!apiKey || !selectedModel || testing}
          >
            {testing ? (
              <>
                <Loader2 size={18} className="spin-icon" />
                연결 확인 중...
              </>
            ) : (
              providerConfig ? '저장' : '연결'
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
