import 'dart:async';
import 'dart:convert';

import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/agent/agent_tool.dart';
import 'package:aios/domain/agent/audit_log.dart';
import 'package:aios/domain/agent/confirmation_gate.dart';
import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/error_recovery.dart';
import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/loop_detector.dart';
import 'package:aios/domain/agent/prompt_builder.dart';
import 'package:aios/domain/agent/response_parser.dart';
import 'package:aios/domain/agent/risk_classifier.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/repositories/llm_repository.dart';

class ReactStrategy implements AgentStrategy {
  ReactStrategy(
    this._llmRepository, {
    ToolContext? toolContext,
    Map<String, AgentTool>? basicTools,
    Map<String, ExtendedTool>? extendedTools,
  })  : _toolContext = toolContext,
        _basicTools = basicTools ?? {},
        _extendedTools = extendedTools ?? {};

  final LlmRepository _llmRepository;
  final ToolContext? _toolContext;
  final Map<String, AgentTool> _basicTools;
  final Map<String, ExtendedTool> _extendedTools;

  ConversationContext? _conversationContext;
  ToolPreferenceTracker? _preferenceTracker;

  bool _cancelled = false;

  final _riskClassifier = RiskClassifier();
  final _loopDetector = LoopDetector();
  final _confirmationGate = ConfirmationGate();
  final _auditLog = AuditLog();
  late final ErrorRecovery _errorRecovery = ErrorRecovery(
    availableTools: _allToolNames,
  );

  late final PromptBuilder _promptBuilder = PromptBuilder();

  Set<String> get _allToolNames =>
      {..._basicTools.keys, ..._extendedTools.keys};

  late final ResponseParser _responseParser =
      ResponseParser(_allToolNames);

  static const _tag = 'AIOS-React';
  static const _phase0MaxRetries = 1;
  static const _phase1MaxRetries = 2;
  static const _phase2MaxRetries = 2;
  static const _answerMaxRetries = 1;

