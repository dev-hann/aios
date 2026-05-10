import 'package:aios/domain/agent/llm_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ToolCallAccumulator', () {
    test('initialState_allFieldsDefault', () {
      final acc = ToolCallAccumulator();
      expect(acc.id, isNull);
      expect(acc.name, isNull);
      expect(acc.arguments, '');
    });

    test('setId_updatesId', () {
      final acc = ToolCallAccumulator()..id = 'call_123';
      expect(acc.id, 'call_123');
    });

    test('setName_updatesName', () {
      final acc = ToolCallAccumulator()..name = 'calculator';
      expect(acc.name, 'calculator');
    });

    test('appendArguments_concatenates', () {
      final acc = ToolCallAccumulator()
        ..arguments += '{"expr'
        ..arguments += 'ession":"2+2"}';
      expect(acc.arguments, '{"expression":"2+2"}');
    });

    test('applyDelta_idSet_updatesId', () {
      final acc = ToolCallAccumulator();
      acc.applyDelta(const LlmToolCallDelta(index: 0, id: 'call_abc'));
      expect(acc.id, 'call_abc');
      expect(acc.name, isNull);
      expect(acc.arguments, '');
    });

    test('applyDelta_nameAndArgs_updatesFields', () {
      final acc = ToolCallAccumulator();
      acc.applyDelta(
        const LlmToolCallDelta(index: 0, name: 'timer', arguments: '{"a'),
      );
      expect(acc.name, 'timer');
      expect(acc.arguments, '{"a');
    });

    test('applyDelta_multipleCalls_accumulatesArgs', () {
      final acc = ToolCallAccumulator()
        ..applyDelta(const LlmToolCallDelta(index: 0, arguments: '{"ex'))
        ..applyDelta(const LlmToolCallDelta(index: 0, arguments: 'pr":1}'));
      expect(acc.arguments, '{"expr":1}');
    });

    test('applyDelta_nullFields_noChange', () {
      final acc = ToolCallAccumulator()..id = 'keep';
      acc.applyDelta(const LlmToolCallDelta(index: 0));
      expect(acc.id, 'keep');
    });
  });
}
