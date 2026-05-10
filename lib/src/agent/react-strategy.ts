import type { AgentStep, AgentResult, ToolResult } from '../types/agent';
import type { LlmToolSchema, LlmProviderConfig, LlmGenerationConfig } from '../llm/types';
import { LlmRemoteSession } from '../llm/session';
import { OpenAiClient } from '../llm/openai-client';
import { RiskClassifier } from './risk-classifier';
import { ErrorRecovery } from './error-recovery';
import { LoopDetector } from './loop-detector';
import { ConversationContext } from './conversation-context';
import { ToolPreferenceTracker } from './tool-preference-tracker';
import { tryParseToolJson } from './tool-json-parser';
import { inferToolArgs } from './tool-arg-inference';
import { truncate } from './truncate';
import { toContent, toolResultErr } from '../types/agent';
import type { AgentTool } from '../tools/types';

const TAG = 'AIOS-React';

export class ReactStrategy {
  private session: LlmRemoteSession | null = null;
  private cachedToolSchemas: LlmToolSchema[] | null = null;
  private cancelled = false;
  private client: OpenAiClient | null = null;

  private riskClassifier = new RiskClassifier();
  private loopDetector = new LoopDetector();
  private errorRecovery = new ErrorRecovery();
  private conversationContext: ConversationContext | null = null;
  private preferenceTracker: ToolPreferenceTracker | null = null;
  private resolveConfirmationFn: ((approved: boolean) => void) | null = null;
  private generationConfig: LlmGenerationConfig = { temperature: 1.0, topP: 0.95, maxTokens: 8192 };

  constructor(
    private readonly agentTools: Map<string, AgentTool>,
    private readonly config: LlmProviderConfig,
  ) {}

  setConversationContext(ctx: ConversationContext | null): void {
    this.conversationContext = ctx;
  }

  setToolPreferenceTracker(tracker: ToolPreferenceTracker | null): void {
    this.preferenceTracker = tracker;
  }

  setGenerationConfig(config: Partial<LlmGenerationConfig>): void {
    this.generationConfig = { ...this.generationConfig, ...config };
  }

  private ensureSession(): LlmRemoteSession {
    if (!this.session) {
      this.client = new OpenAiClient(this.config);
      this.session = new LlmRemoteSession(this.client, this.systemPrompt);
      this.cachedToolSchemas = this.buildToolSchemas();
    }
    return this.session;
  }

  private get systemPrompt(): string {
    const lines: string[] = [
      'You are AIOS, an on-device phone assistant.',
      "Use tools to help the user. Respond concisely in the user's language.",
      'When calling a tool, ALWAYS include ALL required parameters as JSON.',
      'If no tool is needed, answer directly.',
      '',
      'Available tools:',
    ];
    for (const tool of this.agentTools.values()) {
      lines.push(`- ${tool.name}: ${tool.description}`);
    }
    const ctx = this.conversationContext?.toPromptContext() ?? '';
    if (ctx) lines.push('', ctx);
    const pref = this.preferenceTracker?.toPromptContext() ?? '';
    if (pref) lines.push('', pref);
    return lines.join('\n');
  }

  private buildToolSchemas(): LlmToolSchema[] {
    const schemas: LlmToolSchema[] = [];
    for (const tool of this.agentTools.values()) {
      schemas.push({
        name: tool.name,
        description: tool.toolPrompt,
        parameters: this.parseParams(tool.parameters),
      });
    }
    return schemas;
  }

  private parseParams(paramsStr: string): LlmToolSchema['parameters'] {
    try {
      const decoded = JSON.parse(paramsStr);
      if (typeof decoded !== 'object' || decoded === null) return [];
      return Object.entries(decoded).map(([key, desc]) => ({
        name: key,
        description: String(desc),
        type: 'string' as const,
        required: !String(desc).toLowerCase().includes('optional'),
      }));
    } catch {
      return [];
    }
  }

