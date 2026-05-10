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
import 'package:aios/domain/agent/tool_arg_inference.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:aios/domain/agent/tool_json_parser.dart';
import 'package:aios/domain/agent/tool_permission_mapper.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/agent/tool_result.dart';
import 'package:aios/domain/agent/truncate.dart';
import 'package:aios/domain/entities/agent_models.dart';

class ReactStrategy implements AgentStrategy {
  ReactStrategy({
    required LlmEngine engine,
    ToolContext? toolContext,
    Map<String, AgentTool>? basicTools,
    Map<String, ExtendedTool>? extendedTools,
  }) : _engine = engine,
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

  Set<String> get _allToolNames => {
    ..._basicTools.keys,
    ..._extendedTools.keys,
  };

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

  String get _systemPrompt {
    final base = StringBuffer()
      ..writeln('You are AIOS, an on-device phone assistant.')
      ..writeln(
        "Use tools to help the user. Respond concisely in the user's language.",
      )
      ..writeln(
        'When calling a tool, ALWAYS include ALL required parameters as JSON.',
      )
      ..writeln('Example: calculator needs {"expression": "2+3"}')
      ..writeln('If no tool is needed, answer directly.')
      ..writeln()
      ..writeln('CRITICAL RULES FOR screen_action:')
      ..writeln(
        '- Each screen_action call does exactly ONE action. '
        'Do NOT mix parameters from different actions in one call.',
      )
      ..writeln(
        '- NEVER put "content" and "global_action" in the same call. '
        'They belong to different actions.',
      )
      ..writeln('- Search workflow requires 3 SEPARATE calls:')
      ..writeln('  1) {"action":"tap","text":"검색"} → open search field')
      ..writeln('  2) {"action":"type","content":"query"} → type text')
      ..writeln('  3) {"action":"global","global_action":"enter"} → submit')
      ..writeln(
        '- Complex tasks always need MULTIPLE sequential tool calls. '
        'Do not stop until the task is fully done.',
      );

    final contextStr = _conversationContext?.toPromptContext() ?? '';
    if (contextStr.isNotEmpty) {
      base
        ..writeln()
        ..write(contextStr);
    }

    final prefStr = _preferenceTracker?.toPromptContext() ?? '';
    if (prefStr.isNotEmpty) {
      base
        ..writeln()
        ..write(prefStr);
    }

    return base.toString();
  }

  List<LlmToolSchema> _buildToolSchemas() {
    final schemas = <LlmToolSchema>[];
    for (final tool in _basicTools.values) {
      schemas.add(_toolToSchema(tool.name, tool.toolPrompt, tool.parameters));
    }
    for (final tool in _extendedTools.values) {
      schemas.add(_toolToSchema(tool.name, tool.toolPrompt, tool.parameters));
    }
    return schemas;
  }

  LlmToolSchema _toolToSchema(
    String name,
    String toolPrompt,
    String parameters,
  ) {
    return LlmToolSchema(
      name: name,
      description: toolPrompt,
      parameters: _parseParams(parameters),
    );
  }

  List<LlmToolParamSchema> _parseParams(String paramsStr) {
    try {
      final decoded = jsonDecode(paramsStr);
      if (decoded is! Map<String, dynamic>) return [];
      return decoded.entries.map((e) {
        final desc = e.value.toString();
        final type = _detectType(desc);
        if (desc.contains('|')) {
          final values = desc
              .split('|')
              .map((v) => v.replaceAll(RegExp('[^a-z_]'), ''))
              .where((v) => v.isNotEmpty)
              .toList();
          if (values.isNotEmpty) {
            return LlmToolParamSchema(
              name: e.key,
              description: desc,
              type: type,
              required: true,
              isEnum: true,
              enumValues: values,
            );
          }
        }
        final example = _extractExample(desc);
        return LlmToolParamSchema(
          name: e.key,
          description: desc,
          type: type,
          required: !_isOptional(desc),
          example: example,
        );
      }).toList();
    } on Object {
      return [];
    }
  }

