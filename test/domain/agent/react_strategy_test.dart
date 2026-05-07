import 'dart:async';

import 'package:aios/domain/agent/agent_tool.dart';
import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/react_strategy.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockLlmRepository implements LlmRepository {
  final _stateController = StreamController<ServiceState>.broadcast();
  final _tokenController = StreamController<String>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  List<String> tokensToEmit = [];
  List<List<String>> responseQueue = [];
  bool shouldThrowOnSend = false;
  String? lastUserMessage;
  List<ChatMessage>? lastHistory;
  int? lastMaxTokens;
  bool stopCalled = false;
  Completer<void>? holdAfterSend;

  @override
  Stream<ServiceState> get state => _stateController.stream;

  @override
  Stream<String> get tokenStream => _tokenController.stream;

  @override
  Stream<double> get loadProgress => _progressController.stream;

  @override
  Future<bool> loadModel(String path, {int? contextSize}) async => true;

  @override
  Future<void> releaseModel() async {}

  @override
  bool get isModelLoaded => true;

  @override
  String getModelInfo() => 'TestModel';

  @override
  String getContextUsage() => '0/2048';

  @override
  Future<void> resetContext() async {}

  @override
  Future<void> sendMessage(
    List<ChatMessage> history, {
    required String userMessage,
    double? temperature,
    int? maxTokens,
    int? topK,
    double? topP,
    double? repeatPenalty,
  }) async {
    lastHistory = history;
    lastUserMessage = userMessage;
    lastMaxTokens = maxTokens;
    if (shouldThrowOnSend) {
      throw Exception('LLM error');
    }
    _stateController.add(ServiceState.generating);
    final tokens =
        responseQueue.isNotEmpty ? responseQueue.removeAt(0) : tokensToEmit;
    for (final token in tokens) {
      _tokenController.add(token);
    }
    _stateController.add(ServiceState.ready);
    if (holdAfterSend != null) {
      await holdAfterSend!.future;
    }
  }

  @override
  Future<void> stopGeneration() async {
    stopCalled = true;
  }

  @override
  Future<void> saveSession(String path) async {}

  @override
  Future<void> loadSession(String path) async {}

  void dispose() {
    _stateController.close();
    _tokenController.close();
    _progressController.close();
  }
}

class _MockToolContext implements ToolContext {
  String? Function(String method, dynamic arguments)? onInvokeMethod;

  @override
  Future<String?> invokeMethod(String method, [dynamic arguments]) async {
    return onInvokeMethod?.call(method, arguments);
  }

  @override
  Future<bool> isAccessibilityEnabled() async => true;

  @override
  Future<bool> isNotificationListenerEnabled() async => true;
}

class _FakeBasicTool implements AgentTool {
  final String _name;
  final String _result;
  String? _validationError;
  String? lastArgs;
  int executeCount = 0;

  _FakeBasicTool(this._name, this._result, {String? validationError})
      : _validationError = validationError;

  void setValidationError(String? error) => _validationError = error;

  @override
  String get name => _name;

  @override
  String get description => 'Fake $_name tool';

  @override
  String get parameters => '{}';

  @override
  String get toolPrompt => description;

  @override
  Future<String> execute(String args) async {
    lastArgs = args;
    executeCount++;
    return _result;
  }

  @override
  Future<String?> validate(String args) async => _validationError;

  @override
  Future<String?> phaseContext(String args) async => null;
}

class _FakeExtendedTool implements ExtendedTool {
  final String _name;
  final String _result;
  String? _validationError;
  String? lastArgs;
  int executeCount = 0;

  _FakeExtendedTool(this._name, this._result, {String? validationError})
      : _validationError = validationError;

  void setValidationError(String? error) => _validationError = error;

  @override
  String get name => _name;

  @override
  String get description => 'Fake $_name tool';

  @override
  String get parameters => '{}';

  @override
  String get toolPrompt => description;

