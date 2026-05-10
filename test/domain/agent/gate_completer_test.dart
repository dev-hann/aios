import 'package:aios/domain/agent/gate_completer.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestGate extends GateCompleter {
  Future<bool> doWait() => waitForResolution(
    timeout: const Duration(milliseconds: 100),
    tag: 'TestGate',
    label: 'test',
  );
}

void main() {
  group('GateCompleter', () {
    late _TestGate gate;

    setUp(() {
      gate = _TestGate();
    });

    test('resolve_true_completesWithTrue', () async {
      gate.createCompleter();
      final future = gate.doWait();
      gate.resolve(true);
      expect(await future, isTrue);
    });

    test('resolve_false_completesWithFalse', () async {
      gate.createCompleter();
      final future = gate.doWait();
      gate.resolve(false);
      expect(await future, isFalse);
    });

    test('cancel_completesWithFalse', () async {
      gate.createCompleter();
      final future = gate.doWait();
      gate.cancel();
      expect(await future, isFalse);
    });

    test('timeout_returnsFalse', () async {
      gate.createCompleter();
      final result = await gate.doWait();
      expect(result, isFalse);
    });

    test('resolve_beforeWait_completesImmediately', () async {
      gate.createCompleter();
      gate.resolve(true);
      expect(await gate.doWait(), isTrue);
    });

    test('resolve_multipleTimes_firstWins', () async {
      gate.createCompleter();
      final future = gate.doWait();
      gate.resolve(true);
      gate.resolve(false);
      expect(await future, isTrue);
    });

    test('cancel_afterResolve_noEffect', () async {
      gate.createCompleter();
      final future = gate.doWait();
      gate.resolve(true);
      gate.cancel();
      expect(await future, isTrue);
    });

    test('resolve_withoutCreateCompleter_noError', () {
      gate.resolve(true);
    });

    test('cancel_withoutCreateCompleter_noError', () {
      gate.cancel();
    });

    test('createCompleter_resetsState', () async {
      gate.createCompleter();
      gate.resolve(true);
      expect(await gate.doWait(), isTrue);

      gate.createCompleter();
      final future = gate.doWait();
      gate.resolve(false);
      expect(await future, isFalse);
    });
  });
}
