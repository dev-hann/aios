import 'dart:async';

import 'package:aios/domain/agent/agent_tool.dart';
import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/react_strategy.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:aios/domain/agent/llm_engine.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBasicTool extends AgentTool {
  final String _name;
  final String _desc;
  final String _params;
  final Future<String> Function(String) _handler;

  _FakeBasicTool(this._name, this._desc, this._params, this._handler);

  @override
  String get name => _name;

  @override
  String get description => _desc;

  @override
  String get parameters => _params;

  @override
  Future<String> execute(String args) => _handler(args);
}

class _FakeExtendedTool extends ExtendedTool {
  final String _name;
  final String _desc;
  final String _params;
  final Future<String> Function(String, ToolContext) _handler;

  _FakeExtendedTool(this._name, this._desc, this._params, this._handler);

  @override
  String get name => _name;

  @override
  String get description => _desc;

  @override
  String get parameters => _params;

  @override
  Future<String> execute(String args, ToolContext toolContext) =>
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

void main() {
  group('constructor', () {
    test('constructor_withTools_createsInstance', () {
      final strategy = ReactStrategy(
        engine: _FakeEngine(),
        basicTools: {
          'calculator': _FakeBasicTool('calculator', 'Math', '{}', (_) async => '0'),
        },
        extendedTools: {
          'app_launcher': _FakeExtendedTool('app_launcher', 'Open', '{}', (_, __) async => 'ok'),
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
          'calculator': _FakeBasicTool('calculator', 'Calculate', '{}', (_) async => '0'),
        },
        extendedTools: {
          'screen_action': _FakeExtendedTool('screen_action', 'Screen', '{}', (_, __) async => 'ok'),
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
          'calculator': _FakeBasicTool('calculator', 'Calc', '{}', (_) async => '0'),
          'notepad': _FakeBasicTool('notepad', 'Note', '{}', (_) async => 'ok'),
        },
        extendedTools: {
          'app_launcher': _FakeExtendedTool('app_launcher', 'Launch', '{}', (_, __) async => 'ok'),
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
      expect(() => strategy.cancel(), returnsNormally);
    });

    test('cancel_multipleTimes_doesNotThrow', () {
      final strategy = ReactStrategy(engine: _FakeEngine());
      strategy.cancel();
      strategy.cancel();
    });
  });

  group('resolveConfirmation', () {
    test('resolveConfirmation_true_doesNotThrow', () {
      final strategy = ReactStrategy(engine: _FakeEngine());
      expect(() => strategy.resolveConfirmation(true), returnsNormally);
    });

    test('resolveConfirmation_false_doesNotThrow', () {
      final strategy = ReactStrategy(engine: _FakeEngine());
      expect(() => strategy.resolveConfirmation(false), returnsNormally);
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
      expect(
        () => strategy.setConversationContext(null),
        returnsNormally,
      );
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
      expect(
        () => strategy.setToolPreferenceTracker(null),
        returnsNormally,
      );
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
      expect(() => strategy.clearHistory(), returnsNormally);
    });
  });

  group('system prompt context injection', () {
    test('systemPrompt_withoutContext_containsBaseOnly', () {
      final engine = _PromptCapturingEngine();
      final strategy = ReactStrategy(engine: engine);
      strategy.setConversationContext(null);
      strategy.setToolPreferenceTracker(null);

      strategy.execute('test', onStep: (_) {});

      expect(engine.capturedSystemPrompt, contains('AIOS'));
      expect(engine.capturedSystemPrompt, isNot(contains('CONVERSATION HISTORY')));
      expect(engine.capturedSystemPrompt, isNot(contains('FREQUENTLY USED TOOLS')));
    });

    test('systemPrompt_withConversationContext_containsHistory', () async {
      final engine = _PromptCapturingEngine();
      final context = ConversationContext();
      context.addTurn('open youtube', 'YouTube 실행 완료', toolUsed: 'app_launcher');
      final strategy = ReactStrategy(engine: engine);
      strategy.setConversationContext(context);
      strategy.setToolPreferenceTracker(null);

      strategy.execute('test', onStep: (_) {});

      expect(engine.capturedSystemPrompt, contains('CONVERSATION HISTORY'));
      expect(engine.capturedSystemPrompt, contains('open youtube'));
    });

    test('systemPrompt_withPreferenceTracker_containsFrequentTools', () async {
      final engine = _PromptCapturingEngine();
      final tracker = ToolPreferenceTracker();
      tracker.recordToolUse('calculator');
      tracker.recordToolUse('calculator');
      tracker.recordToolUse('calculator');
      final strategy = ReactStrategy(engine: engine);
      strategy.setConversationContext(null);
      strategy.setToolPreferenceTracker(tracker);

      strategy.execute('test', onStep: (_) {});

      expect(engine.capturedSystemPrompt, contains('FREQUENTLY USED TOOLS'));
      expect(engine.capturedSystemPrompt, contains('calculator'));
    });

    test('systemPrompt_withBothContexts_containsBoth', () async {
      final engine = _PromptCapturingEngine();
      final context = ConversationContext();
      context.addTurn('hello', 'hi there', toolUsed: null);
      final tracker = ToolPreferenceTracker();
      tracker.recordToolUse('app_launcher');
      tracker.recordToolUse('app_launcher');
      final strategy = ReactStrategy(engine: engine);
      strategy.setConversationContext(context);
      strategy.setToolPreferenceTracker(tracker);

      strategy.execute('test', onStep: (_) {});

      expect(engine.capturedSystemPrompt, contains('CONVERSATION HISTORY'));
      expect(engine.capturedSystemPrompt, contains('FREQUENTLY USED TOOLS'));
    });
  });
}