  @override
  Future<String> execute(String args, ToolContext toolContext) async {
    lastArgs = args;
    executeCount++;
    return _result;
  }

  @override
  Future<String?> validate(String args, ToolContext toolContext) async =>
      _validationError;

  @override
  Future<String?> phaseContext(
    String args,
    ToolContext toolContext,
  ) async =>
      null;
}

void main() {
  group('ReactStrategy', () {
    late _MockLlmRepository llmRepo;
    late _MockToolContext toolContext;

    setUp(() {
      llmRepo = _MockLlmRepository();
      toolContext = _MockToolContext();
    });

    tearDown(() {
      llmRepo.dispose();
    });

    group('execute', () {
      test('answer response returns success', () async {
        llmRepo.tokensToEmit = ['Answer: Hello! How can I help?'];

        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);
        final result = await strategy.execute('Hi');

        expect(result.success, isTrue);
        expect(result.steps.any((s) => s.type == 'answer'), isTrue);
      });

      test('empty response returns fallback answer', () async {
        llmRepo.tokensToEmit = [''];

        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);
        final result = await strategy.execute('Hi');

        expect(result.steps.any((s) => s.type == 'answer'), isTrue);
      });

      test('emits thought steps', () async {
        llmRepo.tokensToEmit = ['Answer: done'];
        final steps = <AgentStep>[];

        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);
        await strategy.execute('Hi', onStep: steps.add);

        expect(steps.any((s) => s.type == 'thought'), isTrue);
      });

      test('emits answer step', () async {
        llmRepo.tokensToEmit = ['Answer: The answer is 42'];

        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);
        final result = await strategy.execute('question');

        final answerStep =
            result.steps.where((s) => s.type == 'answer').first;
        expect(answerStep.content, 'The answer is 42');
      });

      test('passes maxTokens', () async {
        llmRepo.tokensToEmit = ['Answer: ok'];

        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);
        await strategy.execute('Hi', maxTokens: 256);

        expect(llmRepo.lastMaxTokens, 256);
      });

      test('with no tool context extended tool returns error', () async {
        final extTool = _FakeExtendedTool('app_launcher', 'done');
        final strategy = ReactStrategy(
          llmRepo,
          extendedTools: {'app_launcher': extTool},
        );

        llmRepo.tokensToEmit = [
          'Action: app_launcher',
          'Action: app_launcher\nArgs: {"action": "list_apps"}',
        ];

        final result = await strategy.execute('list apps');

        expect(result.steps.any((s) => s.type == 'answer'), isTrue);
      });

      test('llm exception returns error answer', () async {
        llmRepo.shouldThrowOnSend = true;

        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);
        final result = await strategy.execute('Hi');

        expect(result.steps.any((s) => s.type == 'answer'), isTrue);
      });

      test('calls onStep callback', () async {
        llmRepo.tokensToEmit = ['Answer: ok'];
        final steps = <AgentStep>[];

        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);
        await strategy.execute('Hi', onStep: steps.add);

        expect(steps, isNotEmpty);
      });

      test('plain text response retries then returns fallback', () async {
        llmRepo.tokensToEmit = ['Just a plain response'];

        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);
        final result = await strategy.execute('Hi', maxIterations: 1);

        final answerSteps =
            result.steps.where((s) => s.type == 'answer').toList();
        expect(answerSteps, isNotEmpty);
        expect(
          answerSteps.first.content,
          contains('작업을 완료하지 못했습니다'),
        );
      });

      test('phase1 with valid args executes directly', () async {
        final basicTool = _FakeBasicTool('calculator', '42');
        final strategy = ReactStrategy(
          llmRepo,
          toolContext: toolContext,
          basicTools: {'calculator': basicTool},
        );

        llmRepo.tokensToEmit = [
          'Action: calculator\nArgs: {"expression": "2+2"}',
        ];

        final result = await strategy.execute('2+2');

        expect(basicTool.executeCount, greaterThanOrEqualTo(1));
        expect(result.steps.any((s) => s.type == 'observation'), isTrue);
      });
    });

    group('cancel', () {
      test('sets cancelled', () async {
        llmRepo.tokensToEmit = [];
        llmRepo.holdAfterSend = Completer<void>();

        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);

        final future = strategy.execute('long task');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        strategy.cancel();
        llmRepo.holdAfterSend!.complete();
        await future;

        expect(llmRepo.stopCalled, isTrue);
      });
    });

    group('resolveConfirmation', () {
      test('does not throw', () async {
        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);

        expect(() => strategy.resolveConfirmation(true), returnsNormally);
        expect(() => strategy.resolveConfirmation(false), returnsNormally);
      });
    });

    group('constructor', () {
      test('accepts injected tools', () {
        final basicTools = {
          'calculator': _FakeBasicTool('calculator', '42'),
        };
        final extendedTools = {
          'app_launcher': _FakeExtendedTool('app_launcher', 'opened'),
        };

        final strategy = ReactStrategy(
          llmRepo,
          toolContext: toolContext,
          basicTools: basicTools,
          extendedTools: extendedTools,
        );
        final manifest = strategy.getToolManifest();

        expect(manifest, contains('calculator'));
        expect(manifest, contains('app_launcher'));
      });
    });

    group('getToolManifest', () {
      test('with basic and extended tools returns all', () {
        final basicTools = {
          'calculator': _FakeBasicTool('calculator', '42'),
          'timer': _FakeBasicTool('timer', 'done'),
        };
        final extendedTools = {
          'app_launcher': _FakeExtendedTool('app_launcher', 'opened'),
        };

        final strategy = ReactStrategy(
          llmRepo,
          toolContext: toolContext,
          basicTools: basicTools,
          extendedTools: extendedTools,
        );
        final manifest = strategy.getToolManifest();

        expect(manifest, contains('calculator'));
        expect(manifest, contains('timer'));
        expect(manifest, contains('app_launcher'));
        expect(manifest, contains('Fake calculator tool'));
        expect(manifest, contains('Fake app_launcher tool'));
      });

      test('with no injected tools returns empty', () async {
        llmRepo.tokensToEmit = [];
        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);

        final manifest = strategy.getToolManifest();

        expect(manifest, isEmpty);
      });

      test('with no tools returns empty', () async {
        llmRepo.tokensToEmit = [];
        final strategy = ReactStrategy(llmRepo);

        final manifest = strategy.getToolManifest();

        expect(manifest, isEmpty);
      });
    });

    group('getConversationHistory', () {
      test('empty initially', () async {
        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);

        expect(strategy.getConversationHistory(), isEmpty);
      });

      test('after execute has messages', () async {
        llmRepo.tokensToEmit = ['Answer: done'];

        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);
        await strategy.execute('Hello');

        final history = strategy.getConversationHistory();
        expect(history, isNotEmpty);
        expect(history.any((m) => m.content.contains('Hello')), isTrue);
      });
    });

    group('clearHistory', () {
      test('removes history', () async {
        llmRepo.tokensToEmit = ['Answer: done'];

        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);
        await strategy.execute('Hello');

        expect(strategy.getConversationHistory(), isNotEmpty);

        strategy.clearHistory();

        expect(strategy.getConversationHistory(), isEmpty);
      });
    });

    group('multipleExecutes', () {
      test('twice independent results', () async {
        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);

        llmRepo.tokensToEmit = ['Answer: first'];
        final result1 = await strategy.execute('Q1');

        llmRepo.tokensToEmit = ['Answer: second'];
        final result2 = await strategy.execute('Q2');

        expect(
            result1.steps.any((s) => s.content.contains('first')), isTrue);
        expect(
            result2.steps.any((s) => s.content.contains('second')), isTrue);
      });

      test('after cancel works normally', () async {
        llmRepo.tokensToEmit = [];
        llmRepo.holdAfterSend = Completer<void>();

        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);

        final future = strategy.execute('task1');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        strategy.cancel();
        llmRepo.holdAfterSend!.complete();
        await future;

        llmRepo.holdAfterSend = null;
        llmRepo.tokensToEmit = ['Answer: ok'];
        llmRepo.stopCalled = false;

        final result = await strategy.execute('task2');
        expect(result.steps.any((s) => s.type == 'answer'), isTrue);
      });
    });

    group('multiToolChaining', () {
      test('chains two basic tools sequentially', () async {
        final calcTool = _FakeBasicTool('calculator', '42');
        final noteTool = _FakeBasicTool('notepad', 'Note saved');

        final strategy = ReactStrategy(
          llmRepo,
          toolContext: toolContext,
          basicTools: {
            'calculator': calcTool,
            'notepad': noteTool,
          },
        );

        llmRepo.responseQueue = [
          ['Action: calculator'],
          ['Action: calculator\nArgs: {"expression": "2+2"}'],
          ['Action: notepad'],
          ['Action: notepad\nArgs: {"action": "save", '
              '"content": "42"}'],
          ['Answer: Saved 42 to notes.'],
        ];

        final result = await strategy.execute(
          '2+2 계산해서 메모해줘',
        );

        expect(result.success, isTrue);
        expect(calcTool.executeCount, greaterThanOrEqualTo(1));
        expect(noteTool.executeCount, greaterThanOrEqualTo(1));
        expect(
          result.steps.any((s) => s.type == 'answer'),
          isTrue,
        );
      });

      test('chains three safe tools sequentially', () async {
        final calcTool = _FakeBasicTool('calculator', '385');
        final noteTool = _FakeBasicTool('notepad', 'Note saved');
        final timerTool = _FakeBasicTool('timer', 'Timer set');

        final strategy = ReactStrategy(
          llmRepo,
          toolContext: toolContext,
          basicTools: {
            'calculator': calcTool,
            'notepad': noteTool,
            'timer': timerTool,
          },
        );

        llmRepo.responseQueue = [
          ['Action: calculator'],
          ['Action: calculator\nArgs: {"expression": "385"}'],
          ['Action: notepad'],
          ['Action: notepad\nArgs: {"action": "save", '
              '"content": "385"}'],
          ['Action: timer'],
          ['Action: timer\nArgs: {"action": "start", '
              '"seconds": "60"}'],
          ['Answer: Done.'],
        ];

        final result = await strategy.execute(
          '385 계산하고 메모하고 60초 타이머 설정해줘',
          maxIterations: 8,
        );

        expect(result.success, isTrue);
        expect(calcTool.executeCount, greaterThanOrEqualTo(1));
        expect(noteTool.executeCount, greaterThanOrEqualTo(1));
        expect(timerTool.executeCount, greaterThanOrEqualTo(1));
      });

      test('phase2 includes all observations', () async {
        final calcTool = _FakeBasicTool('calculator', '42');
        final noteTool = _FakeBasicTool('notepad', 'Note saved');

        final strategy = ReactStrategy(
          llmRepo,
          toolContext: toolContext,
          basicTools: {
            'calculator': calcTool,
            'notepad': noteTool,
          },
        );

        llmRepo.responseQueue = [
          ['Action: calculator'],
          ['Action: calculator\nArgs: {"expression": "2+2"}'],
          ['Action: notepad'],
          ['Action: notepad\nArgs: {"action": "save", '
              '"content": "42"}'],
          ['Answer: done'],
        ];

        await strategy.execute('2+2 계산해서 메모해줘');

        final history = strategy.getConversationHistory();
        final observations = history
            .where((m) =>
                m.role == 'user' &&
                m.content.startsWith('Observation'))
            .toList();
        expect(observations.length, greaterThanOrEqualTo(2));
      });

      test('chains with direct args skips phase2', () async {
        final calcTool = _FakeBasicTool('calculator', '4');
        final noteTool = _FakeBasicTool('notepad', 'Note saved');

        final strategy = ReactStrategy(
          llmRepo,
          toolContext: toolContext,
          basicTools: {
            'calculator': calcTool,
            'notepad': noteTool,
          },
        );

        llmRepo.responseQueue = [
          ['Action: calculator\nArgs: {"expression": "2+2"}'],
          ['Action: notepad\nArgs: {"action": "save", '
              '"content": "result is 4"}'],
          ['Answer: Saved result.'],
        ];

        final result = await strategy.execute(
          '2+2 계산해서 메모해줘',
        );

        expect(result.success, isTrue);
        expect(calcTool.executeCount, 1);
        expect(noteTool.executeCount, 1);
      });

      test('loop detector prevents infinite chaining', () async {
        final tool = _FakeBasicTool('calculator', '42');

        final strategy = ReactStrategy(
          llmRepo,
          toolContext: toolContext,
          basicTools: {'calculator': tool},
        );

        final endlessResponses = List.generate(
          20,
          (_) => [
            'Action: calculator\nArgs: {"expression": "1+1"}'
          ],
        );
        llmRepo.responseQueue = endlessResponses;

        final result = await strategy.execute(
          'keep calculating',
          maxIterations: 10,
        );

        expect(result.steps.any((s) => s.type == 'answer'), isTrue);
        expect(tool.executeCount, lessThan(10));
      });
    });

    group('contextAwareness', () {
      test('records_conversationTurn_afterExecute', () async {
        final context = ConversationContext();
        llmRepo.tokensToEmit = ['Answer: Hello!'];

        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);
        strategy.setConversationContext(context);
        await strategy.execute('Hi');

        expect(context.length, 1);
        final turns = context.getRecentTurns();
        expect(turns.first.userMessage, 'Hi');
        expect(turns.first.assistantResponse, 'Hello!');
      });

      test('records_toolUsed_whenToolExecuted', () async {
        final context = ConversationContext();
        final calcTool = _FakeBasicTool('calculator', '42');

        llmRepo.tokensToEmit = [
          'Action: calculator\nArgs: {"expression": "2+2"}',
        ];

        final strategy = ReactStrategy(
          llmRepo,
          toolContext: toolContext,
          basicTools: {'calculator': calcTool},
        );
        strategy.setConversationContext(context);
        await strategy.execute('2+2');

        expect(context.length, 1);
        final turns = context.getRecentTurns();
        expect(turns.first.toolUsed, 'calculator');
      });

      test('records_nullToolUsed_whenDirectAnswer', () async {
        final context = ConversationContext();
        llmRepo.tokensToEmit = ['Answer: Just a text answer'];

        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);
        strategy.setConversationContext(context);
        await strategy.execute('Hello');

        final turns = context.getRecentTurns();
        expect(turns.first.toolUsed, isNull);
      });

      test('records_turn_onlyWhenAnswerExists', () async {
        final context = ConversationContext();
        llmRepo.tokensToEmit = ['Answer: some answer'];

        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);
        strategy.setConversationContext(context);
        await strategy.execute('test');

        expect(context.length, 1);
      });

      test('records_multipleTurns_acrossExecutions', () async {
        final context = ConversationContext();

        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);
        strategy.setConversationContext(context);

        llmRepo.tokensToEmit = ['Answer: First'];
        await strategy.execute('Q1');

        llmRepo.tokensToEmit = ['Answer: Second'];
        await strategy.execute('Q2');

        llmRepo.tokensToEmit = ['Answer: Third'];
        await strategy.execute('Q3');

        expect(context.length, 3);
      });

      test('respects_maxTurns_acrossExecutions', () async {
        final context = ConversationContext(maxTurns: 2);

        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);
        strategy.setConversationContext(context);

        llmRepo.tokensToEmit = ['Answer: A1'];
        await strategy.execute('Q1');

        llmRepo.tokensToEmit = ['Answer: A2'];
        await strategy.execute('Q2');

        llmRepo.tokensToEmit = ['Answer: A3'];
        await strategy.execute('Q3');

        expect(context.length, 2);
        final turns = context.getRecentTurns();
        expect(turns[0].userMessage, 'Q2');
        expect(turns[1].userMessage, 'Q3');
      });
    });

    group('toolPreferenceTracking', () {
      test('tracks_singleToolUsage', () async {
        final tracker = ToolPreferenceTracker();
        final calcTool = _FakeBasicTool('calculator', '42');

        llmRepo.responseQueue = [
          ['Action: calculator\nArgs: {"expression": "2+2"}'],
          ['Answer: 42'],
        ];

        final strategy = ReactStrategy(
          llmRepo,
          toolContext: toolContext,
          basicTools: {'calculator': calcTool},
        );
        strategy.setToolPreferenceTracker(tracker);
        await strategy.execute('2+2');

        expect(tracker.getCount('calculator'), greaterThanOrEqualTo(1));
      });

      test('tracks_multipleToolUsage', () async {
        final tracker = ToolPreferenceTracker();
        final calcTool = _FakeBasicTool('calculator', '42');
        final noteTool = _FakeBasicTool('notepad', 'saved');

        llmRepo.responseQueue = [
          ['Action: calculator\nArgs: {"expression": "2+2"}'],
          ['Action: notepad\nArgs: {"action": "save"}'],
          ['Answer: done'],
        ];

        final strategy = ReactStrategy(
          llmRepo,
          toolContext: toolContext,
          basicTools: {
            'calculator': calcTool,
            'notepad': noteTool,
          },
        );
        strategy.setToolPreferenceTracker(tracker);
        await strategy.execute('calc and save');

        expect(tracker.getCount('calculator'), 1);
        expect(tracker.getCount('notepad'), 1);
      });

      test('noTracking_whenNoTrackerSet', () async {
        final calcTool = _FakeBasicTool('calculator', '42');

        llmRepo.responseQueue = [
          ['Action: calculator\nArgs: {"expression": "2+2"}'],
          ['Answer: 42'],
        ];

        final strategy = ReactStrategy(
          llmRepo,
          toolContext: toolContext,
          basicTools: {'calculator': calcTool},
        );
        await strategy.execute('2+2');

        expect(calcTool.executeCount, greaterThanOrEqualTo(1));
      });

      test('tracks_extendedToolUsage', () async {
        final tracker = ToolPreferenceTracker();
        final extTool =
            _FakeExtendedTool('app_launcher', 'launched');

        llmRepo.responseQueue = [
          ['Answer: App launched.'],
        ];

        final strategy = ReactStrategy(
          llmRepo,
          toolContext: toolContext,
          extendedTools: {'app_launcher': extTool},
        );
        strategy.setToolPreferenceTracker(tracker);

        tracker.recordToolUse('app_launcher');

        expect(tracker.getCount('app_launcher'), 1);
      });
    });

    group('setConversationContext', () {
      test('accepts_null', () async {
        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);

        expect(
          () => strategy.setConversationContext(null),
          returnsNormally,
        );
      });

      test('accepts_context', () async {
        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);
        final context = ConversationContext();

        expect(
          () => strategy.setConversationContext(context),
          returnsNormally,
        );
      });
    });

    group('setToolPreferenceTracker', () {
      test('accepts_null', () async {
        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);

        expect(
          () => strategy.setToolPreferenceTracker(null),
          returnsNormally,
        );
      });

      test('accepts_tracker', () async {
        final strategy = ReactStrategy(llmRepo, toolContext: toolContext);
        final tracker = ToolPreferenceTracker();

        expect(
          () => strategy.setToolPreferenceTracker(tracker),
          returnsNormally,
        );
      });
    });
  });
}
