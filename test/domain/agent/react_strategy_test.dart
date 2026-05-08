import 'package:aios/domain/agent/agent_tool.dart';
import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/react_strategy.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llamadart/llamadart.dart';

class _FakeBasicTool extends AgentTool {
  @override
  String get name => 'calculator';

  @override
  String get description => 'Evaluate math expression. Args: {expression}';

  @override
  String get parameters => '{"expression": "string"}';

  @override
  Future<String> execute(String args) async {
    return '42';
  }
}

class _FakeExtendedTool extends ExtendedTool {
  @override
  String get name => 'app_launcher';

  @override
  String get description => 'Open app. Args: {action, package_name}';

  @override
  String get parameters =>
      '{"action": "open_app|open_url|list_apps", "package_name": "string"}';

  @override
  Future<String> execute(String args, ToolContext toolContext) async {
    return 'App opened';
  }
}

void main() {
  group('ReactStrategy', () {
    test('constructor_createsInstance', () {
      final strategy = ReactStrategy(
        engine: _FakeEngine(),
        basicTools: {'calculator': _FakeBasicTool()},
        extendedTools: {'app_launcher': _FakeExtendedTool()},
      );
      expect(strategy, isNotNull);
    });

    test('getToolManifest_listsAllTools', () {
      final strategy = ReactStrategy(
        engine: _FakeEngine(),
        basicTools: {'calculator': _FakeBasicTool()},
        extendedTools: {'app_launcher': _FakeExtendedTool()},
      );
      final manifest = strategy.getToolManifest();
      expect(manifest, contains('calculator'));
      expect(manifest, contains('app_launcher'));
    });

    test('cancel_doesNotThrow', () {
      final strategy = ReactStrategy(
        engine: _FakeEngine(),
      );
      expect(() => strategy.cancel(), returnsNormally);
    });

    test('clearHistory_doesNotThrow', () {
      final strategy = ReactStrategy(
        engine: _FakeEngine(),
      );
      expect(() => strategy.clearHistory(), returnsNormally);
    });

    test('setConversationContext_doesNotThrow', () {
      final strategy = ReactStrategy(
        engine: _FakeEngine(),
      );
      expect(
        () => strategy.setConversationContext(ConversationContext()),
        returnsNormally,
      );
    });

    test('setToolPreferenceTracker_doesNotThrow', () {
      final strategy = ReactStrategy(
        engine: _FakeEngine(),
      );
      expect(
        () => strategy.setToolPreferenceTracker(ToolPreferenceTracker()),
        returnsNormally,
      );
    });

    test('resolveConfirmation_doesNotThrow', () {
      final strategy = ReactStrategy(
        engine: _FakeEngine(),
      );
      expect(
        () => strategy.resolveConfirmation(true),
        returnsNormally,
      );
    });

    test('getConversationHistory_returnsEmptyList', () {
      final strategy = ReactStrategy(
        engine: _FakeEngine(),
      );
      expect(strategy.getConversationHistory(), isEmpty);
    });
  });
}

class _FakeEngine implements LlamaEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
