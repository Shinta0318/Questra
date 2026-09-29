import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;
  final migration = File(
    '${repo.path}/supabase/migrations/'
    '202609130004_ai_budget_reconciliation_operator_queue.sql',
  ).readAsStringSync();
  final runbook = File(
    '${repo.path}/docs/product/ai_budget_reconciliation_operator_queue.md',
  ).readAsStringSync();

  test('queue claims are service-only leased and concurrency safe', () {
    expect(migration, contains('ai_budget_reconciliation_operators'));
    expect(migration, contains('claim_ai_budget_reconciliation_cases'));
    expect(migration, contains("auth.role() is distinct from 'service_role'"));
    expect(migration, contains('for update skip locked'));
    expect(migration, contains("interval '5 minutes'"));
    expect(migration, contains("interval '2 hours'"));
    expect(migration, contains('expired_claim_reclaimed'));
  });

  test('operator decisions use allowlisted codes without free text', () {
    expect(migration, contains('resolution_code'));
    expect(
      migration,
      contains('ai_budget_reconciliation_case_note_empty_check'),
    );
    expect(migration, contains('resolution_note is null'));
    expect(migration, contains("'evidence_verified_no_change'"));
    expect(migration, contains("'reservation_released_no_execution'"));
    expect(migration, contains("'evidence_unavailable'"));
    expect(migration, isNot(contains('p_resolution_note')));
  });

  test('budget correction requires a separate two-person transaction', () {
    expect(migration, contains('request_ai_budget_correction'));
    expect(migration, contains('review_ai_budget_correction'));
    expect(migration, contains('apply_ai_budget_correction'));
    expect(migration, contains('budget_correction_self_approval_forbidden'));
    expect(migration, contains("status = 'approved'"));
    expect(migration, contains('budget_correction_stale_snapshot'));
    expect(migration, contains('for update'));
    expect(runbook, contains('利用者への請求を変更する機能ではない'));
  });

  test('metrics are aggregate-only and client tables stay private', () {
    expect(migration, contains('get_ai_budget_reconciliation_queue_metrics'));
    expect(migration, contains("'open_count'"));
    expect(migration, contains("'sla_breached_count'"));
    expect(migration, contains("'oldest_open_age_seconds'"));
    final metricsStart = migration.indexOf(
      'create or replace function '
      'public.get_ai_budget_reconciliation_queue_metrics',
    );
    final metricsEnd = migration.indexOf(
      'create or replace function '
      'public.purge_expired_ai_budget_operator_evidence',
    );
    final metrics = migration.substring(metricsStart, metricsEnd);
    expect(metrics, isNot(contains("'reservation_id'")));
    expect(metrics, isNot(contains("'user_id'")));
    expect(migration, contains('from public, anon, authenticated'));
    expect(runbook, contains('識別子を返さない'));
  });

  test('operator evidence is bounded and rollback is forward-safe', () {
    expect(migration, contains("interval '730 days'"));
    expect(migration, contains('purge_expired_ai_budget_operator_evidence'));
    expect(migration, contains('p_limit not between 1 and 10000'));
    expect(migration, contains("review.status = 'open'"));
    expect(runbook, contains('破壊的なdown migrationは実行しない'));
    expect(runbook, contains('補正request'));
  });
}
