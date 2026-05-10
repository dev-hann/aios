import 'package:aios/domain/agent/version_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareVersions', () {
    test('compareVersions_equalVersions_returns0', () {
      expect(compareVersions('1.0.0', '1.0.0'), equals(0));
    });

    test('compareVersions_aGreater_returnsPositive', () {
      expect(compareVersions('2.0.0', '1.0.0'), greaterThan(0));
    });

    test('compareVersions_aSmaller_returnsNegative', () {
      expect(compareVersions('1.0.0', '2.0.0'), lessThan(0));
    });

    test('compareVersions_differentPatch_returnsCorrect', () {
      expect(compareVersions('1.0.2', '1.0.1'), greaterThan(0));
    });

    test('compareVersions_differentMinor_returnsCorrect', () {
      expect(compareVersions('1.2.0', '1.1.0'), greaterThan(0));
    });

    test('compareVersions_differentLength_aShorter_returnsNegative', () {
      expect(compareVersions('1.0', '1.0.1'), lessThan(0));
    });

    test('compareVersions_differentLength_bShorter_returnsPositive', () {
      expect(compareVersions('1.0.1', '1.0'), greaterThan(0));
    });

    test('compareVersions_nonNumericParts_handledGracefully', () {
      expect(compareVersions('1.0.0', '1.0.0'), equals(0));
    });

    test('compareVersions_sameVersions_returnsZero', () {
      expect(compareVersions('2.1.27', '2.1.27'), equals(0));
    });

    test('compareVersions_majorDifference', () {
      expect(compareVersions('3.0.0', '2.9.9'), greaterThan(0));
    });

    test('compareVersions_singlePart', () {
      expect(compareVersions('2', '1'), greaterThan(0));
    });

    test('compareVersions_emptyStrings_returns0', () {
      expect(compareVersions('', ''), equals(0));
    });

    test('compareVersions_nonNumericWithDefault', () {
      expect(compareVersions('abc', 'def'), equals(0));
    });
  });

  group('stripVersionPrefix', () {
    test('stripVersionPrefix_withVPrefix_stripsPrefix', () {
      expect(stripVersionPrefix('v2.1.0'), equals('2.1.0'));
    });

    test('stripVersionPrefix_withoutVPrefix_returnsSame', () {
      expect(stripVersionPrefix('2.1.0'), equals('2.1.0'));
    });

    test('stripVersionPrefix_uppercaseV_notStripped', () {
      expect(stripVersionPrefix('V2.1.0'), equals('V2.1.0'));
    });

    test('stripVersionPrefix_emptyString_returnsEmpty', () {
      expect(stripVersionPrefix(''), isEmpty);
    });
  });
}