  async execute(
    prompt: string,
    onStep?: (step: AgentStep) => void,
    maxIterations = 8,
  ): Promise<AgentResult> {
    this.cancelled = false;
    this.loopDetector.reset();
    this.errorRecovery.reset();
    const steps: AgentStep[] = [];

    console.log(`[${TAG}] Agent run: prompt="${truncate(prompt, 50)}"`);
    const runStartTime = Date.now();
    const maxRunDuration = 120_000;

    try {
      steps.push({ type: 'thought', content: `Processing: ${prompt}` });
      onStep?.(steps[steps.length - 1]);

      const session = this.ensureSession();
      const tools = this.cachedToolSchemas!;
      const config = this.generationConfig;
      let userParts = [prompt];
      let continuationCount = 0;
      const MAX_CONTINUATIONS = 3;

      for (let i = 0; i < maxIterations; i++) {
        if (this.cancelled) break;
        if (Date.now() - runStartTime > maxRunDuration) break;

        steps.push({ type: 'thought', content: `Thinking (step ${i + 1})...` });
        onStep?.(steps[steps.length - 1]);

        let fullContent = '';
        const toolCallBuilders = new Map<number, { id: string; name: string; arguments: string }>();
        const seenToolNames = new Set<number>();
        let lastStreamEmit = 0;
        let lastFinishReason = '';
        const STREAM_THROTTLE_MS = 50;

        try {
          for await (const chunk of session.chat(userParts, config, tools)) {
            if (this.cancelled) break;
            if (chunk.finishReason) lastFinishReason = chunk.finishReason;
            if (chunk.text) {
              fullContent += chunk.text;
              const now = Date.now();
              if (now - lastStreamEmit > STREAM_THROTTLE_MS) {
                lastStreamEmit = now;
                onStep?.({ type: 'streaming_text', content: fullContent });
              }
            }
            if (chunk.toolCallDeltas) {
              for (const tc of chunk.toolCallDeltas) {
                const b = toolCallBuilders.get(tc.index) || { id: '', name: '', arguments: '' };
                if (tc.id) b.id = tc.id;
                if (tc.name) b.name = tc.name;
                if (tc.arguments) b.arguments += tc.arguments;
                toolCallBuilders.set(tc.index, b);
                if (tc.name && !seenToolNames.has(tc.index)) {
                  seenToolNames.add(tc.index);
                  onStep?.({ type: 'tool_call_start', content: `${tc.name} 준비 중...`, toolName: tc.name });
                }
              }
            }
          }
        } catch (e) {
          console.error(`[${TAG}] Stream error:`, e);
        }

        if (fullContent) {
          onStep?.({ type: 'streaming_text', content: fullContent });
        }

        if (toolCallBuilders.size === 0) {
          if (lastFinishReason === 'length' && fullContent && continuationCount < MAX_CONTINUATIONS) {
            continuationCount++;
            steps.push({ type: 'continuation', content: `계속 생성 중... (${continuationCount}/${MAX_CONTINUATIONS})` });
            onStep?.(steps[steps.length - 1]);
            userParts = ['이어서 계속 작성하세요.'];
            continue;
          }

          const answer = fullContent.trim();
          if (answer) {
            steps.push({ type: 'answer', content: answer });
            onStep?.(steps[steps.length - 1]);
            this.recordTurn(prompt, steps);
            return { steps, success: true };
          }
          const retryCount = steps.filter((s) => s.type === 'phase1_retry').length;
          if (retryCount < 2) {
            steps.push({ type: 'phase1_retry', content: `Retry ${retryCount + 1}/2` });
            onStep?.(steps[steps.length - 1]);
            userParts = ['Please use a tool or provide a direct answer.'];
            continue;
          }
          steps.push({ type: 'answer', content: '요청을 처리하지 못했습니다.' });
          onStep?.(steps[steps.length - 1]);
          break;
        }

        for (const [, builder] of toolCallBuilders) {
          if (this.cancelled) break;
          const toolName = builder.name;
          let toolArgs = tryParseToolJson(builder.arguments);
          if (Object.keys(toolArgs).length === 0) {
            const inferred = inferToolArgs(toolName, prompt);
            if (inferred) toolArgs = inferred;
          }
          const argsJson = JSON.stringify(toolArgs);
          steps.push({ type: 'action', content: `Using tool: ${toolName}`, toolName, toolArgs: argsJson });
          onStep?.(steps[steps.length - 1]);

          const risk = this.riskClassifier.classify(toolName, argsJson);
          const validationError = await this.agentTools.get(toolName)?.validate?.(argsJson);
          if (validationError) {
            steps.push({ type: 'observation', content: validationError, toolName, toolResult: validationError });
            onStep?.(steps[steps.length - 1]);
            session.addToolResult(toolName, validationError);
            continue;
          }

          if (risk === 'high' || risk === 'critical') {
            steps.push({ type: 'confirmation_required', content: `Confirm: ${toolName}`, toolName, toolArgs: argsJson, riskLevel: risk });
            onStep?.(steps[steps.length - 1]);
            const approved = await this.waitForConfirmation();
            if (!approved) {
              const msg = 'Action cancelled by user';
              steps.push({ type: 'observation', content: msg, toolName, toolResult: msg });
              onStep?.(steps[steps.length - 1]);
              session.addToolResult(toolName, msg);
              continue;
            }
          }

          const toolResult = await this.executeTool(toolName, argsJson);
          const toolContent = toContent(toolResult);
          this.preferenceTracker?.recordToolUse(toolName);
          steps.push({ type: 'observation', content: toolContent, toolName, toolResult: toolContent });
          onStep?.(steps[steps.length - 1]);
          session.addToolResult(toolName, toolContent);

          this.errorRecovery.analyze(toolName, argsJson, toolResult);

          const loopResult = this.loopDetector.record(toolName, argsJson, toolResult);
          if (loopResult.type === 'forceBreak') {
            steps.push({ type: 'answer', content: '작업이 반복 감지로 중단되었습니다.' });
            onStep?.(steps[steps.length - 1]);
            this.recordTurn(prompt, steps);
            return { steps, success: false };
          }
        }
        userParts = [];
      }

      if (!steps.some((s) => s.type === 'answer')) {
        steps.push({ type: 'answer', content: '작업을 완료하지 못했습니다.' });
        onStep?.(steps[steps.length - 1]);
      }
    } catch (e) {
      console.error(`[${TAG}] Crashed:`, e);
      if (!steps.some((s) => s.type === 'answer')) {
        steps.push({ type: 'answer', content: `오류: ${e}` });
        onStep?.(steps[steps.length - 1]);
      }
    }

    this.recordTurn(prompt, steps);
    return { steps, success: steps.some((s) => s.type === 'answer') };
  }

