import 'package:aios/core/theme/time_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatTimeOfDay', () {
    test('formatTimeOfDay_midnight_returns00_00', () {
      final dt = DateTime(2024, 1, 1, 0, 0);
      expect(formatTimeOfDay(dt), '00:00');
    });

    test('formatTimeOfDay_afternoon_returnsCorrectTime', () {
      final dt = DateTime(2024, 1, 1, 14, 30);
      expect(formatTimeOfDay(dt), '14:30');
    });

    test('formatTimeOfDay_singleDigitPadsZero', () {
      final dt = DateTime(2024, 1, 1, 9, 5);
      expect(formatTimeOfDay(dt), '09:05');
    });

    test('formatTimeOfDay_endOfDay_returns23_59', () {
      final dt = DateTime(2024, 1, 1, 23, 59);
      expect(formatTimeOfDay(dt), '23:59');
    });
  });
}