  @override
  Future<AgentResult> execute(
    String prompt, {
    int maxIterations = 8,
    int maxTokens = 512,
    void Function(AgentStep)? onStep,
  }) async {
    _cancelled = false;
    _loopDetector.reset();
    _errorRecovery.reset();
    final steps = <AgentStep>[];

    print('[$_tag] Agent run: '
        'prompt="${prompt.substring(0, prompt.length > 50 ? 50 : prompt.length)}", '
        'maxIter=$maxIterations');

    final runStartTime = DateTime.now();
    const maxRunDuration = Duration(seconds: 120);

    try {
      steps.add(AgentStep('thought', 'Processing: $prompt'));
      onStep?.call(steps.last);

      _promptBuilder.addUserMessage(prompt);

      final routingManifest = _getRoutingManifest();

      // ── Phase 0: Intent Classification ──
      final isConversation = await _classifyIntent(
        prompt,
        maxTokens,
        onStep,
        steps,
        routingManifest,
      );
      if (_cancelled) {
        steps.add(const AgentStep('answer', '작업이 취소되었습니다.'));
        onStep?.call(steps.last);
        _recordTurn(prompt, steps);
        return AgentResult(steps: steps, success: false);
      }

      if (isConversation) {
        final answer = await _generateAnswer(
          prompt,
          maxTokens,
          onStep,
          steps,
        );
        steps.add(AgentStep('answer', answer));
        onStep?.call(steps.last);
        _recordTurn(prompt, steps);
        return AgentResult(steps: steps, success: true);
      }

      // ── TASK: Phase 1/2 Loop ──
      for (var i = 0; i < maxIterations; i++) {
        if (_cancelled) break;

        final elapsed = DateTime.now().difference(runStartTime);
        if (elapsed > maxRunDuration) {
          steps.add(AgentStep(
            'thought',
            'Time limit reached (${elapsed.inSeconds}s).',
          ));
          onStep?.call(steps.last);
          break;
        }

        steps.add(
          AgentStep('thought', 'Thinking (step ${i + 1})...'),
        );
        onStep?.call(steps.last);
        onStep?.call(const AgentStep('thinking_start', ''));

        // ── Phase 1: Routing ──
        final routingSystem =
            _promptBuilder.buildRoutingPrompt(
          routingManifest,
          conversationContext:
              _conversationContext?.toPromptContext(),
          toolPreferences:
              _preferenceTracker?.toPromptContext(),
        );

        final phase1Response =
            await _generateResponse(routingSystem, maxTokens);

        print('[$_tag] Phase1 iter$i: '
            '${phase1Response.substring(0, phase1Response.length > 200 ? 200 : phase1Response.length)}');

        onStep?.call(const AgentStep('thinking_end', ''));

        _promptBuilder.addAssistantMessage(phase1Response);

        final parsed = _responseParser.parse(phase1Response);

        if (parsed is ParseAnswer) {
          steps.add(AgentStep('answer', parsed.text));
          onStep?.call(steps.last);
          break;
        }

        if (parsed is ParseAction) {
          final String observation;

          if (_hasValidArgs(parsed.args)) {
            print('[$_tag] Phase1 direct execute: '
                'tool=${parsed.toolName}');
            observation = await _executeTool(
              parsed.toolName,
              parsed.args,
              onStep,
            );
          } else {
            print('[$_tag] Phase2: tool=${parsed.toolName}');
            observation = await _phase2Execute(
              parsed.toolName,
              prompt,
              maxTokens,
              onStep,
            );
          }

          steps.add(
            AgentStep(
              'action',
              'Using tool: ${parsed.toolName}',
              toolName: parsed.toolName,
              toolArgs: parsed.args,
            ),
          );
          onStep?.call(steps.last);

          steps.add(
            AgentStep(
              'observation',
              observation,
              toolName: parsed.toolName,
              toolResult: observation,
            ),
          );
          onStep?.call(steps.last);

          _promptBuilder.addObservation(
            'Observation from ${parsed.toolName}: $observation',
          );

          final recoveryHint = _errorRecovery.analyze(
            parsed.toolName,
            parsed.args,
            observation,
          );
          if (recoveryHint != null &&
              recoveryHint.promptNudge.isNotEmpty) {
            print('[$_tag] Recovery: type=${recoveryHint.type}, '
                'retry=${recoveryHint.shouldRetry}');
            _promptBuilder.addObservation(
              recoveryHint.promptNudge,
            );
          }

          final loopResult = _loopDetector.record(
            parsed.toolName,
            parsed.args,
            observation,
          );

          if (loopResult is LoopWarning) {
            final nudge =
                'WARNING: You have called \'${parsed.toolName}\' '
                '${loopResult.count} times with similar arguments. '
                'Provide your final Answer now, '
                'or try a different approach.';
            _promptBuilder.addObservation(nudge);
          } else if (loopResult is LoopForceBreak) {
            _promptBuilder.addObservation(
              'SYSTEM: Loop detected. Provide your Answer now.',
            );
            break;
          } else if (_loopDetector.shouldNudge(
            i + 1,
            steps.every((s) => s.type != 'answer'),
          )) {
            _promptBuilder.addObservation(
              'Reminder: ${i + 1} steps completed. '
              'If you have enough information, '
              'provide your final Answer now.',
            );
          }
        } else {
          final retryCount = steps
              .where((s) => s.type == 'phase1_retry')
              .length;
          print('[$_tag] WARN: ParseEmpty iter$i '
              '(retry=$retryCount/$_phase1MaxRetries)');

          if (retryCount < _phase1MaxRetries) {
            final nudge = retryCount == 0
                ? 'FORMAT ERROR: Respond ONLY '
                    '"Action: tool_name" or "Answer: text".'
                : 'CRITICAL: You MUST respond '
                    '"Answer: [your response]". '
                    'You have failed format twice. Answer now.';
            steps.add(AgentStep(
              'phase1_retry',
              'Format retry ${retryCount + 1}/$_phase1MaxRetries',
              phase: 'routing',
              retryAttempt: retryCount + 1,
              maxRetries: _phase1MaxRetries,
            ));
            onStep?.call(steps.last);
            _promptBuilder.addObservation(nudge);
            continue;
          }

          steps.add(AgentStep(
            'answer',
            '요청을 처리하지 못했습니다. 다시 시도해주세요.',
          ));
          onStep?.call(steps.last);
          break;
        }
      }

      if (steps.every((s) => s.type != 'answer')) {
        final lastObs = steps
            .where((s) => s.type == 'observation')
            .lastOrNull?.toolResult;
        final truncated = lastObs != null && lastObs.length > 200
            ? lastObs.substring(0, 200)
            : lastObs;
        final summary = truncated != null
            ? '작업을 완료하지 못했습니다. '
                '마지막 관찰 결과: $truncated'
            : '작업을 완료하지 못했습니다. 다시 시도해주세요.';
        steps.add(AgentStep('answer', summary));
        onStep?.call(steps.last);
      }
    } on Object catch (e) {
      print('[$_tag] ERROR: Agent run crashed: $e');
      if (steps.every((s) => s.type != 'answer')) {
        steps.add(AgentStep(
          'answer',
          'An error occurred: $e',
        ));
        onStep?.call(steps.last);
      }
    }

    final success = steps.any((s) => s.type == 'answer');
    _recordTurn(prompt, steps);
    return AgentResult(steps: steps, success: success);
  }

