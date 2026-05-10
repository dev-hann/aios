import 'package:aios/domain/agent/audit_log.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuditLog', () {
    late AuditLog log;

    setUp(() {
      log = AuditLog();
    });

    group('add', () {
      test('add_singleEntry_stored', () {
        log.add(
          'calculator',
          '{}',
          ToolRisk.safe,
          approved: true,
          result: '42',
        );

        final entries = log.getAll();
        expect(entries, hasLength(1));
        expect(entries.first.tool, 'calculator');
        expect(entries.first.args, '{}');
        expect(entries.first.risk, ToolRisk.safe);
        expect(entries.first.approved, isTrue);
        expect(entries.first.result, '42');
      });

      test('add_multipleEntries_storedInOrder', () {
        log
          ..add('calculator', '{}', ToolRisk.safe, approved: true, result: '42')
          ..add(
            'screen_action',
            '{"action":"tap"}',
            ToolRisk.high,
            approved: true,
            result: 'tapped',
          )
          ..add(
            'sms_sender',
            '{"action":"send"}',
            ToolRisk.critical,
            approved: false,
            result: 'cancelled',
          );

        final entries = log.getAll();
        expect(entries, hasLength(3));
        expect(entries[0].tool, 'calculator');
        expect(entries[1].tool, 'screen_action');
        expect(entries[2].tool, 'sms_sender');
        expect(entries[2].approved, isFalse);
      });

      test('add_hasValidTimestamp', () {
        final before = DateTime.now().millisecondsSinceEpoch;
        log.add('test', '{}', ToolRisk.safe, approved: true, result: 'ok');
        final after = DateTime.now().millisecondsSinceEpoch;

        final entry = log.getAll().first;
        expect(entry.timestamp, greaterThanOrEqualTo(before));
        expect(entry.timestamp, lessThanOrEqualTo(after));
      });

      test('add_allRiskLevels', () {
        log
          ..add('t1', '{}', ToolRisk.safe, approved: true, result: 'ok')
          ..add('t2', '{}', ToolRisk.low, approved: true, result: 'ok')
          ..add('t3', '{}', ToolRisk.high, approved: true, result: 'ok')
          ..add('t4', '{}', ToolRisk.critical, approved: false, result: 'no');

        final entries = log.getAll();
        expect(entries[0].risk, ToolRisk.safe);
        expect(entries[1].risk, ToolRisk.low);
        expect(entries[2].risk, ToolRisk.high);
        expect(entries[3].risk, ToolRisk.critical);
      });

      test('add_emptyResult_stored', () {
        log.add(
          'screen_reader',
          '{}',
          ToolRisk.safe,
          approved: true,
          result: '',
        );

        final entries = log.getAll();
        expect(entries.first.result, isEmpty);
      });

      test('add_longArgs_stored', () {
        final longArgs = '{"data": "${"x" * 5000}"}';
        log.add('test', longArgs, ToolRisk.safe, approved: true, result: 'ok');

        expect(log.getAll().first.args, longArgs);
      });

      test('add_longResult_stored', () {
        final longResult = 'R' * 10000;
        log.add(
          'test',
          '{}',
          ToolRisk.safe,
          approved: true,
          result: longResult,
        );

        expect(log.getAll().first.result, longResult);
      });
    });

    group('maxSize', () {
      test('add_withinMaxSize_allRetained', () {
        log = AuditLog(maxSize: 5);

        for (var i = 0; i < 5; i++) {
          log.add(
            'tool$i',
            '{}',
            ToolRisk.safe,
            approved: true,
            result: 'result$i',
          );
        }

        expect(log.getAll(), hasLength(5));
      });

      test('add_exceedsMaxSize_oldestEvicted', () {
        log = AuditLog(maxSize: 3);

        for (var i = 0; i < 5; i++) {
          log.add(
            'tool$i',
            '{}',
            ToolRisk.safe,
            approved: true,
            result: 'result$i',
          );
        }

        final entries = log.getAll();
        expect(entries, hasLength(3));
        expect(entries[0].tool, 'tool2');
        expect(entries[1].tool, 'tool3');
        expect(entries[2].tool, 'tool4');
      });

      test('add_maxSizeOne_keepsOnlyLast', () {
        log = AuditLog(maxSize: 1)
          ..add('first', '{}', ToolRisk.safe, approved: true, result: 'r1')
          ..add('second', '{}', ToolRisk.safe, approved: true, result: 'r2');

        final entries = log.getAll();
        expect(entries, hasLength(1));
        expect(entries.first.tool, 'second');
      });

      test('add_exactlyAtMaxSize_noEviction', () {
        log = AuditLog();

        for (var i = 0; i < 100; i++) {
          log.add('tool$i', '{}', ToolRisk.safe, approved: true, result: 'r$i');
        }

        expect(log.getAll(), hasLength(100));
        expect(log.getAll().first.tool, 'tool0');
        expect(log.getAll().last.tool, 'tool99');
      });

      test('add_wayOverMaxSize_keepsMaxSize', () {
        log = AuditLog(maxSize: 10);

        for (var i = 0; i < 200; i++) {
          log.add('tool$i', '{}', ToolRisk.safe, approved: true, result: 'r$i');
        }

        expect(log.getAll(), hasLength(10));
        expect(log.getAll().first.tool, 'tool190');
        expect(log.getAll().last.tool, 'tool199');
      });
    });

    group('getAll', () {
      test('getAll_empty_returnsEmptyList', () {
        expect(log.getAll(), isEmpty);
      });

      test('getAll_returnsUnmodifiableList', () {
        log.add('test', '{}', ToolRisk.safe, approved: true, result: 'ok');

        final entries = log.getAll();

        expect(entries.clear, throwsA(isA<UnsupportedError>()));
      });

      test('getAll_returnsSnapshot_notLiveView', () {
        log.add('test', '{}', ToolRisk.safe, approved: true, result: 'ok');

        final snapshot = log.getAll();
        log.add('test2', '{}', ToolRisk.safe, approved: true, result: 'ok2');

        expect(snapshot, hasLength(1));
        expect(log.getAll(), hasLength(2));
      });
    });

    group('clear', () {
      test('clear_removesAllEntries', () {
        log
          ..add('t1', '{}', ToolRisk.safe, approved: true, result: 'ok')
          ..add('t2', '{}', ToolRisk.high, approved: false, result: 'no')
          ..clear();

        expect(log.getAll(), isEmpty);
      });

      test('clear_empty_doesNothing', () {
        log.clear();

        expect(log.getAll(), isEmpty);
      });

      test('clear_allowsNewEntries', () {
        log
          ..add('old', '{}', ToolRisk.safe, approved: true, result: 'ok')
          ..clear()
          ..add('new', '{}', ToolRisk.safe, approved: true, result: 'ok2');

        final entries = log.getAll();
        expect(entries, hasLength(1));
        expect(entries.first.tool, 'new');
      });

      test('clear_respectsMaxSizeAfterClear', () {
        log = AuditLog(maxSize: 2)
          ..add('a', '{}', ToolRisk.safe, approved: true, result: '1')
          ..add('b', '{}', ToolRisk.safe, approved: true, result: '2')
          ..clear()
          ..add('c', '{}', ToolRisk.safe, approved: true, result: '3')
          ..add('d', '{}', ToolRisk.safe, approved: true, result: '4')
          ..add('e', '{}', ToolRisk.safe, approved: true, result: '5');

        final entries = log.getAll();
        expect(entries, hasLength(2));
        expect(entries[0].tool, 'd');
        expect(entries[1].tool, 'e');
      });
    });
  });
}
