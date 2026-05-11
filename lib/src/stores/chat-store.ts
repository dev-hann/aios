import { create } from 'zustand';
import type { AgentStep } from '../types/agent';
import { ReactStrategy } from '../agent/react-strategy';
import { ConversationContext } from '../agent/conversation-context';
import { ToolPreferenceTracker } from '../agent/tool-preference-tracker';
import { CalculatorTool } from '../tools/calculator';
import { NotepadTool } from '../tools/notepad';
import { TimerTool } from '../tools/timer';
import { conversationDb, type ChatMessage, type Conversation } from '../services/conversation-db';
import type { LlmProviderConfig, LlmModelInfo } from '../llm/types';
import { createProviderConfig } from '../llm/types';
import { OpenAiClient } from '../llm/openai-client';

export interface ServiceState {
  status: 'idle' | 'connecting' | 'ready' | 'generating' | 'error';
  label: string;
}

export interface InferenceConfig {
  temperature: number;
  topP: number;
  maxTokens: number;
  maxIterations: number;
}

interface ChatState {
  messages: ChatMessage[];
  agentSteps: AgentStep[];
  serviceState: ServiceState;
  isConfirming: boolean;
  pendingToolName: string;
  pendingToolArgs: string;
  pendingToolRisk: string;
  errorMessage: string | null;

  streamingContent: string;
  isStreamingText: boolean;

  conversations: Conversation[];
  currentConversationId: string | null;
  currentConversationTitle: string;

  providerConfig: LlmProviderConfig | null;
  apiKey: string;
  baseUrl: string;
  model: string;
  providerType: string;

  availableModels: LlmModelInfo[];
  connectionTestResult: { success: boolean; message: string } | null;
  inferenceConfig: InferenceConfig;

  setProvider: (type: string, apiKey: string, baseUrl: string, model: string) => void;
  disconnectProvider: () => void;
  testConnection: () => Promise<void>;
  fetchModels: () => Promise<void>;
  sendMessage: (content: string) => Promise<void>;
  cancelGeneration: () => void;
  resolveConfirmation: (approved: boolean) => void;
  initializeSession: () => Promise<void>;
  createConversation: () => Promise<void>;
  switchConversation: (id: string) => Promise<void>;
  deleteConversation: (id: string) => Promise<void>;
  loadConversations: () => Promise<void>;
  clearHistory: () => void;
  setInferenceConfig: (config: Partial<InferenceConfig>) => void;
}

const tools = new Map<string, import('../tools/types').AgentTool>();
tools.set('calculator', new CalculatorTool());
tools.set('notepad', new NotepadTool());
tools.set('timer', new TimerTool());

const conversationContext = new ConversationContext();
const preferenceTracker = new ToolPreferenceTracker();

let strategy: ReactStrategy | null = null;
let storeInferenceConfig: InferenceConfig = { temperature: 1.0, topP: 0.95, maxTokens: 8192, maxIterations: 8 };

function wireStrategy(s: ReactStrategy): void {
  s.setConversationContext(conversationContext);
  s.setToolPreferenceTracker(preferenceTracker);
  s.setGenerationConfig({
    temperature: storeInferenceConfig.temperature,
    topP: storeInferenceConfig.topP,
    maxTokens: storeInferenceConfig.maxTokens,
  });
}

function initProviderFromEnv(): Partial<ChatState> {
  const apiKey = import.meta.env.VITE_API_KEY;
  const providerType = import.meta.env.VITE_PROVIDER_TYPE;
  const model = import.meta.env.VITE_MODEL;

  if (apiKey && providerType && model) {
    const config = createProviderConfig(providerType, apiKey, '', model);
    strategy = new ReactStrategy(tools, config);
    wireStrategy(strategy);
    console.log(`[AIOS-Chat] Auto-configured provider: ${providerType}, model: ${model}`);
    return {
      providerConfig: config,
      apiKey,
      baseUrl: config.baseUrl,
      model,
      providerType,
      serviceState: { status: 'ready', label: '준비 완료' },
    };
  }

  return {};
}

