import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;
  final tabletop = File(
    '${repo.path}/docs/qst/AI_BUDGET_OPERATIONS_TABLETOP.yaml',
  ).readAsStringSync();
  final runbook = File(
    '${repo.path}/docs/product/ai_budget_operations_recovery.md',
  ).readAsStringSync();

  test(
    'every scenario has severity owner stop decision recovery and result',
    () {
      for (final scenario in <String>[
        'provider_outage',
        'settlement_response_lost_after_commit',
        'reconciliation_queue_backlog',
        'incorrect_correction_applied',
        'cross_owner_or_negative_counter',
      ]) {
        final start = tabletop.indexOf('id: $scenario');
        expect(start, greaterThanOrEqualTo(0));
        final end = tabletop.indexOf('\n  - id:', start + 1);
        final section = tabletop.substring(
          start,
          end < 0 ? tabletop.indexOf('\nuser_notifications:', start) : end,
        );
        for (final field in <String>[
          'severity:',
          'detection:',
          'owner:',
          'stop_decision:',
          'recovery:',
          'result:',
        ]) {
          expect(section, contains(field), reason: '$scenario requires $field');
        }
      }
    },
  );

  test('severity policy defines acknowledgement containment and recovery', () {
    for (final value in <String>[
      'acknowledge_minutes:',
      'contain_minutes:',
      'recovery_minutes:',
      'distribution:',
    ]) {
      expect(tabletop, contains(value));
    }
    expect(runbook, contains('S0'));
    expect(runbook, contains('S1'));
    expect(runbook, contains('S2'));
  });

  test('user copy hides technical and internal cost details', () {
    expect(tabletop, contains('expose_internal_cost: false'));
    expect(tabletop, contains('expose_model_or_provider_error: false'));
    expect(tabletop, contains('expose_reservation_or_trace: false'));
    expect(runbook, contains('技術用語、内部費用'));
    expect(runbook, contains('相談内容は保持されています'));
  });

  test('incorrect correction is compensated without audit rewriting', () {
    expect(
      tabletop,
      contains('create_separate_compensating_request_from_current_snapshot'),
    );
    expect(tabletop, contains('delete_or_rewrite_prior_audit: prohibited'));
    expect(runbook, contains('別requestを作り'));
    expect(runbook, contains('別requester／approver'));
  });

  test('tabletop findings feed review and preserve external beta no-go', () {
    expect(tabletop, contains('owner_qst: QST-455'));
    expect(tabletop, contains('current_decision: no_go'));
    expect(tabletop, contains('tabletop_is_hosted_execution_evidence: false'));
    expect(runbook, contains('External BetaはNO-GO'));
  });
}