  String _detectType(String desc) {
    final lower = desc.toLowerCase();
    if (lower.contains('boolean') || lower.contains('(true|false)')) {
      return 'boolean';
    }
    if (lower.contains('integer') || lower.contains('int ')) {
      return 'integer';
    }
    if (lower.contains('number') || lower.contains('float')) {
      return 'number';
    }
    return 'string';
  }

  bool _isOptional(String desc) {
    return desc.toLowerCase().contains('optional');
  }

  String? _extractExample(String desc) {
    final match = RegExp(
      r'\(e\.g\.?\s*([^)]+)\)',
      caseSensitive: false,
    ).firstMatch(desc);
    return match?.group(1)?.trim();
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

    print(
      '[$_tag] Agent run: '
      'prompt="${truncate(prompt, 50)}", '
      'maxIter=$maxIterations',
    );

    final runStartTime = DateTime.now();
    const maxRunDuration = Duration(seconds: 120);

    try {
      steps.add(AgentStep('thought', 'Processing: $prompt'));
      onStep?.call(steps.last);

      final session = _ensureSession();

      final tools = _cachedToolSchemas!;
      final generationConfig = LlmGenerationConfig(
        temperature: 0.7,
        topP: 0.9,
        maxTokens: maxTokens,
      );

      var userParts = [LlmContentPart.text(prompt)];

      for (var i = 0; i < maxIterations; i++) {
        if (_cancelled) break;

        final elapsed = DateTime.now().difference(runStartTime);
        if (elapsed > maxRunDuration) {
          steps.add(
            AgentStep('thought', 'Time limit reached (${elapsed.inSeconds}s).'),
          );
          onStep?.call(steps.last);
          break;
        }

        steps.add(AgentStep('thought', 'Thinking (step ${i + 1})...'));
        onStep?.call(steps.last);
        onStep?.call(const AgentStep('thinking_start', ''));

        String fullContent = '';
        final Map<int, _ToolCallAccumulator> toolCallBuilders = {};

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
                  _ToolCallAccumulator.new,
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

        print(
          '[$_tag] Step $i: '
          'content="${truncate(fullContent, 200)}", '
          'toolCalls=${toolCallBuilders.length}',
        );

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
            steps.add(
              AgentStep('phase1_retry', 'Format retry ${retryCount + 1}/2'),
            );
            onStep?.call(steps.last);
            userParts = [
              const LlmContentPart.text(
                'Please use a tool or provide a direct answer.',
              ),
            ];
            continue;
          }

          steps.add(const AgentStep('answer', '요청을 처리하지 못했습니다.'));
          onStep?.call(steps.last);
          break;
        }

        for (final entry in toolCallBuilders.entries) {
          if (_cancelled) break;

          final builder = entry.value;
          final toolName = builder.name ?? '';
          print('[$_tag] Processing tool: $toolName');
          Map<String, dynamic> toolArgs = {};
          if (builder.arguments.isNotEmpty) {
            toolArgs = tryParseToolJson(builder.arguments, _tag);
          }
          print('[$_tag] Tool args: $toolArgs');

          if (toolArgs.isEmpty) {
            final inferred = _inferToolArgs(toolName, prompt);
            if (inferred != null) {
              toolArgs = inferred;
              print('[$_tag] Auto-inferred args for $toolName: $toolArgs');
            }
          }

          final argsJson = jsonEncode(toolArgs);

          steps.add(
            AgentStep(
              'action',
              'Using tool: $toolName',
              toolName: toolName,
              toolArgs: argsJson,
            ),
          );
          onStep?.call(steps.last);

          final requiredPerm = ToolPermissionMapper.getRequiredPermission(
            toolName,
            argsJson,
          );
          if (requiredPerm != null) {
            final hasPermission = await _checkPermission(requiredPerm.key);
            if (!hasPermission) {
              final granted = await _permissionGate.requestPermission(
                requiredPerm,
                toolName,
                onStep ?? (_) {},
              );
              if (!granted) {
                final result = 'Error: ${requiredPerm.displayName} 권한이 거부되었습니다';
                steps.add(
                  AgentStep(
                    'observation',
                    result,
                    toolName: toolName,
                    toolResult: result,
                  ),
                );
                onStep?.call(steps.last);
                session.addToolResult(toolName, result);
                continue;
              }
            }
          }

          final risk = _riskClassifier.classify(toolName, argsJson);
          print('[$_tag] Risk: $risk for $toolName');

          final validationError = await _validateTool(toolName, argsJson);
          if (validationError != null) {
            print('[$_tag] Validation error: $validationError');
            steps.add(
              AgentStep(
                'observation',
                validationError,
                toolName: toolName,
                toolResult: validationError,
              ),
            );
            onStep?.call(steps.last);
            session.addToolResult(toolName, validationError);
            continue;
          }

          if (risk == ToolRisk.high || risk == ToolRisk.critical) {
            print('[$_tag] ConfirmationGate: requesting for $toolName');
            final approved = await _confirmationGate.requestConfirmation(
              risk,
              toolName,
              argsJson,
              onStep ?? (_) {},
            );
            print('[$_tag] ConfirmationGate: approved=$approved');
            if (!approved) {
              _auditLog.add(toolName, argsJson, risk, false, 'Cancelled');
              const result = 'Action cancelled by user';
              steps.add(
                AgentStep(
                  'observation',
                  result,
                  toolName: toolName,
                  toolResult: result,
                ),
              );
              onStep?.call(steps.last);
              session.addToolResult(toolName, result);
              continue;
            }
          }

          print('[$_tag] Executing tool: $toolName');
          final toolResult = await _executeToolDirect(toolName, toolArgs);
          final toolContent = toolResult.toContent();
          print(
            '[$_tag] Tool result (${toolContent.length} chars): ${truncate(toolContent, 200)}',
          );

          _auditLog.add(toolName, argsJson, risk, true, toolContent);
          _preferenceTracker?.recordToolUse(toolName);

          steps.add(
            AgentStep(
              'observation',
              toolContent,
              toolName: toolName,
              toolResult: toolContent,
            ),
          );
          onStep?.call(steps.last);

          session.addToolResult(toolName, toolContent);

          final recoveryHint = _errorRecovery.analyze(
            toolName,
            argsJson,
            toolResult,
          );
          if (recoveryHint != null && recoveryHint.promptNudge.isNotEmpty) {
            print('[$_tag] Recovery: type=${recoveryHint.type}');
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
            steps.add(const AgentStep('answer', '작업이 반복 감지로 중단되었습니다.'));
            onStep?.call(steps.last);
            _recordTurn(prompt, steps);
            return AgentResult(steps: steps, success: false);
          }
        }

        userParts = [];
      }

