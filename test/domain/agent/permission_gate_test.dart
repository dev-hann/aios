import 'package:aios/domain/agent/permission_gate.dart';
import 'package:aios/domain/agent/tool_permission_mapper.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionGate', () {
    late PermissionGate gate;

    setUp(() {
      gate = PermissionGate();
    });

    group('requestPermission', () {
      test('requestPermission_resolvesGranted_returnsTrue', () async {
        const perm = RequiredPermission(
          key: 'contacts',
          displayName: '연락처',
          isService: false,
        );

        final future = gate.requestPermission(perm, 'contact_search', (_) {});
        gate.resolve(value: true);
        expect(await future, isTrue);
      });

      test('requestPermission_resolvesDenied_returnsFalse', () async {
        const perm = RequiredPermission(
          key: 'contacts',
          displayName: '연락처',
          isService: false,
        );

        final future = gate.requestPermission(perm, 'contact_search', (_) {});
        gate.resolve(value: false);
        expect(await future, isFalse);
      });

      test('requestPermission_emitsPermissionRequiredStep', () async {
        const perm = RequiredPermission(
          key: 'contacts',
          displayName: '연락처',
          isService: false,
        );

        AgentStep? captured;
        final future = gate.requestPermission(
          perm,
          'contact_search',
          (step) => captured = step,
        );
        gate.resolve(value: true);
        await future;

        expect(captured, isNotNull);
        expect(captured!.type, 'permission_required');
        expect(captured!.toolName, 'contact_search');
        expect(captured!.permission, 'contacts');
      });
    });

    group('cancel', () {
      test('cancel_completesWithFalse', () async {
        const perm = RequiredPermission(
          key: 'contacts',
          displayName: '연락처',
          isService: false,
        );

        final future = gate.requestPermission(perm, 'contact_search', (_) {});
        gate.cancel();
        expect(await future, isFalse);
      });
    });

    group('resolve', () {
      test('resolve_withoutRequest_doesNotThrow', () {
        expect(() => gate.resolve(value: true), returnsNormally);
      });

      test('resolve_multipleTimes_doesNotThrow', () async {
        const perm = RequiredPermission(
          key: 'contacts',
          displayName: '연락처',
          isService: false,
        );

        final future = gate.requestPermission(perm, 'contact_search', (_) {});
        gate
          ..resolve(value: true)
          ..resolve(value: true);
        expect(await future, isTrue);
      });
    });
  });
}
