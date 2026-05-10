import 'package:aios/domain/agent/truncate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('truncate', () {
    test('truncate_shortString_returnsSame', () {
      expect(truncate('hello', 10), 'hello');
    });

    test('truncate_exactLength_returnsSame', () {
      expect(truncate('hello', 5), 'hello');
    });

    test('truncate_longString_truncates', () {
      expect(truncate('hello world', 5), 'hello');
    });

    test('truncate_emptyString_returnsEmpty', () {
      expect(truncate('', 5), '');
    });

    test('truncate_zeroLength_returnsEmpty', () {
      expect(truncate('hello', 0), '');
    });
  });
}