  Future<bool> _classifyIntent(
    String prompt,
    int maxTokens,
    void Function(AgentStep)? onStep,
    List<AgentStep> steps,
    String routingManifest,
  ) async {
    for (var attempt = 0; attempt <= _phase0MaxRetries; attempt++) {
      if (_cancelled) return false;

      steps.add(AgentStep(
        'phase0_classifying',
        '의도 분석 중...',
        phase: 'intent',
        retryAttempt: attempt,
        maxRetries: _phase0MaxRetries,
      ));
      onStep?.call(steps.last);

      final intentSystem =
          _promptBuilder.buildIntentPrompt(routingManifest);
      final response = await _generateResponseFromPrompt(
        [
          ChatMessage(
            id: 'sys_p0_${DateTime.now().millisecondsSinceEpoch}',
            role: 'system',
            content: intentSystem,
            createdAt: DateTime.now(),
          ),
          ChatMessage(
            id: 'usr_p0_${DateTime.now().millisecondsSinceEpoch}',
            role: 'user',
            content: prompt,
            createdAt: DateTime.now(),
          ),
        ],
        prompt,
        16,
      );

      final result = _responseParser.parseIntent(response);
      if (result is ParseIntent) {
        final isConvo = result.isConversation;
        steps.add(AgentStep(
          'phase0_result',
          isConvo ? '의도: 대화' : '의도: 작업 요청',
          phase: 'intent',
        ));
        onStep?.call(steps.last);
        print('[$_tag] Phase0: '
            '${isConvo ? "CONVERSATION" : "TASK"} '
            '(attempt=$attempt, response="$response")');
        return isConvo;
      }

      print('[$_tag] Phase0 retry: '
          'attempt=$attempt, response="$response"');

      if (attempt < _phase0MaxRetries) {
        steps.add(AgentStep(
          'phase0_retry',
          '의도 분석 재시도... (${attempt + 1}/$_phase0MaxRetries)',
          phase: 'intent',
          retryAttempt: attempt + 1,
          maxRetries: _phase0MaxRetries,
        ));
        onStep?.call(steps.last);
      }
    }

    print('[$_tag] Phase0 fallback: defaulting to TASK');
    steps.add(const AgentStep(
      'phase0_result',
      '의도: 작업 요청 (기본)',
      phase: 'intent',
    ));
    onStep?.call(steps.last);
    return false;
  }

