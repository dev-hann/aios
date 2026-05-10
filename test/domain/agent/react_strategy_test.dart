import 'dart:async';

import 'package:aios/agent/tools/screen_action_tool.dart';
import 'package:aios/domain/agent/agent_tool.dart';
import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/llm_engine.dart';
import 'package:aios/domain/agent/react_strategy.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/agent/tool_result.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBasicTool extends AgentTool {
  _FakeBasicTool(this._name, this._desc, this._params, this._handler);
  final String _name;
  final String _desc;
  final String _params;
  final Future<ToolResult> Function(String) _handler;

  @override
  String get name => _name;

  @override
  String get description => _desc;

  @override
  String get parameters => _params;

  @override
  Future<ToolResult> execute(String args) => _handler(args);
}

class _FakeExtendedTool extends ExtendedTool {
  _FakeExtendedTool(this._name, this._desc, this._params, this._handler);
  final String _name;
  final String _desc;
  final String _params;
  final Future<ToolResult> Function(String, ToolContext) _handler;

  @override
  String get name => _name;

  @override
  String get description => _desc;

  @override
  String get parameters => _params;

  @override
  Future<ToolResult> execute(String args, ToolContext toolContext) =>
      _handler(args, toolContext);
}

class _FakeSession implements LlmChatSession {
  @override
  Stream<LlmResponseChunk> chat(
    List<LlmContentPart> messages, {
    required LlmGenerationConfig config,
    required List<LlmToolSchema> tools,
  }) {
    return Stream.value(const LlmResponseChunk(text: 'test response'));
  }

  @override
  void addToolResult(String toolName, String result) {}
}

class _FakeEngine implements LlmEngine {
  @override
  LlmChatSession createSession(String systemPrompt) => _FakeSession();

  @override
  void cancelGeneration() {}

  @override
  Future<void> warmup() async {}
}

class _PromptCapturingEngine implements LlmEngine {
  String? capturedSystemPrompt;

  @override
  LlmChatSession createSession(String systemPrompt) {
    capturedSystemPrompt = systemPrompt;
    return _FakeSession();
  }

  @override
  void cancelGeneration() {}

  @override
  Future<void> warmup() async {}
}

class _ToolCapturingSession implements LlmChatSession {
  _ToolCapturingSession();
  final List<LlmToolSchema> capturedTools = [];

  @override
  Stream<LlmResponseChunk> chat(
    List<LlmContentPart> messages, {
    required LlmGenerationConfig config,
    required List<LlmToolSchema> tools,
  }) {
    capturedTools.addAll(tools);
    return Stream.value(const LlmResponseChunk(text: 'done'));
  }

  @override
  void addToolResult(String toolName, String result) {}
}

class _ToolCapturingEngine implements LlmEngine {
  _ToolCapturingSession? capturedSession;

  @override
  LlmChatSession createSession(String systemPrompt) {
    capturedSession = _ToolCapturingSession();
    return capturedSession!;
  }

  @override
  void cancelGeneration() {}

  @override
  Future<void> warmup() async {}
}

