import 'dart:async';
import 'dart:convert';

import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/agent/agent_tool.dart';
import 'package:aios/domain/agent/audit_log.dart';
import 'package:aios/domain/agent/confirmation_gate.dart';
import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/error_recovery.dart';
import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/llm_engine.dart';
import 'package:aios/domain/agent/loop_detector.dart';
import 'package:aios/domain/agent/permission_gate.dart';
import 'package:aios/domain/agent/risk_classifier.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:aios/domain/agent/tool_permission_mapper.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/entities/agent_models.dart';

class ReactStrategy implements AgentStrategy {
  ReactStrategy({
    required LlmEngine engine,
    ToolContext? toolContext,
    Map<String, AgentTool>? basicTools,
    Map<String, ExtendedTool>? extendedTools,
  })  : _engine = engine,
        _toolContext = toolContext,
        _basicTools = basicTools ?? {},
        _extendedTools = extendedTools ?? {};

  final LlmEngine _engine;
  final ToolContext? _toolContext;
  final Map<String, AgentTool> _basicTools;
  final Map<String, ExtendedTool> _extendedTools;

  ConversationContext? _conversationContext;
  ToolPreferenceTracker? _preferenceTracker;

  LlmChatSession? _session;
  List<LlmToolSchema>? _cachedToolSchemas;

  bool _cancelled = false;

  final _riskClassifier = RiskClassifier();
  final _loopDetector = LoopDetector();
  final _confirmationGate = ConfirmationGate();
  final _permissionGate = PermissionGate();
  final _auditLog = AuditLog();
  late final ErrorRecovery _errorRecovery = ErrorRecovery(
    availableTools: _allToolNames,
  );

  PermissionChecker? _permissionChecker;

  Set<String> get _allToolNames =>
      {..._basicTools.keys, ..._extendedTools.keys};

  @override
  void setPermissionChecker(PermissionChecker? checker) {
    _permissionChecker = checker;
  }

  LlmChatSession _ensureSession() {
    if (_session == null) {
      _session = _engine.createSession(_systemPrompt);
      _cachedToolSchemas = _buildToolSchemas();
    }
    return _session!;
  }

  static const _tag = 'AIOS-React';
  static const _maxToolRetries = 1;

  String get _systemPrompt {
    final base = StringBuffer();
    base.writeln(
      'You are AIOS, an on-device phone assistant.',
    );
    base.writeln(
      'Use tools to help the user. '
      'Respond concisely in the user\'s language.',
    );
    base.writeln(
      'When calling a tool, '
      'ALWAYS include ALL required parameters as JSON.',
    );
    base.writeln(
      'Example: calculator needs {"expression": "2+3"}',
    );
    base.writeln(
      'If no tool is needed, answer directly.',
    );

    final contextStr =
        _conversationContext?.toPromptContext() ?? '';
    if (contextStr.isNotEmpty) {
      base.writeln();
      base.write(contextStr);
    }

    final prefStr =
        _preferenceTracker?.toPromptContext() ?? '';
    if (prefStr.isNotEmpty) {
      base.writeln();
      base.write(prefStr);
    }

    return base.toString();
  }

  List<LlmToolSchema> _buildToolSchemas() {
    final schemas = <LlmToolSchema>[];
    for (final tool in _basicTools.values) {
      schemas.add(_basicToolToSchema(tool));
    }
    for (final tool in _extendedTools.values) {
      schemas.add(_extendedToolToSchema(tool));
    }
    return schemas;
  }

  LlmToolSchema _basicToolToSchema(AgentTool tool) {
    return LlmToolSchema(
      name: tool.name,
      description: tool.description,
      parameters: _parseParams(tool.parameters),
    );
  }

  LlmToolSchema _extendedToolToSchema(ExtendedTool tool) {
    return LlmToolSchema(
      name: tool.name,
      description: tool.description,
      parameters: _parseParams(tool.parameters),
    );
  }

  List<LlmToolParamSchema> _parseParams(String paramsStr) {
    try {
      final decoded = jsonDecode(paramsStr);
      if (decoded is! Map<String, dynamic>) return [];
      return decoded.entries.map((e) {
        final desc = e.value.toString();
        if (desc.contains('|')) {
          final values = desc
              .split('|')
              .map(
                (v) => v.replaceAll(RegExp(r'[^a-z_]'), ''),
              )
              .where((v) => v.isNotEmpty)
              .toList();
          if (values.isNotEmpty) {
            return LlmToolParamSchema(
              name: e.key,
              description: desc,
              required: true,
              isEnum: true,
              enumValues: values,
            );
          }
        }
        return LlmToolParamSchema(
          name: e.key,
          description: desc,
          required: true,
        );
      }).toList();
    } on Object {
      return [];
    }
  }

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