  Future<String> _generateAnswer(
    String prompt,
    int maxTokens,
    void Function(AgentStep)? onStep,
    List<AgentStep> steps,
  ) async {
    for (var attempt = 0; attempt <= _answerMaxRetries; attempt++) {
      if (_cancelled) return '작업이 취소되었습니다.';

      steps.add(AgentStep(
        'phase_answer',
        '응답 생성 중...',
        phase: 'answer',
        retryAttempt: attempt,
        maxRetries: _answerMaxRetries,
      ));
      onStep?.call(steps.last);

      final answerSystem = _promptBuilder.buildAnswerPrompt();
      final response = await _generateResponseFromPrompt(
        [
          ChatMessage(
            id: 'sys_ans_${DateTime.now().millisecondsSinceEpoch}',
            role: 'system',
            content: answerSystem,
            createdAt: DateTime.now(),
          ),
          ChatMessage(
            id: 'usr_ans_${DateTime.now().millisecondsSinceEpoch}',
            role: 'user',
            content: prompt,
            createdAt: DateTime.now(),
          ),
        ],
        prompt,
        maxTokens,
      );

      final trimmed = response.trim();
      if (trimmed.isNotEmpty &&
          !trimmed.toLowerCase().startsWith('action:') &&
          !trimmed.toLowerCase().startsWith('answer:')) {
        print('[$_tag] Answer phase: "$trimmed" '
            '(attempt=$attempt)');
        return trimmed;
      }

      if (trimmed.toLowerCase().startsWith('answer:')) {
        final text = trimmed.substring(7).trim();
        if (text.isNotEmpty) return text;
      }

      print('[$_tag] Answer phase retry: '
          'attempt=$attempt, response="$trimmed"');

      if (attempt < _answerMaxRetries) {
        steps.add(AgentStep(
          'phase_answer_retry',
          '응답 재시도... (${attempt + 1}/$_answerMaxRetries)',
          phase: 'answer',
          retryAttempt: attempt + 1,
          maxRetries: _answerMaxRetries,
        ));
        onStep?.call(steps.last);
      }
    }

    return '안녕하세요! 무엇을 도와드릴까요?';
  }

  void _recordTurn(String userMessage, List<AgentStep> steps) {
    if (_conversationContext == null) return;
    final answerStep = steps
        .where((s) => s.type == 'answer')
        .lastOrNull;
    if (answerStep == null) return;
    final toolSteps = steps
        .where((s) => s.type == 'action' && s.toolName.isNotEmpty)
        .toList();
    final toolUsed =
        toolSteps.isNotEmpty ? toolSteps.first.toolName : null;
    _conversationContext!.addTurn(
      userMessage,
      answerStep.content,
      toolUsed: toolUsed,
    );
    print('[$_tag] Context turn recorded: '
        '${_conversationContext!.length} turns, '
        'tool=${toolUsed ?? "none"}');
  }

  Future<String> _generateResponse(
    String systemPrompt,
    int maxTokens,
  ) async {
    final history = _promptBuilder.getHistory();
    final chatHistory = _buildChatHistory(systemPrompt, history);

    final responseBuffer = StringBuffer();

    final tokenSub = _llmRepository.tokenStream.listen(
      (token) => responseBuffer.write(token),
      onError: (Object e) {
        print('[$_tag] ERROR: Token stream error: $e');
      },
    );

    try {
      await _llmRepository.sendMessage(
        chatHistory,
        userMessage: history.last.content,
        maxTokens: maxTokens,
      );
      await Future<void>.delayed(Duration.zero);
    } on Object catch (e) {
      print('[$_tag] ERROR: Generate response error: $e');
    } finally {
      await tokenSub.cancel();
    }

    final response = responseBuffer.toString();
    print('[$_tag] LLM response="$response"');
    return response;
  }

