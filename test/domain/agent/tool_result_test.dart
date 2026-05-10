import 'package:aios/domain/agent/tool_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ToolResult', () {
    group('ok constructor', () {
      test('ok_withOutput_isNotError', () {
        const result = ToolResult.ok('success');
        expect(result.isError, isFalse);
        expect(result.output, 'success');
        expect(result.error, isNull);
      });

      test('ok_withSystemAndObservation_includesBoth', () {
        const result = ToolResult.ok('done', system: 'sys', observation: 'obs');
        expect(result.output, 'done');
        expect(result.system, 'sys');
        expect(result.observation, 'obs');
      });
    });

    group('err constructor', () {
      test('err_withMessage_isError', () {
        const result = ToolResult.err('something failed');
        expect(result.isError, isTrue);
        expect(result.error, 'something failed');
        expect(result.output, isNull);
        expect(result.observation, isNull);
      });

      test('err_withSystem_includesSystem', () {
        const result = ToolResult.err('fail', system: 'context');
        expect(result.error, 'fail');
        expect(result.system, 'context');
      });
    });

    group('toContent', () {
      test('toContent_okOutput_returnsOutput', () {
        const result = ToolResult.ok('hello');
        expect(result.toContent(), 'hello');
      });

      test('toContent_error_returnsErrorPrefix', () {
        const result = ToolResult.err('bad');
        expect(result.toContent(), 'Error: bad');
      });

      test('toContent_withSystem_wrapsInSystemTag', () {
        const result = ToolResult.ok('ok', system: 'info');
        expect(result.toContent(), '<system>info</system>\nok');
      });

      test('toContent_withObservation_appendsScreen', () {
        const result = ToolResult.ok('ok', observation: 'screen text');
        expect(result.toContent(), 'ok\nScreen: screen text');
      });

      test('toContent_withAllFields_formatsCorrectly', () {
        const result = ToolResult.ok('done', system: 'sys', observation: 'obs');
        expect(result.toContent(), '<system>sys</system>\ndone\nScreen: obs');
      });

      test('toContent_errorWithSystem_formatsCorrectly', () {
        const result = ToolResult.err('fail', system: 'context');
        expect(result.toContent(), '<system>context</system>\nError: fail');
      });
    });

    group('toString', () {
      test('toString_returnsToContent', () {
        const result = ToolResult.ok('test');
        expect(result.toString(), result.toContent());
      });
    });

    group('default constructor', () {
      test('default_allNull_isNotError', () {
        const result = ToolResult();
        expect(result.isError, isFalse);
        expect(result.output, isNull);
        expect(result.error, isNull);
        expect(result.toContent(), '');
      });
    });

    group('fromPlatformResult', () {
      test('fromPlatformResult_null_returnsErrorWithAction', () {
        final result = ToolResult.fromPlatformResult(null, 'tap by text');
        expect(result.isError, isTrue);
        expect(
          result.error,
          'tap by text failed - no response from platform',
        );
        expect(result.output, isNull);
      });

      test('fromPlatformResult_nonNull_returnsOk', () {
        final result = ToolResult.fromPlatformResult('OK', 'tap');
        expect(result.isError, isFalse);
        expect(result.output, 'OK');
        expect(result.error, isNull);
      });

      test('fromPlatformResult_emptyString_returnsOk', () {
        final result = ToolResult.fromPlatformResult('', 'scroll');
        expect(result.isError, isFalse);
        expect(result.output, '');
      });
    });
  });
}
