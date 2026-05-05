import 'package:aios/domain/entities/service_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ServiceState', () {
    test('should have all expected states', () {
      const states = ServiceState.values;

      expect(states, contains(ServiceState.idle));
      expect(states, contains(ServiceState.loadingModel));
      expect(states, contains(ServiceState.ready));
      expect(states, contains(ServiceState.generating));
      expect(states, contains(ServiceState.error));
      expect(states.length, 5);
    });

    test('should be comparable', () {
      expect(ServiceState.idle == ServiceState.idle, isTrue);
      expect(ServiceState.ready == ServiceState.generating, isFalse);
    });
  });
}