  Future<String> _phase2Execute(
    String toolName,
    String originalPrompt,
    int maxTokens,
    void Function(AgentStep)? onStep,
  ) async {
    final basicTool = _basicTools[toolName];
    final extendedTool = _extendedTools[toolName];
    if (basicTool == null && extendedTool == null) {
      return "Error: Unknown tool '$toolName'";
    }

    final String toolPromptText;
    String? extraContext;

    if (extendedTool != null) {
      toolPromptText = extendedTool.toolPrompt;
      if (_toolContext != null) {
        extraContext =
            await extendedTool.phaseContext(originalPrompt, _toolContext!);
      }
    } else {
      toolPromptText = basicTool!.toolPrompt;
      extraContext = await basicTool.phaseContext(originalPrompt);
    }

    final toolSystem = _promptBuilder.buildToolPrompt(
      toolName,
      toolPromptText,
      extraContext: extraContext,
    );

    final phase2UserMessage =
        _buildPhase2UserMessage(originalPrompt);

    for (var attempt = 0; attempt < _phase2MaxRetries; attempt++) {
      String userMsg = attempt == 0
          ? phase2UserMessage
          : '$phase2UserMessage\n\n'
              'FORMAT: Respond with:\n'
              'Action: $toolName\n'
              'Args: {"param": "value"}';

      final phase2History = <ChatMessage>[
        ChatMessage(
          id: 'sys_p2_${DateTime.now().millisecondsSinceEpoch}',
          role: 'system',
          content: toolSystem,
          createdAt: DateTime.now(),
        ),
        ChatMessage(
          id: 'usr_p2_${DateTime.now().millisecondsSinceEpoch}',
          role: 'user',
          content: userMsg,
          createdAt: DateTime.now(),
        ),
      ];

      final phase2Response =
          await _generateResponseFromPrompt(
        phase2History,
        userMsg,
        maxTokens,
      );

      print('[$_tag] Phase2 attempt=$attempt '
          'response="$phase2Response"');

      final parsed = _responseParser.parse(phase2Response);
      if (parsed is ParseAction &&
          parsed.toolName == toolName &&
          _hasValidArgs(parsed.args)) {
        return _executeTool(
          parsed.toolName,
          parsed.args,
          onStep,
        );
      }

      print('[$_tag] Phase2 retry: '
          'attempt=$attempt, parsed=$parsed');
    }

    return "Error: Could not generate valid args for $toolName";
  }

  Future<String> _generateResponseFromPrompt(
    List<ChatMessage> chatHistory,
    String userMessage,
    int maxTokens,
  ) async {
    final responseBuffer = StringBuffer();

    final tokenSub = _llmRepository.tokenStream.listen(
      (token) => responseBuffer.write(token),
      onError: (Object e) {
        print('[$_tag] ERROR: Stream error: $e');
      },
    );

    try {
      await _llmRepository.sendMessage(
        chatHistory,
        userMessage: userMessage,
        maxTokens: maxTokens,
      );
      await Future<void>.delayed(Duration.zero);
    } on Object catch (e) {
      print('[$_tag] ERROR: Generate error: $e');
    } finally {
      await tokenSub.cancel();
    }

    return responseBuffer.toString();
  }

  String _buildPhase2UserMessage(String originalPrompt) {
    final history = _promptBuilder.getHistory();
    final observations = history
        .where((m) =>
            m.role == 'user' &&
            m.content.startsWith('Observation'))
        .toList();

    if (observations.isEmpty) return originalPrompt;

    final allObs =
        observations.map((m) => m.content).join('\n');
    return '$originalPrompt\n\nPrevious results:\n$allObs';
  }

