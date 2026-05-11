import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, SlidersHorizontal, Cpu, Bot, RotateCcw } from 'lucide-react';
import { useChatStore, type InferenceConfig } from '../stores/chat-store';
import { goBack } from './SettingsScreen';
import '../styles/settings.css';

const DEFAULTS: InferenceConfig = {
  temperature: 1.0,
  topP: 0.95,
  maxTokens: 512,
  maxIterations: 8,
};

interface SliderDef {
  key: keyof InferenceConfig;
  label: string;
  description: string;
  min: number;
  max: number;
  step: number;
}

const SLIDERS: { section: { icon: typeof SlidersHorizontal; title: string }; items: SliderDef[] }[] = [
  {
    section: { icon: SlidersHorizontal, title: '샘플링' },
    items: [
      { key: 'temperature', label: 'Temperature', description: '응답의 창의성을 조절합니다', min: 0, max: 1, step: 0.05 },
      { key: 'topP', label: 'Top-P', description: '핵 샘플링 임계값', min: 0, max: 1, step: 0.05 },
    ],
  },
  {
    section: { icon: Cpu, title: '출력' },
    items: [
      { key: 'maxTokens', label: '최대 토큰', description: '응답의 최대 길이', min: 64, max: 4096, step: 64 },
    ],
  },
  {
    section: { icon: Bot, title: '에이전트' },
    items: [
      { key: 'maxIterations', label: '최대 반복', description: '에이전트의 최대 도구 호출 횟수', min: 1, max: 20, step: 1 },
    ],
  },
];

export function InferenceSettingsScreen() {
  const navigate = useNavigate();
  const { inferenceConfig, setInferenceConfig } = useChatStore();
  const [editingKey, setEditingKey] = useState<keyof InferenceConfig | null>(null);
  const [editValue, setEditValue] = useState('');

  const handleSliderChange = (key: keyof InferenceConfig, value: number) => {
    setInferenceConfig({ [key]: value });
  };

  const handleValueClick = (key: keyof InferenceConfig) => {
    setEditingKey(key);
    setEditValue(String(inferenceConfig[key]));
  };

  const handleEditConfirm = () => {
    if (editingKey === null) return;
    const num = Number(editValue);
    if (!isNaN(num)) {
      const slider = SLIDERS.flatMap((s) => s.items).find((i) => i.key === editingKey);
      if (slider) {
        const clamped = Math.min(slider.max, Math.max(slider.min, num));
        setInferenceConfig({ [editingKey]: clamped });
      }
    }
    setEditingKey(null);
  };

  const handleReset = () => {
    setInferenceConfig(DEFAULTS);
  };

  const formatVal = (key: keyof InferenceConfig, val: number): string => {
    if (key === 'maxIterations') return String(val);
    if (key === 'maxTokens') return String(val);
    return val.toFixed(2);
  };

  const isDefault = (key: keyof InferenceConfig): boolean => {
    return inferenceConfig[key] === DEFAULTS[key];
  };

  return (
    <div className="settings-screen">
      <header className="settings-header">
        <button className="icon-btn" onClick={() => goBack(navigate)} aria-label="뒤로 가기">
          <ArrowLeft size={20} />
        </button>
        <h1>추론 설정</h1>
      </header>

      <div className="settings-body">
        {SLIDERS.map(({ section, items }) => (
          <section key={section.title} className="section-card">
            <div className="section-header">
              <section.icon size={20} className="section-header-icon" />
              <span className="section-header-title">{section.title}</span>
            </div>
            {items.map((slider) => (
              <div key={slider.key} className="slider-tile">
                <div className="slider-tile-header">
                  <div className="slider-tile-info">
                    <div className="slider-tile-label">{slider.label}</div>
                    <div className="slider-tile-desc">{slider.description}</div>
                  </div>
                  <div className="slider-tile-value-row">
                    <button
                      className="slider-value-btn"
                      onClick={() => handleValueClick(slider.key)}
                      aria-label={`${slider.label} 값 변경`}
                    >
                      {formatVal(slider.key, inferenceConfig[slider.key])}
                    </button>
                    {!isDefault(slider.key) && (
                      <button
                        className="slider-reset-single"
                        onClick={() => handleSliderChange(slider.key, DEFAULTS[slider.key])}
                        aria-label={`${slider.label} 기본값 복원`}
                      >
                        <RotateCcw size={14} />
                      </button>
                    )}
                  </div>
                </div>
                <input
                  type="range"
                  className="slider-input"
                  min={slider.min}
                  max={slider.max}
                  step={slider.step}
                  value={inferenceConfig[slider.key] as number}
                  onChange={(e) => handleSliderChange(slider.key, Number(e.target.value))}
                  aria-label={slider.label}
                />
              </div>
            ))}
          </section>
        ))}

        <div style={{ padding: 'var(--spacing-s) var(--spacing-l) var(--spacing-xxl)' }}>
          <button className="outlined-btn" onClick={handleReset}>
            <RotateCcw size={18} />
            기본값 복원
          </button>
        </div>
      </div>

      {editingKey !== null && (
        <div
          className="dialog-overlay"
          onClick={() => setEditingKey(null)}
          role="dialog"
          aria-modal="true"
          aria-labelledby="edit-dialog-title"
        >
          <div className="dialog-card" onClick={(e) => e.stopPropagation()}>
            <div className="dialog-title" id="edit-dialog-title">
              {SLIDERS.flatMap((s) => s.items).find((i) => i.key === editingKey)?.label} 값 입력
            </div>
            <input
              type="number"
              className="settings-input"
              value={editValue}
              onChange={(e) => setEditValue(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') handleEditConfirm();
                if (e.key === 'Escape') setEditingKey(null);
              }}
              autoFocus
            />
            <div className="dialog-actions">
              <button className="dialog-btn-cancel" onClick={() => setEditingKey(null)}>
                취소
              </button>
              <button className="dialog-btn-confirm" onClick={handleEditConfirm}>
                확인
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
