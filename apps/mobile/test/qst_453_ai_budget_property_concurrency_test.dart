import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;
  final propertySql = File(
    '${repo.path}/supabase/tests/qst_453_ai_budget_properties.sql',
  ).readAsStringSync();
  final runner = File(
    '${repo.path}/tools/qst/run_ai_budget_concurrency_drill.ps1',
  ).readAsStringSync();
  final runbook = File(
    '${repo.path}/docs/product/ai_budget_property_concurrency_testing.md',
  ).readAsStringSync();
  final correction = File(
    '${repo.path}/supabase/migrations/'
    '202609130004_ai_budget_reconciliation_operator_queue.sql',
  ).readAsStringSync();

  test('ledger counters are checked against reservation state', () {
    expect(propertySql, contains('counters_match_reservation_ledger'));
    expect(
      propertySql,
      contains("status in ('reserved', 'settled', 'expired')"),
    );
    expect(propertySql, contains("status = 'reserved'"));
    expect(propertySql, contains("status = 'settled'"));
    expect(propertySql, contains('full join'));
  });

  test('idempotency replay owner and nonnegative properties are explicit', () {
    expect(propertySql, contains('no_duplicate_idempotency_or_receipt_replay'));
    expect(propertySql, contains('reconciliation_owner_boundary_is_intact'));
    expect(propertySql, contains('ledger_numbers_are_nonnegative'));
    expect(propertySql, contains('provider_interaction_id'));
  });

  test('random state-machine property executes five hundred transitions', () {
    expect(propertySql, contains('perform setseed(0.453)'));
    expect(propertySql, contains('for v_iteration in 1..500 loop'));
    expect(
      propertySql,
      contains('qst_453_random_property_failed_at_iteration_'),
    );
    expect(propertySql.trimRight(), endsWith('rollback;'));
  });

  test('two authenticated sessions race for one dedicated case', () {
    expect(runner, contains('Start-Process'));
    expect(runner, contains('ReviewerAuthUserA'));
    expect(runner, contains('ReviewerAuthUserB'));
    expect(runner, contains(r"$claimCount -ne 1"));
    expect(runner, contains('exactly one claimable dedicated probe case'));
    expect(runner, contains('-WindowStyle Hidden'));
  });

  test('stale correction check happens before every persistent mutation', () {
    final stale = correction.indexOf('budget_correction_stale_snapshot');
    final counter = correction.indexOf(
      'update public.ai_usage_counters counter',
      stale,
    );
    final reservation = correction.indexOf(
      'update public.ai_budget_reservations',
      stale,
    );
    final request = correction.indexOf(
      'update public.ai_budget_correction_requests',
      stale,
    );
    final audit = correction.indexOf(
      'insert into public.ai_budget_reconciliation_operator_events',
      stale,
    );
    expect(stale, greaterThanOrEqualTo(0));
    expect(counter, greaterThan(stale));
    expect(reservation, greaterThan(counter));
    expect(request, greaterThan(reservation));
    expect(audit, greaterThan(request));
  });

  test('hosted evidence excludes credentials and direct identifiers', () {
    expect(runbook, contains('DB URL'));
    expect(runbook, contains('Service Role Key'));
    expect(runbook, contains('Auth UUID'));
    expect(runbook, contains('記録しない'));
    expect(runbook, contains('隔離されたcandidate DB'));
  });
}