  List<ChatMessage> _buildChatHistory(
    String systemPrompt,
    List<({String role, String content})> history,
  ) {
    return <ChatMessage>[
      ChatMessage(
        id: 'system_${DateTime.now().millisecondsSinceEpoch}',
        role: 'system',
        content: systemPrompt,
        createdAt: DateTime.now(),
      ),
      ...history.map(
        (m) => ChatMessage(
          id: '${m.role}_${DateTime.now().millisecondsSinceEpoch}',
          role: m.role,
          content: m.content,
          createdAt: DateTime.now(),
        ),
      ),
    ];
  }

  bool _hasValidArgs(String args) {
    if (args.isEmpty || args == '{}') return false;
    try {
      final decoded = jsonDecode(args);
      return decoded is Map<String, dynamic> && decoded.isNotEmpty;
    } on Object {
      return false;
    }
  }

  String _getRoutingManifest() {
    final lines = <String>[];
    for (final tool in _basicTools.values) {
      lines.add('- ${tool.name}: ${tool.description}');
    }
    for (final tool in _extendedTools.values) {
      lines.add('- ${tool.name}: ${tool.description}');
    }
    return lines.join('\n');
  }

  Future<String> _executeTool(
    String name,
    String args,
    void Function(AgentStep)? onStep,
  ) async {
    final risk = _riskClassifier.classify(name, args);

    final basicTool = _basicTools[name];
    final extendedTool = _extendedTools[name];

    if (basicTool != null) {
      final validationError = await basicTool.validate(args);
      if (validationError != null) return validationError;
    }

    if (extendedTool != null) {
      final ctx = _toolContext;
      if (ctx == null) return _noContextError(name, args, risk);
      final validationError =
          await extendedTool.validate(args, ctx);
      if (validationError != null) return validationError;
    }

    if (risk == ToolRisk.high || risk == ToolRisk.critical) {
      final approved =
          await _confirmationGate.requestConfirmation(
        risk,
        name,
        args,
        onStep ?? (_) {},
      );
      if (!approved) {
        _auditLog.add(name, args, risk, false, 'Cancelled');
        return 'Action cancelled by user';
      }
    }

    if (basicTool != null) {
      final result = await basicTool.execute(args);
      _auditLog.add(name, args, risk, true, result);
      _preferenceTracker?.recordToolUse(name);
      return result;
    }

    if (extendedTool != null) {
      final ctx = _toolContext;
      if (ctx == null) return _noContextError(name, args, risk);
      final result = await extendedTool.execute(args, ctx);
      _auditLog.add(name, args, risk, true, result);
      _preferenceTracker?.recordToolUse(name);
      return result;
    }

    return "Error: Unknown tool '$name'. "
        "Available: ${_allToolNames.join(', ')}";
  }

  String _noContextError(String name, String args, ToolRisk risk) {
    _auditLog.add(
      name,
      args,
      risk,
      false,
      'ToolContext not initialized',
    );
    return 'Error: ToolContext not initialized';
  }

  @override
  void cancel() {
    _cancelled = true;
    _llmRepository.stopGeneration();
    _confirmationGate.cancel();
  }

  @override
  void resolveConfirmation(bool approved) {
    _confirmationGate.resolve(approved);
  }

  @override
  String getToolManifest() {
    final lines = <String>[];
    for (final tool in _basicTools.values) {
      lines.add(
        '- ${tool.name}: ${tool.description}\n'
        '  Parameters: ${tool.parameters}',
      );
    }
    for (final tool in _extendedTools.values) {
      lines.add(
        '- ${tool.name}: ${tool.description}\n'
        '  Parameters: ${tool.parameters}',
      );
    }
    return lines.join('\n');
  }

  @override
  List<({String role, String content})> getConversationHistory() =>
      _promptBuilder.getHistory();

  @override
  void clearHistory() {
    _promptBuilder.clearHistory();
  }

  @override
  void setConversationContext(ConversationContext? context) {
    _conversationContext = context;
  }

  @override
  void setToolPreferenceTracker(ToolPreferenceTracker? tracker) {
    _preferenceTracker = tracker;
  }
}
