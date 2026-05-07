import 'dart:async';
import 'dart:convert';

import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/agent/agent_tool.dart';
import 'package:aios/domain/agent/audit_log.dart';
import 'package:aios/domain/agent/confirmation_gate.dart';
import 'package:aios/domain/agent/conversation_context.dart';
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

  late final PromptBuilder _promptBuilder = PromptBuilder();

  Set<String> get _allToolNames =>
      {..._basicTools.keys, ..._extendedTools.keys};

  late final ResponseParser _responseParser =
      ResponseParser(_allToolNames);

  static const _tag = 'AIOS-React';

  @override
  Future<AgentResult> execute(
    String prompt, {
    int maxIterations = 8,
    int maxTokens = 512,
    void Function(AgentStep)? onStep,
  }) async {
    _cancelled = false;
    _loopDetector.reset();
    final steps = <AgentStep>[];

    print('[$_tag] Agent run: prompt="${prompt.substring(0, prompt.length > 50 ? 50 : prompt.length)}", maxIter=$maxIterations');

    final runStartTime = DateTime.now();
    const maxRunDuration = Duration(seconds: 120);

    try {
      steps.add(AgentStep('thought', 'Processing: $prompt'));
      onStep?.call(steps.last);

      _promptBuilder.addUserMessage(prompt);

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
        final routingManifest = _getRoutingManifest();
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

        print('[$_tag] Phase1 iter$i: ${phase1Response.substring(0, phase1Response.length > 200 ? 200 : phase1Response.length)}');

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
            print('[$_tag] Phase1 direct execute: tool=${parsed.toolName}');
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

          final loopResult = _loopDetector.record(
            parsed.toolName,
            parsed.args,
            observation,
          );

          if (loopResult is LoopWarning) {
            final nudge =
                'WARNING: You have called \'${parsed.toolName}\' '
                '${loopResult.count} times with similar arguments. '
                'Provide your final Answer now, or try a different approach.';
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
              'If you have enough information, provide your final Answer now.',
            );
          }
        } else {
          print('[$_tag] WARN: ParseEmpty iter$i, adding format nudge');
          _promptBuilder.addObservation(
            'IMPORTANT: You must respond with ONLY '
            '"Action: tool_name" or "Answer: your text". '
            'Do not write anything else. '
            'Try again.',
          );
          if (i >= maxIterations - 1) {
            steps.add(AgentStep(
              'answer',
              '\uC791\uC5C5\uC744 \uC644\uB8CC\uD558\uC9C0 \uBABB\uD588\uC2B5\uB2C8\uB2E4. '
              '\uB2E4\uC2DC \uC2DC\uB3C4\uD574\uC8FC\uC138\uC694.',
            ));
            onStep?.call(steps.last);
            break;
          }
          continue;
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
            ? '\uC791\uC5C5\uC744 \uC644\uB8CC\uD558\uC9C0 \uBABB\uD588\uC2B5\uB2C8\uB2E4. '
                '\uB9C8\uC9C0\uB9C9 \uAD00\uCC30 \uACB0\uACFC: $truncated'
            : '\uC791\uC5C5\uC744 \uC644\uB8CC\uD558\uC9C0 \uBABB\uD588\uC2B5\uB2C8\uB2E4. '
                '\uB2E4\uC2DC \uC2DC\uB3C4\uD574\uC8FC\uC138\uC694.';
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
            await extendedTool.phaseContext('', _toolContext!);
      }
    } else {
      toolPromptText = basicTool!.toolPrompt;
      extraContext = await basicTool.phaseContext('');
    }

    final toolSystem = _promptBuilder.buildToolPrompt(
      toolName,
      toolPromptText,
      extraContext: extraContext,
    );

    final phase2UserMessage = _buildPhase2UserMessage(originalPrompt);

    final phase2History = <ChatMessage>[
      ChatMessage(
        id: 'system_p2_${DateTime.now().millisecondsSinceEpoch}',
        role: 'system',
        content: toolSystem,
        createdAt: DateTime.now(),
      ),
      ChatMessage(
        id: 'user_p2_${DateTime.now().millisecondsSinceEpoch}',
        role: 'user',
        content: phase2UserMessage,
        createdAt: DateTime.now(),
      ),
    ];

    final phase2Response = await _generateResponseFromPrompt(
      phase2History,
      phase2UserMessage,
      maxTokens,
    );

    print('[$_tag] Phase2 response="$phase2Response"');

    final parsed = _responseParser.parse(phase2Response);
    if (parsed is ParseAction) {
      return _executeTool(parsed.toolName, parsed.args, onStep);
    }

    return "Error: Could not execute $toolName";
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
      final validationError = await extendedTool.validate(args, ctx);
      if (validationError != null) return validationError;
    }

    if (risk == ToolRisk.high || risk == ToolRisk.critical) {
      final approved = await _confirmationGate.requestConfirmation(
        risk,
        name,
        args,
        onStep ?? (_) {},
      );
      if (!approved) {
        _auditLog.add(name, args, risk, false, 'Cancelled by user');
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
    _auditLog.add(name, args, risk, false, 'ToolContext not initialized');
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
