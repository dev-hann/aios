import 'dart:async';
import 'dart:developer' as developer;

import 'package:aios/agent/tools/app_launcher_tool.dart';
import 'package:aios/agent/tools/calculator_tool.dart';
import 'package:aios/agent/tools/contact_search_tool.dart';
import 'package:aios/agent/tools/notepad_tool.dart';
import 'package:aios/agent/tools/notification_tool.dart';
import 'package:aios/agent/tools/phone_caller_tool.dart';
import 'package:aios/agent/tools/screen_action_tool.dart';
import 'package:aios/agent/tools/screen_reader_tool.dart';
import 'package:aios/agent/tools/sms_sender_tool.dart';
import 'package:aios/agent/tools/timer_tool.dart';
import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/agent/agent_tool.dart';
import 'package:aios/domain/agent/audit_log.dart';
import 'package:aios/domain/agent/confirmation_gate.dart';
import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/loop_detector.dart';
import 'package:aios/domain/agent/prompt_builder.dart';
import 'package:aios/domain/agent/response_parser.dart';
import 'package:aios/domain/agent/risk_classifier.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/repositories/llm_repository.dart';

class ReactStrategy implements AgentStrategy {
  ReactStrategy(this._llmRepository, {ToolContext? toolContext})
      : _toolContext = toolContext;

  final LlmRepository _llmRepository;
  final ToolContext? _toolContext;

  bool _cancelled = false;
  final _notes = <String, String>{};

  final _riskClassifier = RiskClassifier();
  final _loopDetector = LoopDetector();
  final _confirmationGate = ConfirmationGate();
  final _auditLog = AuditLog();

  late final PromptBuilder _promptBuilder =
      PromptBuilder(_llmRepository);

  late final Map<String, AgentTool> _basicTools = {
    for (final tool in [
      CalculatorTool(),
      TimerTool(),
      NotePadTool(_notes),
    ])
      tool.name: tool,
  };

  late final Map<String, ExtendedTool> _extendedTools = {
    for (final tool in [
      ScreenReaderTool(),
      ScreenFindTool(),
      ScreenActionTool(),
      AppLauncherTool(),
      NotificationTool(),
      ContactSearchTool(),
      SmsSenderTool(),
      PhoneCallerTool(),
    ])
      tool.name: tool,
  };

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
    final systemPrompt = _promptBuilder.buildSystemPrompt(
      getToolManifest(),
    );

    developer.log(
      'Agent run: prompt="${prompt.substring(0, prompt.length > 50 ? 50 : prompt.length)}", '
      'maxIter=$maxIterations',
      name: _tag,
    );

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

        final response = await _generateResponse(
          systemPrompt,
          maxTokens,
        );

        developer.log(
          'Iteration $i LLM: ${response.substring(0, response.length > 200 ? 200 : response.length)}',
          name: _tag,
        );

        onStep?.call(const AgentStep('thinking_end', ''));

        _promptBuilder.addAssistantMessage(response);

        final parsed = _responseParser.parse(response);

        if (parsed is ParseAction) {
          steps.add(
            AgentStep(
              'action',
              'Using tool: ${parsed.toolName}',
              toolName: parsed.toolName,
              toolArgs: parsed.args,
            ),
          );
          onStep?.call(steps.last);

          final observation = await _executeTool(
            parsed.toolName,
            parsed.args,
            onStep,
          );

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
        } else if (parsed is ParseAnswer) {
          steps.add(AgentStep('answer', parsed.text));
          onStep?.call(steps.last);
          break;
        } else {
          final directAnswer = response.trim();
          if (directAnswer.isNotEmpty) {
            steps.add(AgentStep('answer', directAnswer));
            onStep?.call(steps.last);
          } else if (i >= maxIterations - 1) {
            steps.add(AgentStep(
              'answer',
              '모델이 빈 응답을 생성했습니다. 다시 시도해주세요.',
            ));
            onStep?.call(steps.last);
          }
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
            ? '작업을 완료하지 못했습니다. 마지막 관찰 결과: $truncated'
            : '작업을 완료하지 못했습니다. 다시 시도해주세요.';
        steps.add(AgentStep('answer', summary));
        onStep?.call(steps.last);
      }
    } on Object catch (e) {
      developer.log(
        'Agent run crashed: $e',
        name: _tag,
        level: 1000,
      );
      if (steps.every((s) => s.type != 'answer')) {
        steps.add(AgentStep(
          'answer',
          'An error occurred: $e',
        ));
        onStep?.call(steps.last);
      }
    }

    final success = steps.any((s) => s.type == 'answer');
    return AgentResult(steps: steps, success: success);
  }

  Future<String> _generateResponse(
    String systemPrompt,
    int maxTokens,
  ) async {
    final history = _promptBuilder.getHistory();
    final chatHistory = history
        .map((m) => ChatMessage(
              id: '${m.role}_${DateTime.now().millisecondsSinceEpoch}',
              role: m.role,
              content: m.content,
              createdAt: DateTime.now(),
            ))
        .toList();

    final responseBuffer = StringBuffer();
    final completer = Completer<void>();

    final tokenSub = _llmRepository.tokenStream.listen(
      (token) {
        responseBuffer.write(token);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (Object e) {
        developer.log(
          'Token stream error: $e',
          name: _tag,
          level: 1000,
        );
        if (!completer.isCompleted) completer.complete();
      },
    );

    try {
      await _llmRepository.sendMessage(
        chatHistory,
        userMessage: history.last.content,
        maxTokens: maxTokens,
      );

      await completer.future;
    } on Object catch (e) {
      developer.log(
        'Generate response error: $e',
        name: _tag,
        level: 1000,
      );
    } finally {
      await tokenSub.cancel();
    }

    return responseBuffer.toString();
  }

  Future<String> _executeTool(
    String name,
    String args,
    void Function(AgentStep)? onStep,
  ) async {
    final risk = _riskClassifier.classify(name, args);

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

    final basicTool = _basicTools[name];
    if (basicTool != null) {
      final result = basicTool.execute(args);
      _auditLog.add(name, args, risk, true, result);
      return result;
    }

    final extendedTool = _extendedTools[name];
    if (extendedTool != null) {
      final ctx = _toolContext;
      if (ctx == null) {
        return _noContextError(name, args, risk);
      }
      final result = await extendedTool.execute(args, ctx);
      _auditLog.add(name, args, risk, true, result);
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
      lines.add('- ${tool.name}: ${tool.description}');
    }
    for (final tool in _extendedTools.values) {
      lines.add('- ${tool.name}: ${tool.description}');
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
}