export const useChatStore = create<ChatState>((set, get) => ({
  messages: [],
  agentSteps: [],
  serviceState: { status: 'idle', label: '대기 중' },
  isConfirming: false,
  pendingToolName: '',
  pendingToolArgs: '',
  pendingToolRisk: '',
  errorMessage: null,
  streamingContent: '',
  isStreamingText: false,

  conversations: [],
  currentConversationId: null,
  currentConversationTitle: 'AIOS',

  providerConfig: null,
  apiKey: '',
  baseUrl: '',
  model: '',
  providerType: '',
  ...initProviderFromEnv(),

  availableModels: [],
  connectionTestResult: null,
  inferenceConfig: { temperature: 1.0, topP: 0.95, maxTokens: 8192, maxIterations: 8 },

  setProvider: (type, apiKey, baseUrl, model) => {
    const config = createProviderConfig(type, apiKey, baseUrl, model);
    strategy = new ReactStrategy(tools, config);
    wireStrategy(strategy);
    set({
      providerConfig: config,
      apiKey,
      baseUrl,
      model,
      providerType: type,
      serviceState: { status: 'ready', label: '준비 완료' },
      connectionTestResult: null,
    });
  },

  disconnectProvider: () => {
    strategy = null;
    set({
      providerConfig: null,
      apiKey: '',
      baseUrl: '',
      model: '',
      providerType: '',
      availableModels: [],
      connectionTestResult: null,
      serviceState: { status: 'idle', label: '대기 중' },
    });
  },

  testConnection: async () => {
    const { providerConfig } = get();
    if (!providerConfig) return;
    set({ connectionTestResult: null });
    try {
      const client = new OpenAiClient(providerConfig);
      const ok = await client.testConnection();
      set({
        connectionTestResult: {
          success: ok,
          message: ok ? '연결 성공' : '연결 실패',
        },
      });
    } catch (e) {
      set({
        connectionTestResult: {
          success: false,
          message: e instanceof Error ? e.message : '알 수 없는 오류',
        },
      });
    }
  },

  fetchModels: async () => {
    const { providerConfig } = get();
    if (!providerConfig) return;
    try {
      const client = new OpenAiClient(providerConfig);
      const models = await client.fetchModels();
      set({ availableModels: models });
    } catch (e) {
      console.error('[AIOS-Chat] fetchModels failed:', e);
    }
  },

  sendMessage: async (content: string) => {
    const state = get();
    if (!strategy) {
      set({ serviceState: { status: 'error', label: 'AI 설정 필요' } });
      return;
    }

    const userMsg: ChatMessage = {
      id: `msg_${Date.now()}`,
      role: 'user',
      content,
      createdAt: Date.now(),
    };

    const convId = state.currentConversationId || (await conversationDb.createConversation()).id;
    await conversationDb.appendMessage(convId, userMsg);

    const currentMessages = [...state.messages, userMsg];
    set({
      messages: currentMessages,
      agentSteps: [],
      serviceState: { status: 'generating', label: '생성 중...' },
      currentConversationId: convId,
      errorMessage: null,
      isConfirming: false,
    });

    const title = currentMessages.length === 1 ? content.substring(0, 20) : state.currentConversationTitle;
    if (currentMessages.length === 1) {
      await conversationDb.updateTitle(convId, title);
      set({ currentConversationTitle: title });
    }

    try {
      const result = await strategy.execute(content, (step) => {
        if (step.type === 'streaming_text') {
          set({ streamingContent: step.content, isStreamingText: true });
          return;
        }

        set((s) => ({ agentSteps: [...s.agentSteps, step] }));

        if (step.type === 'action' || step.type === 'tool_call_start') {
          set({ streamingContent: '', isStreamingText: false });
        }

        if (step.type === 'confirmation_required') {
          set({
            isConfirming: true,
            pendingToolName: step.toolName ?? '',
            pendingToolArgs: step.toolArgs ?? '',
            pendingToolRisk: step.riskLevel ?? '',
          });
        }
      }, get().inferenceConfig.maxIterations);

        const answerStep = result.steps.find((s) => s.type === 'answer');
        if (answerStep) {
          const assistantMsg: ChatMessage = {
            id: `msg_${Date.now()}_ans`,
            role: 'assistant',
            content: answerStep.content,
            createdAt: Date.now(),
          };
          await conversationDb.appendMessage(convId, assistantMsg);
          set((s) => ({
            messages: [...s.messages, assistantMsg],
            serviceState: { status: 'ready', label: '준비 완료' },
            agentSteps: [],
            streamingContent: '',
            isStreamingText: false,
          }));
      }
    } catch (e) {
      console.error('[AIOS-Chat] Error:', e);
      const msg = e instanceof Error ? e.message : '오류가 발생했습니다';
      set({
        serviceState: { status: 'error', label: '오류' },
        errorMessage: msg,
        agentSteps: [],
        streamingContent: '',
        isStreamingText: false,
      });
    }

    get().loadConversations();
  },

  cancelGeneration: () => {
    strategy?.cancel();
    const state = get();
    const lastAnswer = [...state.agentSteps].reverse().find((s) => s.type === 'answer');
    if (lastAnswer) {
      const assistantMsg: ChatMessage = {
        id: `msg_${Date.now()}_ans`,
        role: 'assistant',
        content: lastAnswer.content,
        createdAt: Date.now(),
      };
      const convId = state.currentConversationId;
      if (convId) {
        conversationDb.appendMessage(convId, assistantMsg).catch((e) => console.error('[AIOS-Chat] WARN:', e));
      }
      set((s) => ({
        messages: [...s.messages, assistantMsg],
        serviceState: { status: 'ready', label: '준비 완료' },
        agentSteps: [],
        streamingContent: '',
        isStreamingText: false,
      }));
    } else {
      set({
        serviceState: { status: 'ready', label: '준비 완료' },
        agentSteps: [],
        streamingContent: '',
        isStreamingText: false,
      });
    }
  },

  resolveConfirmation: (approved: boolean) => {
    strategy?.resolveConfirmation(approved);
    set({ isConfirming: false, pendingToolName: '', pendingToolArgs: '', pendingToolRisk: '' });
  },

  initializeSession: async () => {
    try {
      const convs = await conversationDb.getAllConversations();
      if (convs.length === 0) {
        const conv = await conversationDb.createConversation();
        set({
          currentConversationId: conv.id,
          currentConversationTitle: conv.title,
          conversations: [conv],
        });
      } else {
        const active = convs[0];
        const messages = await conversationDb.getMessages(active.id);
        set({
          currentConversationId: active.id,
          currentConversationTitle: active.title,
          messages,
          conversations: convs,
        });
      }
      console.log(`[AIOS-Chat] Session initialized: ${get().currentConversationId}`);
    } catch (e) {
      console.error('[AIOS-Chat] initializeSession failed:', e);
    }
  },

  createConversation: async () => {
    const conv = await conversationDb.createConversation();
    set({
      currentConversationId: conv.id,
      currentConversationTitle: conv.title,
      messages: [],
      agentSteps: [],
    });
    strategy?.clearHistory();
    await get().loadConversations();
  },

  switchConversation: async (id: string) => {
    const messages = await conversationDb.getMessages(id);
    const convs = await conversationDb.getAllConversations();
    const conv = convs.find((c) => c.id === id);
    set({
      currentConversationId: id,
      currentConversationTitle: conv?.title ?? 'AIOS',
      messages,
      agentSteps: [],
    });
    strategy?.clearHistory();
  },

  deleteConversation: async (id: string) => {
    await conversationDb.deleteConversation(id);
    const state = get();
    if (state.currentConversationId === id) {
      const convs = await conversationDb.getAllConversations();
      if (convs.length > 0) {
        await get().switchConversation(convs[0].id);
      } else {
        await get().createConversation();
      }
    }
    await get().loadConversations();
  },

  loadConversations: async () => {
    const convs = await conversationDb.getAllConversations();
    set({ conversations: convs });
  },

  clearHistory: () => {
    strategy?.clearHistory();
    set({ messages: [], agentSteps: [] });
  },

  setInferenceConfig: (config) => {
    set((s) => ({ inferenceConfig: { ...s.inferenceConfig, ...config } }));
    storeInferenceConfig = get().inferenceConfig;
    strategy?.setGenerationConfig({
      temperature: storeInferenceConfig.temperature,
      topP: storeInferenceConfig.topP,
      maxTokens: storeInferenceConfig.maxTokens,
    });
  },
}));
