import 'package:aios/domain/agent/confirmation_gate.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConfirmationGate', () {
    late ConfirmationGate gate;

    setUp(() {
      gate = ConfirmationGate();
    });

    group('requestConfirmation', () {
      test('requestConfirmation_emitsConfirmationStep', () async {
        AgentStep? capturedStep;

        final future = gate.requestConfirmation(
          ToolRisk.high,
          'app_launcher',
          '{"action": "open_app"}',
          (step) => capturedStep = step,
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(capturedStep, isNotNull);
        expect(capturedStep!.type, 'confirmation_required');
        expect(capturedStep!.toolName, 'app_launcher');
        expect(capturedStep!.toolArgs, '{"action": "open_app"}');
        expect(capturedStep!.riskLevel, 'high');

        gate.resolve(value: true);
        await future;
      });

      test('requestConfirmation_approved_returnsTrue', () async {
        final future = gate.requestConfirmation(
          ToolRisk.high,
          'screen_action',
          '{}',
          (_) {},
        );

        gate.resolve(value: true);

        final result = await future;

        expect(result, isTrue);
      });

      test('requestConfirmation_denied_returnsFalse', () async {
        final future = gate.requestConfirmation(
          ToolRisk.high,
          'screen_action',
          '{}',
          (_) {},
        );

        gate.resolve(value: false);

        final result = await future;

        expect(result, isFalse);
      });

      test('requestConfirmation_criticalRisk_emitsCriticalLevel', () async {
        AgentStep? capturedStep;

        final future = gate.requestConfirmation(
          ToolRisk.critical,
          'sms_sender',
          '{"action": "send"}',
          (step) => capturedStep = step,
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(capturedStep!.riskLevel, 'critical');

        gate.resolve(value: true);
        await future;
      });

      test('requestConfirmation_stepContent_containsToolName', () async {
        AgentStep? capturedStep;

        final future = gate.requestConfirmation(
          ToolRisk.high,
          'phone_caller',
          '{"action": "call"}',
          (step) => capturedStep = step,
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(capturedStep!.content, contains('phone_caller'));

        gate.resolve(value: true);
        await future;
      });

      test('requestConfirmation_timeout_returnsFalse', () async {
        final result = await gate
            .requestConfirmation(ToolRisk.high, 'test', '{}', (_) {})
            .timeout(const Duration(milliseconds: 100), onTimeout: () => false);

        expect(result, isFalse);
      });
    });

    group('resolve', () {
      test('resolve_multipleTimesOnlyFirstTakesEffect', () async {
        final future = gate.requestConfirmation(
          ToolRisk.high,
          'test',
          '{}',
          (_) {},
        );

        gate
          ..resolve(value: true)
          ..resolve(value: false);

        final result = await future;

        expect(result, isTrue);
      });

      test('resolve_withoutPendingRequest_doesNotThrow', () async {
        expect(() => gate.resolve(value: true), returnsNormally);
        expect(() => gate.resolve(value: false), returnsNormally);
      });

      test('resolve_true_afterCancel_doesNotChangeResult', () async {
        final future = gate.requestConfirmation(
          ToolRisk.high,
          'test',
          '{}',
          (_) {},
        );

        gate
          ..cancel()
          ..resolve(value: true);

        final result = await future;
        expect(result, isFalse);
      });
    });

    group('cancel', () {
      test('cancel_returnsFalse', () async {
        final future = gate.requestConfirmation(
          ToolRisk.high,
          'test',
          '{}',
          (_) {},
        );

        gate.cancel();

        final result = await future;

        expect(result, isFalse);
      });

      test('cancel_withoutPendingRequest_doesNotThrow', () async {
        expect(() => gate.cancel(), returnsNormally);
      });

      test('cancel_thenNewRequest_worksIndependently', () async {
        final future1 = gate.requestConfirmation(
          ToolRisk.high,
          'first',
          '{}',
          (_) {},
        );
        gate.cancel();
        final r1 = await future1;
        expect(r1, isFalse);

        final future2 = gate.requestConfirmation(
          ToolRisk.high,
          'second',
          '{}',
          (_) {},
        );
        gate.resolve(value: true);
        final r2 = await future2;
        expect(r2, isTrue);
      });
    });

    group('sequentialRequests', () {
      test('multipleSequentialRequests_eachIndependent', () async {
        final future1 = gate.requestConfirmation(
          ToolRisk.high,
          't1',
          '{}',
          (_) {},
        );
        gate.resolve(value: true);
        final r1 = await future1;
        expect(r1, isTrue);

        final future2 = gate.requestConfirmation(
          ToolRisk.high,
          't2',
          '{}',
          (_) {},
        );
        gate.resolve(value: false);
        final r2 = await future2;
        expect(r2, isFalse);

        final future3 = gate.requestConfirmation(
          ToolRisk.critical,
          't3',
          '{}',
          (_) {},
        );
        gate.resolve(value: true);
        final r3 = await future3;
        expect(r3, isTrue);
      });
    });
  });
}