      if (steps.every((s) => s.type != 'answer')) {
        steps.add(const AgentStep('answer', '작업을 완료하지 못했습니다.'));
        onStep?.call(steps.last);
      }
    } on Object catch (e) {
      print('[$_tag] ERROR: Agent run crashed: $e');
      if (steps.every((s) => s.type != 'answer')) {
        steps.add(AgentStep('answer', '오류가 발생했습니다: $e'));
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

  Future<String?> _validateTool(String name, String argsJson) async {
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

  Future<ToolResult> _executeToolDirect(
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
        return const ToolResult.err('ToolContext not initialized');
      }
      return extendedTool.execute(argsJson, ctx);
    }

    return ToolResult.err("Unknown tool '$name'");
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

  Map<String, dynamic>? _inferToolArgs(String toolName, String userMessage) {
    return inferToolArgs(toolName, userMessage);
  }

  void _recordTurn(String userMessage, List<AgentStep> steps) {
    if (_conversationContext == null) return;
    final answerStep = steps.where((s) => s.type == 'answer').lastOrNull;
    if (answerStep == null) return;
    final toolSteps = steps
        .where((s) => s.type == 'action' && s.toolName.isNotEmpty)
        .toList();
    final toolUsed = toolSteps.isNotEmpty ? toolSteps.first.toolName : null;
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
  List<({String role, String content})> getConversationHistory() => [];

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
  void setToolPreferenceTracker(ToolPreferenceTracker? tracker) {
    _preferenceTracker = tracker;
  }
}

class _ToolCallAccumulator {
  String? id;
  String? name;
  String arguments = '';
}
