import 'package:aios/agent/tools/calculator_tool.dart';
import 'package:aios/agent/tools/device_info_tool.dart';
import 'package:aios/agent/tools/notepad_tool.dart';
import 'package:aios/agent/tools/timer_tool.dart';
import 'package:aios/data/providers/remote/llm_remote_engine.dart';
import 'package:aios/data/providers/tool_context_impl.dart';
import 'package:aios/domain/agent/agent_tool.dart';
import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/react_strategy.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:aios/domain/repositories/note_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'model_test.dart'
    show ensureProviderAvailable, providerReady, testConfig;

class _InMemoryNoteRepository implements NoteRepository {
  final Map<String, String> _notes = {};

  Map<String, String> get all => Map.unmodifiable(_notes);

  @override
  Future<void> save(String key, String value) async => _notes[key] = value;

  @override
  Future<String?> get(String key) async => _notes[key];

  @override
  Future<Map<String, String>> getAll() async => Map.from(_notes);

  @override
  Future<bool> delete(String key) async => _notes.remove(key) != null;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureProviderAvailable();
  });

  group('Tool execution via Agent (LLM + Tool E2E)', () {
    late LlmRemoteEngine engine;
    late ReactStrategy strategy;

    setUp(() {
      if (!providerReady) return;
      engine = LlmRemoteEngine(testConfig!);
    });

    ReactStrategy createStrategy({
      Map<String, AgentTool>? basicTools,
      Map<String, ExtendedTool>? extendedTools,
      ToolContext? toolContext,
    }) {
      return ReactStrategy(
        engine: engine,
        toolContext: toolContext,
        basicTools: basicTools,
        extendedTools: extendedTools,
      );
    }

    group('calculator', () {
      testWidgets('agent_selectsCalculator_forMath', (tester) async {
        if (!providerReady) return;

        strategy = createStrategy(basicTools: {'calculator': CalculatorTool()});

        final result = await strategy.execute(
          'What is 2 + 3?',
          maxIterations: 5,
          maxTokens: 64,
        );

        final usedCalculator = result.steps.any(
          (s) => s.type == 'action' && s.toolName == 'calculator',
        );
        debugPrint('Calculator used: $usedCalculator');
        debugPrint(
          'Steps: ${result.steps.map((s) => '${s.type}:${s.toolName}').join(' -> ')}',
        );

        expect(result.steps, isNotEmpty);
        expect(result.success, isTrue);
      });
    });

    group('notepad', () {
      testWidgets('agent_selectsNotepad_forWriteNote', (tester) async {
        if (!providerReady) return;

        final noteRepo = _InMemoryNoteRepository();
        strategy = createStrategy(
          basicTools: {'notepad': NotePadTool(noteRepo)},
        );

        final result = await strategy.execute(
          'Write a note: buy milk',
          maxIterations: 5,
          maxTokens: 64,
        );

        final usedNotepad = result.steps.any(
          (s) => s.type == 'action' && s.toolName == 'notepad',
        );
        debugPrint('Notepad used: $usedNotepad');
        final notes = await noteRepo.getAll();
        debugPrint('Notes stored: $notes');

        expect(result.steps, isNotEmpty);
        expect(result.success, isTrue);
      });

      testWidgets('agent_selectsNotepad_forListNotes', (tester) async {
        if (!providerReady) return;

        final noteRepo = _InMemoryNoteRepository();
        await noteRepo.save('test', 'hello world');
        strategy = createStrategy(
          basicTools: {'notepad': NotePadTool(noteRepo)},
        );

        final result = await strategy.execute(
          'Show my notes',
          maxIterations: 5,
          maxTokens: 64,
        );

        final usedNotepad = result.steps.any(
          (s) => s.type == 'action' && s.toolName == 'notepad',
        );
        debugPrint('Notepad used: $usedNotepad');

        expect(result.steps, isNotEmpty);
        expect(result.success, isTrue);
      });
    });

    group('timer', () {
      testWidgets('agent_selectsTimer_forSetTimer', (tester) async {
        if (!providerReady) return;

        final timers = <String, TimerEntry>{};
        strategy = createStrategy(basicTools: {'timer': TimerTool(timers)});

        final result = await strategy.execute(
          'Set a timer for 60 seconds',
          maxIterations: 5,
          maxTokens: 64,
        );

        final usedTimer = result.steps.any(
          (s) => s.type == 'action' && s.toolName == 'timer',
        );
        debugPrint('Timer used: $usedTimer');
        debugPrint('Timers: $timers');

        expect(result.steps, isNotEmpty);
        expect(result.success, isTrue);
      });
    });

    group('device_info (ExtendedTool)', () {
      testWidgets('agent_selectsDeviceInfo_forBatteryQuery', (tester) async {
        if (!providerReady) return;

        final toolContext = ToolContextImpl();
        strategy = createStrategy(
          toolContext: toolContext,
          extendedTools: {'device_info': DeviceInfoTool()},
        );

        final result = await strategy.execute(
          'What is my battery level?',
          maxIterations: 5,
          maxTokens: 64,
        );

        final usedDeviceInfo = result.steps.any(
          (s) => s.type == 'action' && s.toolName == 'device_info',
        );
        debugPrint('Device info used: $usedDeviceInfo');
        debugPrint(
          'Steps: ${result.steps.map((s) => '${s.type}:${s.toolName}').join(' -> ')}',
        );

        expect(result.steps, isNotEmpty);
        expect(result.success, isTrue);
      });
    });

    group('plain text answer (no tool)', () {
      testWidgets('agent_respondsDirectly_forGreeting', (tester) async {
        if (!providerReady) return;

        final noteRepo = _InMemoryNoteRepository();
        final timers = <String, TimerEntry>{};
        strategy = createStrategy(
          basicTools: {
            'calculator': CalculatorTool(),
            'notepad': NotePadTool(noteRepo),
            'timer': TimerTool(timers),
          },
        );

        final result = await strategy.execute(
          'Hello, how are you?',
          maxIterations: 3,
          maxTokens: 32,
        );

        final answerSteps = result.steps.where((s) => s.type == 'answer');
        debugPrint('Answer: ${answerSteps.map((s) => s.content).join('; ')}');

        expect(result.steps, isNotEmpty);
        expect(result.success, isTrue);
      });
    });

    group('multi-tool chaining', () {
      testWidgets('agent_usesMultipleTools_forSequentialRequest', (
        tester,
      ) async {
        if (!providerReady) return;

        final noteRepo = _InMemoryNoteRepository();
        strategy = createStrategy(
          basicTools: {
            'calculator': CalculatorTool(),
            'notepad': NotePadTool(noteRepo),
          },
        );

        final result = await strategy.execute(
          'Calculate 10 * 5 and save the result as a note',
          maxTokens: 128,
        );

        final toolActions = result.steps
            .where((s) => s.type == 'action')
            .map((s) => s.toolName)
            .toList();
        debugPrint('Tool chain: $toolActions');
        final notes = await noteRepo.getAll();
        debugPrint('Notes after: $notes');

        expect(result.steps, isNotEmpty);
        expect(result.success, isTrue);
      });
    });
  });
}
