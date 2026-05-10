import 'package:aios/domain/agent/tool_json_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tryParseToolJson', () {
    test('tryParseToolJson_validJsonObject_returnsMap', () {
      final result = tryParseToolJson('{"key": "value"}', 'AIOS-Test');
      expect(result, {'key': 'value'});
    });

    test('tryParseToolJson_emptyObject_returnsEmptyMap', () {
      final result = tryParseToolJson('{}', 'AIOS-Test');
      expect(result, {});
    });

    test('tryParseToolJson_invalidJson_returnsEmptyMap', () {
      final result = tryParseToolJson('not json', 'AIOS-Test');
      expect(result, {});
    });

    test('tryParseToolJson_emptyString_returnsEmptyMap', () {
      final result = tryParseToolJson('', 'AIOS-Test');
      expect(result, {});
    });

    test('tryParseToolJson_jsonArray_returnsEmptyMap', () {
      final result = tryParseToolJson('[1, 2, 3]', 'AIOS-Test');
      expect(result, {});
    });

    test('tryParseToolJson_jsonString_returnsEmptyMap', () {
      final result = tryParseToolJson('"hello"', 'AIOS-Test');
      expect(result, {});
    });

    test('tryParseToolJson_jsonNumber_returnsEmptyMap', () {
      final result = tryParseToolJson('42', 'AIOS-Test');
      expect(result, {});
    });

    test('tryParseToolJson_nestedObject_returnsNestedMap', () {
      final result = tryParseToolJson(
        '{"action": "tap", "text": "hello"}',
        'AIOS-Test',
      );
      expect(result['action'], 'tap');
      expect(result['text'], 'hello');
    });
  });

  group('parseIntDynamic', () {
    test('parseIntDynamic_int_returnsInt', () {
      expect(parseIntDynamic(42), 42);
    });

    test('parseIntDynamic_stringInt_returnsInt', () {
      expect(parseIntDynamic('42'), 42);
    });

    test('parseIntDynamic_stringNegative_returnsNegative', () {
      expect(parseIntDynamic('-5'), -5);
    });

    test('parseIntDynamic_stringNonNumeric_returnsNull', () {
      expect(parseIntDynamic('abc'), isNull);
    });

    test('parseIntDynamic_double_returnsNull', () {
      expect(parseIntDynamic(3.14), isNull);
    });

    test('parseIntDynamic_null_returnsNull', () {
      expect(parseIntDynamic(null), isNull);
    });

    test('parseIntDynamic_emptyString_returnsNull', () {
      expect(parseIntDynamic(''), isNull);
    });
  });
}