  private async executeTool(name: string, argsJson: string): Promise<ToolResult> {
    const tool = this.agentTools.get(name);
    if (!tool) return toolResultErr(`Unknown tool '${name}'`);
    try {
      return await tool.execute(argsJson);
    } catch (e) {
      return toolResultErr(`${e}`);
    }
  }

  private recordTurn(userMessage: string, steps: AgentStep[]): void {
    if (!this.conversationContext) return;
    const answerStep = [...steps].reverse().find((s) => s.type === 'answer');
    if (!answerStep) return;
    const actionStep = steps.find((s) => s.type === 'action' && s.toolName);
    this.conversationContext.addTurn(userMessage, answerStep.content, actionStep?.toolName);
  }

  cancel(): void {
    this.cancelled = true;
    this.client?.cancel();
    if (this.resolveConfirmationFn) {
      this.resolveConfirmationFn(false);
      this.resolveConfirmationFn = null;
    }
  }

  resolveConfirmation(approved: boolean): void {
    this.resolveConfirmationFn?.(approved);
    this.resolveConfirmationFn = null;
  }

  private waitForConfirmation(): Promise<boolean> {
    return new Promise((resolve) => {
      this.resolveConfirmationFn = resolve;
      setTimeout(() => {
        if (this.resolveConfirmationFn === resolve) {
          this.resolveConfirmationFn = null;
          resolve(false);
        }
      }, 60_000);
    });
  }

  clearHistory(): void {
    this.session = null;
    this.cachedToolSchemas = null;
  }
}
