import 'package:aios/domain/entities/agent_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ToolRisk', () {
    test('hasAllExpectedValues', () {
      expect(ToolRisk.values, hasLength(4));
      expect(
        ToolRisk.values,
        containsAll([
          ToolRisk.safe,
          ToolRisk.low,
          ToolRisk.high,
          ToolRisk.critical,
        ]),
      );
    });

    test('name_property_matchesExpected', () {
      expect(ToolRisk.safe.name, 'safe');
      expect(ToolRisk.low.name, 'low');
      expect(ToolRisk.high.name, 'high');
      expect(ToolRisk.critical.name, 'critical');
    });

    test('valuesByIndex', () {
      expect(ToolRisk.values[0], ToolRisk.safe);
      expect(ToolRisk.values[1], ToolRisk.low);
      expect(ToolRisk.values[2], ToolRisk.high);
      expect(ToolRisk.values[3], ToolRisk.critical);
    });
  });

  group('AgentStep', () {
    test('create_withRequiredFields', () {
      const step = AgentStep('thought', 'Processing...');

      expect(step.type, 'thought');
      expect(step.content, 'Processing...');
    });

    test('create_withAllFields', () {
      const step = AgentStep(
        'action',
        'Using tool',
        toolName: 'calculator',
        toolArgs: '{"expression": "2+2"}',
        toolResult: '4',
        riskLevel: 'safe',
      );

      expect(step.type, 'action');
      expect(step.content, 'Using tool');
      expect(step.toolName, 'calculator');
      expect(step.toolArgs, '{"expression": "2+2"}');
      expect(step.toolResult, '4');
      expect(step.riskLevel, 'safe');
    });

    test('create_defaultsEmpty', () {
      const step = AgentStep('thought', 'test');

      expect(step.toolName, '');
      expect(step.toolArgs, '');
      expect(step.toolResult, '');
      expect(step.riskLevel, '');
    });

    test('copyWith_modifiesSpecifiedFields', () {
      const step = AgentStep('action', 'Using tool', toolName: 'calc');
      final copied = step.copyWith(toolName: 'timer', content: 'Setting timer');

      expect(copied.type, 'action');
      expect(copied.content, 'Setting timer');
      expect(copied.toolName, 'timer');
      expect(step.toolName, 'calc');
    });

    test('copyWith_preservesUnmodified', () {
      const step = AgentStep(
        'action',
        'desc',
        toolName: 'test',
        toolArgs: '{"a":1}',
        toolResult: 'ok',
        riskLevel: 'high',
      );
      final copied = step.copyWith(content: 'new desc');

      expect(copied.type, 'action');
      expect(copied.toolName, 'test');
      expect(copied.toolArgs, '{"a":1}');
      expect(copied.toolResult, 'ok');
      expect(copied.riskLevel, 'high');
    });

    test('equality_sameValues_areEqual', () {
      const a = AgentStep('thought', 'test', toolName: 'calc');
      const b = AgentStep('thought', 'test', toolName: 'calc');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality_differentValues_notEqual', () {
      const a = AgentStep('thought', 'test');
      const b = AgentStep('action', 'test');

      expect(a, isNot(equals(b)));
    });

    test('toJson_serializesAllFields', () {
      const step = AgentStep(
        'action',
        'desc',
        toolName: 'calc',
        toolArgs: '{}',
        toolResult: '42',
        riskLevel: 'safe',
      );

      final json = step.toJson();

      expect(json['type'], 'action');
      expect(json['content'], 'desc');
      expect(json['toolName'], 'calc');
      expect(json['toolArgs'], '{}');
      expect(json['toolResult'], '42');
      expect(json['riskLevel'], 'safe');
    });

    test('fromJson_deserializesAllFields', () {
      final json = {
        'type': 'answer',
        'content': 'Result is 42',
        'toolName': '',
        'toolArgs': '',
        'toolResult': '',
        'riskLevel': '',
      };

      final step = AgentStep.fromJson(json);

      expect(step.type, 'answer');
      expect(step.content, 'Result is 42');
      expect(step.toolName, '');
    });

    test('json_roundTrip_preservesData', () {
      const step = AgentStep(
        'observation',
        'Screen text',
        toolName: 'screen_reader',
        toolArgs: '{}',
        toolResult: 'Home',
        riskLevel: 'safe',
      );

      final json = step.toJson();
      final restored = AgentStep.fromJson(json);

      expect(restored, equals(step));
    });

    test('variousStepTypes', () {
      const types = [
        'thought',
        'action',
        'observation',
        'answer',
        'confirmation_required',
        'thinking_start',
        'thinking_end',
      ];

      for (final type in types) {
        final step = AgentStep(type, '$type content');
        expect(step.type, type);
      }
    });
  });

  group('AgentResult', () {
    test('create_withStepsAndSuccess', () {
      final result = AgentResult(
        steps: const [
          AgentStep('thought', 'Thinking'),
          AgentStep('answer', '42'),
        ],
        success: true,
      );

      expect(result.steps, hasLength(2));
      expect(result.success, isTrue);
    });

    test('create_emptySteps_unsuccessful', () {
      final result = AgentResult(steps: const [], success: false);

      expect(result.steps, isEmpty);
      expect(result.success, isFalse);
    });

    test('copyWith_modifiesFields', () {
      final original = AgentResult(
        steps: const [AgentStep('answer', 'yes')],
        success: true,
      );
      final copied = original.copyWith(success: false);

      expect(copied.success, isFalse);
      expect(copied.steps, hasLength(1));
      expect(original.success, isTrue);
    });

    test('equality', () {
      final a = AgentResult(
        steps: const [AgentStep('answer', '42')],
        success: true,
      );
      final b = AgentResult(
        steps: const [AgentStep('answer', '42')],
        success: true,
      );

      expect(a, equals(b));
    });

    test('toJson_serializesCorrectly', () {
      final result = AgentResult(
        steps: const [
          AgentStep('thought', 'think'),
          AgentStep('answer', 'done'),
        ],
        success: true,
      );

      final json = result.toJson();

      expect(json['success'], isTrue);
      expect(json['steps'], isA<List<dynamic>>());
    });

    test('fromJson_deserializesCorrectly', () {
      final json = {
        'steps': [
          {
            'type': 'thought',
            'content': 'think',
            'toolName': '',
            'toolArgs': '',
            'toolResult': '',
            'riskLevel': '',
          },
          {
            'type': 'answer',
            'content': 'done',
            'toolName': '',
            'toolArgs': '',
            'toolResult': '',
            'riskLevel': '',
          },
        ],
        'success': true,
      };

      final result = AgentResult.fromJson(json);

      expect(result.success, isTrue);
      expect(result.steps, hasLength(2));
      expect(result.steps.first.type, 'thought');
      expect(result.steps.last.type, 'answer');
    });
  });

  group('ToolAuditEntry', () {
    test('create_withAllFields', () {
      final entry = ToolAuditEntry(
        timestamp: 1700000000000,
        tool: 'calculator',
        args: '{"expression": "2+2"}',
        risk: ToolRisk.safe,
        approved: true,
        result: '4.0000',
      );

      expect(entry.timestamp, 1700000000000);
      expect(entry.tool, 'calculator');
      expect(entry.args, '{"expression": "2+2"}');
      expect(entry.risk, ToolRisk.safe);
      expect(entry.approved, isTrue);
      expect(entry.result, '4.0000');
    });

    test('create_rejectedEntry', () {
      final entry = ToolAuditEntry(
        timestamp: 0,
        tool: 'sms_sender',
        args: '{"action": "send"}',
        risk: ToolRisk.critical,
        approved: false,
        result: 'Cancelled by user',
      );

      expect(entry.approved, isFalse);
      expect(entry.risk, ToolRisk.critical);
    });

    test('copyWith_modifiesFields', () {
      final original = ToolAuditEntry(
        timestamp: 1000,
        tool: 'test',
        args: '{}',
        risk: ToolRisk.safe,
        approved: true,
        result: 'ok',
      );
      final copied = original.copyWith(approved: false, result: 'denied');

      expect(copied.approved, isFalse);
      expect(copied.result, 'denied');
      expect(copied.tool, 'test');
      expect(original.approved, isTrue);
    });

    test('equality', () {
      final a = ToolAuditEntry(
        timestamp: 1000,
        tool: 'calc',
        args: '{}',
        risk: ToolRisk.safe,
        approved: true,
        result: 'ok',
      );
      final b = ToolAuditEntry(
        timestamp: 1000,
        tool: 'calc',
        args: '{}',
        risk: ToolRisk.safe,
        approved: true,
        result: 'ok',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality_differentFields_notEqual', () {
      final a = ToolAuditEntry(
        timestamp: 1000,
        tool: 'calc',
        args: '{}',
        risk: ToolRisk.safe,
        approved: true,
        result: 'ok',
      );
      final b = ToolAuditEntry(
        timestamp: 1000,
        tool: 'calc',
        args: '{}',
        risk: ToolRisk.high,
        approved: true,
        result: 'ok',
      );

      expect(a, isNot(equals(b)));
    });

    test('toJson_serializesAllFields', () {
      final entry = ToolAuditEntry(
        timestamp: 1700000000000,
        tool: 'screen_action',
        args: '{"action": "tap"}',
        risk: ToolRisk.high,
        approved: true,
        result: 'tapped',
      );

      final json = entry.toJson();

      expect(json['timestamp'], 1700000000000);
      expect(json['tool'], 'screen_action');
      expect(json['risk'], 'high');
      expect(json['approved'], isTrue);
    });

    test('fromJson_deserializesAllFields', () {
      final json = {
        'timestamp': 1700000000000,
        'tool': 'phone_caller',
        'args': '{"action": "call"}',
        'risk': 'critical',
        'approved': false,
        'result': 'Cancelled',
      };

      final entry = ToolAuditEntry.fromJson(json);

      expect(entry.timestamp, 1700000000000);
      expect(entry.tool, 'phone_caller');
      expect(entry.risk, ToolRisk.critical);
      expect(entry.approved, isFalse);
      expect(entry.result, 'Cancelled');
    });

    test('json_roundTrip_preservesData', () {
      final entry = ToolAuditEntry(
        timestamp: 1700000000000,
        tool: 'notepad',
        args: '{"action": "save"}',
        risk: ToolRisk.safe,
        approved: true,
        result: 'Saved',
      );

      final json = entry.toJson();
      final restored = ToolAuditEntry.fromJson(json);

      expect(restored, equals(entry));
    });

    test('allRiskLevels_serializedCorrectly', () {
      for (final risk in ToolRisk.values) {
        final entry = ToolAuditEntry(
          timestamp: 0,
          tool: 'test',
          args: '{}',
          risk: risk,
          approved: true,
          result: 'ok',
        );

        final json = entry.toJson();
        final restored = ToolAuditEntry.fromJson(json);

        expect(restored.risk, risk);
      }
    });
  });
}