void main() {
  group('constructor', () {
    test('constructor_withTools_createsInstance', () {
      final strategy = ReactStrategy(
        engine: _FakeEngine(),
        basicTools: {
          'calculator': _FakeBasicTool(
            'calculator',
            'Math',
            '{}',
            (_) async => const ToolResult.ok('0'),
          ),
        },
        extendedTools: {
          'app_launcher': _FakeExtendedTool(
            'app_launcher',
            'Open',
            '{}',
            (_, __) async => const ToolResult.ok('ok'),
          ),
        },
      );
      expect(strategy, isNotNull);
    });

    test('constructor_emptyTools_createsInstance', () {
      final strategy = ReactStrategy(engine: _FakeEngine());
      expect(strategy, isNotNull);
    });
  });

  group('getToolManifest', () {
    test('getToolManifest_basicAndExtended_listsAll', () {
      final strategy = ReactStrategy(
        engine: _FakeEngine(),
        basicTools: {
          'calculator': _FakeBasicTool(
            'calculator',
            'Calculate',
            '{}',
            (_) async => const ToolResult.ok('0'),
          ),
        },
        extendedTools: {
          'screen_action': _FakeExtendedTool(
            'screen_action',
            'Screen',
            '{}',
            (_, __) async => const ToolResult.ok('ok'),
          ),
        },
      );
      final manifest = strategy.getToolManifest();
      expect(manifest, contains('calculator'));
      expect(manifest, contains('screen_action'));
      expect(manifest, contains('Calculate'));
      expect(manifest, contains('Screen'));
    });

    test('getToolManifest_emptyTools_returnsEmpty', () {
      final strategy = ReactStrategy(engine: _FakeEngine());
      expect(strategy.getToolManifest(), isEmpty);
    });

    test('getToolManifest_multipleTools_allListed', () {
      final strategy = ReactStrategy(
        engine: _FakeEngine(),
        basicTools: {
          'calculator': _FakeBasicTool(
            'calculator',
            'Calc',
            '{}',
            (_) async => const ToolResult.ok('0'),
          ),
          'notepad': _FakeBasicTool(
            'notepad',
            'Note',
            '{}',
            (_) async => const ToolResult.ok('ok'),
          ),
        },
        extendedTools: {
          'app_launcher': _FakeExtendedTool(
            'app_launcher',
            'Launch',
            '{}',
            (_, __) async => const ToolResult.ok('ok'),
          ),
        },
      );
      final manifest = strategy.getToolManifest();
      expect(manifest, contains('calculator'));
      expect(manifest, contains('notepad'));
      expect(manifest, contains('app_launcher'));
    });
  });

  group('cancel', () {
    test('cancel_doesNotThrow', () {
      final strategy = ReactStrategy(engine: _FakeEngine());
      expect(strategy.cancel, returnsNormally);
    });

    test('cancel_multipleTimes_doesNotThrow', () {
      ReactStrategy(engine: _FakeEngine())
        ..cancel()
        ..cancel();
    });
  });

  group('resolveConfirmation', () {
    test('resolveConfirmation_true_doesNotThrow', () {
      final strategy = ReactStrategy(engine: _FakeEngine());
      expect(
        () => strategy.resolveConfirmation(approved: true),
        returnsNormally,
      );
    });

    test('resolveConfirmation_false_doesNotThrow', () {
      final strategy = ReactStrategy(engine: _FakeEngine());
      expect(
        () => strategy.resolveConfirmation(approved: false),
        returnsNormally,
      );
    });
  });

  group('setConversationContext', () {
    test('setConversationContext_withContext_doesNotThrow', () {
      final strategy = ReactStrategy(engine: _FakeEngine());
      expect(
        () => strategy.setConversationContext(ConversationContext()),
        returnsNormally,
      );
    });

    test('setConversationContext_null_doesNotThrow', () {
      final strategy = ReactStrategy(engine: _FakeEngine());
      expect(() => strategy.setConversationContext(null), returnsNormally);
    });
  });

  group('setToolPreferenceTracker', () {
    test('setToolPreferenceTracker_withTracker_doesNotThrow', () {
      final strategy = ReactStrategy(engine: _FakeEngine());
      expect(
        () => strategy.setToolPreferenceTracker(ToolPreferenceTracker()),
        returnsNormally,
      );
    });

    test('setToolPreferenceTracker_null_doesNotThrow', () {
      final strategy = ReactStrategy(engine: _FakeEngine());
      expect(() => strategy.setToolPreferenceTracker(null), returnsNormally);
    });
  });

  group('getConversationHistory', () {
    test('getConversationHistory_returnsEmptyList', () {
      final strategy = ReactStrategy(engine: _FakeEngine());
      expect(strategy.getConversationHistory(), isEmpty);
    });
  });

  group('clearHistory', () {
    test('clearHistory_doesNotThrow', () {
      final strategy = ReactStrategy(engine: _FakeEngine());
      expect(strategy.clearHistory, returnsNormally);
    });
  });

  group('system prompt context injection', () {
    test('systemPrompt_withoutContext_containsBaseOnly', () {
      final engine = _PromptCapturingEngine();
      ReactStrategy(engine: engine)
        ..setConversationContext(null)
        ..setToolPreferenceTracker(null)
        ..execute('test', onStep: (_) {});

      expect(engine.capturedSystemPrompt, contains('AIOS'));
      expect(
        engine.capturedSystemPrompt,
        isNot(contains('CONVERSATION HISTORY')),
      );
      expect(
        engine.capturedSystemPrompt,
        isNot(contains('FREQUENTLY USED TOOLS')),
      );
    });

    test('systemPrompt_withConversationContext_containsHistory', () async {
      final engine = _PromptCapturingEngine();
      final context = ConversationContext()
        ..addTurn('open youtube', 'YouTube 실행 완료', toolUsed: 'app_launcher');
      final strategy = ReactStrategy(engine: engine)
        ..setConversationContext(context)
        ..setToolPreferenceTracker(null);

      unawaited(strategy.execute('test', onStep: (_) {}));

      expect(engine.capturedSystemPrompt, contains('CONVERSATION HISTORY'));
      expect(engine.capturedSystemPrompt, contains('open youtube'));
    });

    test('systemPrompt_withPreferenceTracker_containsFrequentTools', () async {
      final engine = _PromptCapturingEngine();
      final tracker = ToolPreferenceTracker()
        ..recordToolUse('calculator')
        ..recordToolUse('calculator')
        ..recordToolUse('calculator');
      final strategy = ReactStrategy(engine: engine)
        ..setConversationContext(null)
        ..setToolPreferenceTracker(tracker);

      unawaited(strategy.execute('test', onStep: (_) {}));

      expect(engine.capturedSystemPrompt, contains('FREQUENTLY USED TOOLS'));
      expect(engine.capturedSystemPrompt, contains('calculator'));
    });

    test('systemPrompt_withBothContexts_containsBoth', () async {
      final engine = _PromptCapturingEngine();
      final context = ConversationContext()..addTurn('hello', 'hi there');
      final tracker = ToolPreferenceTracker()
        ..recordToolUse('app_launcher')
        ..recordToolUse('app_launcher');
      final strategy = ReactStrategy(engine: engine)
        ..setConversationContext(context)
        ..setToolPreferenceTracker(tracker);

      unawaited(strategy.execute('test', onStep: (_) {}));

      expect(engine.capturedSystemPrompt, contains('CONVERSATION HISTORY'));
      expect(engine.capturedSystemPrompt, contains('FREQUENTLY USED TOOLS'));
    });
  });

  group('system prompt multi-step workflow rules', () {
    test('systemPrompt_containsScreenActionCriticalRules', () {
      final engine = _PromptCapturingEngine();
      ReactStrategy(engine: engine).execute('test', onStep: (_) {});

      final prompt = engine.capturedSystemPrompt!;
      expect(prompt, contains('screen_action'));
      expect(prompt, contains('ONE action'));
      expect(prompt, contains('SEPARATE'));
      expect(prompt, contains('global_action'));
      expect(prompt, contains('enter'));
    });

    test('systemPrompt_containsSearchWorkflowSteps', () {
      final engine = _PromptCapturingEngine();
      ReactStrategy(engine: engine).execute('test', onStep: (_) {});

      final prompt = engine.capturedSystemPrompt!;
      expect(prompt, contains('tap'));
      expect(prompt, contains('type'));
      expect(prompt, contains('submit'));
    });

    test('systemPrompt_warnsAgainstMixingParams', () {
      final engine = _PromptCapturingEngine();
      ReactStrategy(engine: engine).execute('test', onStep: (_) {});

      final prompt = engine.capturedSystemPrompt!;
      expect(prompt, contains('content'));
      expect(prompt, contains('global_action'));
      expect(prompt, contains('Do NOT mix'));
    });
  });

  group('tool schema uses toolPrompt', () {
    test('extendedToolSchema_usesToolPrompt_notDescription', () {
      final engine = _ToolCapturingEngine();
      final tool = ScreenActionTool();
      ReactStrategy(
        engine: engine,
        extendedTools: {'screen_action': tool},
      ).execute('test', onStep: (_) {});

      final schemas = engine.capturedSession!.capturedTools;
      final screenSchema = schemas.firstWhere((s) => s.name == 'screen_action');

      expect(screenSchema.description, contains('Control the device screen'));
      expect(screenSchema.description, contains('submit=true'));
      expect(screenSchema.description, contains('global_action "enter"'));
      expect(screenSchema.description, isNot(contains('Screen actions: tap')));
    });

    test('extendedToolSchema_containsSearchWorkflowInDescription', () {
      final engine = _ToolCapturingEngine();
      final tool = ScreenActionTool();
      ReactStrategy(
        engine: engine,
        extendedTools: {'screen_action': tool},
      ).execute('test', onStep: (_) {});

      final schemas = engine.capturedSession!.capturedTools;
      final screenSchema = schemas.firstWhere((s) => s.name == 'screen_action');

      expect(screenSchema.description, contains('tap search field'));
      expect(screenSchema.description, contains('submit=true'));
      expect(screenSchema.description, contains('global_action "enter"'));
    });

    test('basicToolSchema_usesToolPrompt_notDescription', () {
      final engine = _ToolCapturingEngine();
      final tool = _FakeBasicTool(
        'calculator',
        'Math tool',
        '{"expression": "string"}',
        (_) async => const ToolResult.ok('0'),
      );
      ReactStrategy(
        engine: engine,
        basicTools: {'calculator': tool},
      ).execute('test', onStep: (_) {});

      final schemas = engine.capturedSession!.capturedTools;
      final calcSchema = schemas.firstWhere((s) => s.name == 'calculator');

      expect(calcSchema.description, contains('Math tool'));
      expect(calcSchema.description, contains('Parameters:'));
    });
  });

  group('toolPrompt consistency', () {
    test('basicAndExtendedTool_toolPrompt_formatMatches', () {
      final basic = _FakeBasicTool(
        'test',
        'A tool',
        '{"x": "int"}',
        (_) async => const ToolResult.ok('0'),
      );
      final extended = _FakeExtendedTool(
        'test2',
        'A tool',
        '{"x": "int"}',
        (_, __) async => const ToolResult.ok('0'),
      );
      expect(basic.toolPrompt, 'A tool\nParameters: {"x": "int"}');
      expect(extended.toolPrompt, 'A tool\nParameters: {"x": "int"}');
      expect(basic.toolPrompt, equals(extended.toolPrompt));
    });
  });
}
