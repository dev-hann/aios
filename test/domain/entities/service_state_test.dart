import 'package:aios/domain/entities/service_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ServiceState', () {
    test('values_containsAllExpectedStates', () {
      const states = ServiceState.values;

      expect(states, contains(ServiceState.idle));
      expect(states, contains(ServiceState.loadingModel));
      expect(states, contains(ServiceState.ready));
      expect(states, contains(ServiceState.generating));
      expect(states, contains(ServiceState.error));
      expect(states.length, 5);
    });

    test('equality_sameState_returnsTrue', () {
      expect(ServiceState.idle == ServiceState.idle, isTrue);
      expect(ServiceState.ready == ServiceState.generating, isFalse);
    });

    test('values_areInCorrectOrder', () {
      expect(ServiceState.values[0], ServiceState.idle);
      expect(ServiceState.values[1], ServiceState.loadingModel);
      expect(ServiceState.values[2], ServiceState.ready);
      expect(ServiceState.values[3], ServiceState.generating);
      expect(ServiceState.values[4], ServiceState.error);
    });

    test('name_returnsExpectedStrings', () {
      expect(ServiceState.idle.name, 'idle');
      expect(ServiceState.loadingModel.name, 'loadingModel');
      expect(ServiceState.ready.name, 'ready');
      expect(ServiceState.generating.name, 'generating');
      expect(ServiceState.error.name, 'error');
    });

    test('switchStatement_worksForAllStates', () {
      for (final state in ServiceState.values) {
        final result = switch (state) {
          ServiceState.idle => 'idle',
          ServiceState.loadingModel => 'loading',
          ServiceState.ready => 'ready',
          ServiceState.generating => 'generating',
          ServiceState.error => 'error',
        };
        expect(result, isNotEmpty);
      }
    });
  });
}