      final session = _ensureSession();

      final tools = _cachedToolSchemas!;
      final generationConfig = LlmGenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.9,
        penalty: 1.1,
        maxTokens: maxTokens,
      );

      var userParts = [LlmContentPart.text(prompt)];

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

        String fullContent = '';
        final Map<int, _ToolCallAccumulator> toolCallBuilders =
            {};

        try {
          await for (final chunk in session.chat(
            userParts,
            config: generationConfig,
            tools: tools,
          )) {
            if (_cancelled) break;
            if (chunk.text != null) fullContent += chunk.text!;

            if (chunk.toolCallDeltas != null) {
              for (final tc in chunk.toolCallDeltas!) {
                toolCallBuilders.putIfAbsent(
                  tc.index,
                  () => _ToolCallAccumulator(),
                );
                final builder = toolCallBuilders[tc.index]!;
                if (tc.id != null) builder.id = tc.id;
                if (tc.name != null) builder.name = tc.name;
                if (tc.arguments != null) {
                  builder.arguments += tc.arguments!;
                }
              }
            }
          }
        } on Object catch (e) {
          print('[$_tag] ERROR: generation stream error - $e');
        }

        onStep?.call(const AgentStep('thinking_end', ''));

        print('[$_tag] Step $i: '
            'content="${fullContent.substring(0, fullContent.length > 200 ? 200 : fullContent.length)}", '
            'toolCalls=${toolCallBuilders.length}');

        if (toolCallBuilders.isEmpty) {
          final answer = fullContent.trim();
          if (answer.isNotEmpty) {
            steps.add(AgentStep('answer', answer));
            onStep?.call(steps.last);
            _recordTurn(prompt, steps);
            return AgentResult(steps: steps, success: true);
          }

          final retryCount = steps
              .where((s) => s.type == 'phase1_retry')
              .length;
          if (retryCount < 2) {
            steps.add(AgentStep(
              'phase1_retry',
              'Format retry ${retryCount + 1}/2',
            ));
            onStep?.call(steps.last);
            userParts = [
              LlmContentPart.text(
                'Please use a tool or provide a direct answer.',
              ),
            ];
            continue;
          }

          steps.add(
            AgentStep('answer', '요청을 처리하지 못했습니다.'),
          );
          onStep?.call(steps.last);
          break;
        }

        for (final entry in toolCallBuilders.entries) {
          if (_cancelled) break;

          final builder = entry.value;
          final toolName = builder.name ?? '';
          Map<String, dynamic> toolArgs = {};
          try {
            if (builder.arguments.isNotEmpty) {
              toolArgs = Map<String, dynamic>.from(
                jsonDecode(builder.arguments) as Map,
              );
            }
          } on Object {
            print('[$_tag] WARN: tool args parse error');
          }

          if (toolArgs.isEmpty) {
            final inferred = _inferToolArgs(toolName, prompt);
            if (inferred != null) {
              toolArgs = inferred;
              print(
                '[$_tag] Auto-inferred args for $toolName: $toolArgs',
              );
            }
          }

          final argsJson = jsonEncode(toolArgs);

          steps.add(AgentStep(
            'action',
            'Using tool: $toolName',
            toolName: toolName,
            toolArgs: argsJson,
          ));
          onStep?.call(steps.last);

          final requiredPerm = ToolPermissionMapper
              .getRequiredPermission(toolName, argsJson);
          if (requiredPerm != null) {
            final hasPermission =
                await _checkPermission(requiredPerm.key);
            if (!hasPermission) {
              final granted =
                  await _permissionGate.requestPermission(
                requiredPerm,
                toolName,
                onStep ?? (_) {},
              );
              if (!granted) {
                final result =
                    'Error: ${requiredPerm.displayName} 권한이 거부되었습니다';
                steps.add(AgentStep(
                  'observation',
                  result,
                  toolName: toolName,
                  toolResult: result,
                ));
                onStep?.call(steps.last);
                session.addToolResult(toolName, result);
                continue;
              }
            }
          }

          final risk = _riskClassifier.classify(
            toolName,
            argsJson,
          );

          final validationError =
              await _validateTool(toolName, argsJson);
          if (validationError != null) {
            steps.add(AgentStep(
              'observation',
              validationError,
              toolName: toolName,
              toolResult: validationError,
            ));
            onStep?.call(steps.last);
            session.addToolResult(toolName, validationError);
            continue;
          }

          if (risk == ToolRisk.high || risk == ToolRisk.critical) {
            final approved =
                await _confirmationGate.requestConfirmation(
              risk,
              toolName,
              argsJson,
              onStep ?? (_) {},
            );
            if (!approved) {
              _auditLog.add(
                toolName,
                argsJson,
                risk,
                false,
                'Cancelled',
              );
              const result = 'Action cancelled by user';
              steps.add(AgentStep(
                'observation',
                result,
                toolName: toolName,
                toolResult: result,
              ));
              onStep?.call(steps.last);
              session.addToolResult(toolName, result);
              continue;
            }
          }

          final toolResult = await _executeToolDirect(
            toolName,
            toolArgs,
          );

          _auditLog.add(
            toolName,
            argsJson,
            risk,
            true,
            toolResult,
          );
          _preferenceTracker?.recordToolUse(toolName);

          steps.add(AgentStep(
            'observation',
            toolResult,
            toolName: toolName,
            toolResult: toolResult,
          ));
          onStep?.call(steps.last);

          session.addToolResult(toolName, toolResult);

          final recoveryHint = _errorRecovery.analyze(
            toolName,
            argsJson,
            toolResult,
          );
          if (recoveryHint != null &&
              recoveryHint.promptNudge.isNotEmpty) {
            print(
              '[$_tag] Recovery: type=${recoveryHint.type}',
            );
            if (recoveryHint.shouldRetry) {
              final toolPrompt = _getToolPrompt(toolName);
              userParts = [
                LlmContentPart.text(
                  '${recoveryHint.promptNudge}\n'
                  '$toolPrompt',
                ),
              ];
            }
          }

          final loopResult = _loopDetector.record(
            toolName,
            argsJson,
            toolResult,
          );

          if (loopResult is LoopForceBreak) {
            steps.add(
              AgentStep('answer', '작업이 반복 감지로 중단되었습니다.'),
            );
            onStep?.call(steps.last);
            _recordTurn(prompt, steps);
            return AgentResult(steps: steps, success: false);
          }
        }

        userParts = [];
      }

      if (steps.every((s) => s.type != 'answer')) {
        steps.add(
          AgentStep('answer', '작업을 완료하지 못했습니다.'),
        );
        onStep?.call(steps.last);
      }
    } on Object catch (e) {
      print('[$_tag] ERROR: Agent run crashed: $e');
      if (steps.every((s) => s.type != 'answer')) {
        steps.add(AgentStep('answer', 'An error occurred: $e'));
        onStep?.call(steps.last);
      }
    }

    final success = steps.any((s) => s.type == 'answer');
    _recordTurn(prompt, steps);
    return AgentResult(steps: steps, success: success);
  }

  Future<bool> _checkPermission(String permissionKey) async {
    if (_permissionChecker == null) return true;
    try {
      return await _permissionChecker!(permissionKey);
    } on Object catch (e) {
      print('[$_tag] WARN: permission check failed - $e');
      return true;
    }
  }

  Future<String?> _validateTool(
    String name,
    String argsJson,
  ) async {
    final basicTool = _basicTools[name];
    if (basicTool != null) {
      return basicTool.validate(argsJson);
    }

    final extendedTool = _extendedTools[name];
    if (extendedTool != null) {
      final ctx = _toolContext;
      if (ctx == null) {
        return 'Error: ToolContext not initialized';
      }
      return extendedTool.validate(argsJson, ctx);
    }

    return null;
  }

  Future<String> _executeToolDirect(
    String name,
    Map<String, dynamic> args,
  ) async {
    final argsJson = jsonEncode(args);
    final basicTool = _basicTools[name];
    final extendedTool = _extendedTools[name];

    if (basicTool != null) {
      return basicTool.execute(argsJson);
    }

    if (extendedTool != null) {
      final ctx = _toolContext;
      if (ctx == null) {
        return 'Error: ToolContext not initialized';
      }
      return extendedTool.execute(argsJson, ctx);
    }

    return "Error: Unknown tool '$name'";
  }

  String _getToolPrompt(String name) {
    final basicTool = _basicTools[name];
    if (basicTool != null) {
      return 'Tool "$name" help: ${basicTool.toolPrompt}';
    }
    final extendedTool = _extendedTools[name];
    if (extendedTool != null) {
      return 'Tool "$name" help: ${extendedTool.toolPrompt}';
    }
    return '';
  }

  Map<String, dynamic>? _inferToolArgs(
    String toolName,
    String userMessage,
  ) {
    final msg = userMessage.toLowerCase();
    switch (toolName) {
      case 'calculator':
        final expr = _extractMathExpr(msg);
        if (expr != null) return {'expression': expr};
        return null;
      case 'notepad':
        final writeMatch = RegExp(
          r'(?:write|save|note|store|record)\s+(.+)',
          caseSensitive: false,
        ).firstMatch(userMessage);
        if (writeMatch != null) {
          return {
            'action': 'write',
            'key':
                'note_${DateTime.now().millisecondsSinceEpoch}',
            'content': writeMatch.group(1)!.trim(),
          };
        }
        return {'action': 'list'};
      case 'timer':
        final durationMatch = RegExp(
          r'(\d+)\s*(?:second|sec|minute|min)',
          caseSensitive: false,
        ).firstMatch(msg);
        if (durationMatch != null) {
          final value =
              int.tryParse(durationMatch.group(1)!) ?? 0;
          final unit = msg.contains('min') ? value * 60 : value;
          return {'action': 'set', 'seconds': unit};
        }
        return null;
      default:
        return null;
    }
  }

  String? _extractMathExpr(String msg) {
    final ops = {
      'plus': '+',
      'added to': '+',
      'and': '+',
      'minus': '-',
      'less': '-',
      'subtract': '-',
      'times': '*',
      'multiplied by': '*',
      'x': '*',
      'divided by': '/',
      'over': '/',
    };
    var expr = msg;
    expr = expr.replaceAll(
      RegExp(r'calculate\s*', caseSensitive: false),
      '',
    );
    expr = expr.replaceAll(
      RegExp(r'what\s+is\s*', caseSensitive: false),
      '',
    );
    expr = expr.replaceAll(
      RegExp(r'compute\s*', caseSensitive: false),
      '',
    );
    for (final entry in ops.entries) {
      expr = expr.replaceAll(entry.key, entry.value);
    }
    expr = expr
        .replaceAll(RegExp(r'[^\d+\-*/.()% ]'), '')
        .trim();
    if (expr.isEmpty || !RegExp(r'\d').hasMatch(expr)) {
      return null;
    }
    if (!RegExp(r'[+\-*/]').hasMatch(expr)) return null;
    return expr;
  }

  void _recordTurn(
    String userMessage,
    List<AgentStep> steps,
  ) {
    if (_conversationContext == null) return;
    final answerStep =
        steps.where((s) => s.type == 'answer').lastOrNull;
    if (answerStep == null) return;
    final toolSteps = steps
        .where(
          (s) => s.type == 'action' && s.toolName.isNotEmpty,
        )
        .toList();
    final toolUsed = toolSteps.isNotEmpty
        ? toolSteps.first.toolName
        : null;
    _conversationContext!.addTurn(
      userMessage,
      answerStep.content,
      toolUsed: toolUsed,
    );
  }

  @override
  void cancel() {
    _cancelled = true;
    _engine.cancelGeneration();
    _confirmationGate.cancel();
    _permissionGate.cancel();
  }

  @override
  void resolveConfirmation(bool approved) {
    _confirmationGate.resolve(approved);
  }

  @override
  void resolvePermission(bool granted) {
    _permissionGate.resolve(granted);
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
  List<({String role, String content})>
      getConversationHistory() => [];

  @override
  void clearHistory() {
    _session = null;
    _cachedToolSchemas = null;
  }

  @override
  Future<void> warmup() async {
    await _engine.warmup();
  }

  @override
  void setConversationContext(ConversationContext? context) {
    _conversationContext = context;
  }

  @override
  void setToolPreferenceTracker(
    ToolPreferenceTracker? tracker,
  ) {
    _preferenceTracker = tracker;
  }
}

class _ToolCallAccumulator {
  String? id;
  String? name;
  String arguments = '';
}
