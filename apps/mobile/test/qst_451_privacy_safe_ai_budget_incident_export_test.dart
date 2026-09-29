import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;
  final migration = File(
    '${repo.path}/supabase/migrations/'
    '202609150003_privacy_safe_ai_budget_incident_export.sql',
  ).readAsStringSync();
  final runbook = File(
    '${repo.path}/docs/product/ai_budget_incident_export.md',
  ).readAsStringSync();

  test('export contains only bounded aggregate incident evidence', () {
    expect(migration, contains('generate_my_ai_budget_incident_export'));
    expect(migration, contains("'reason', reason"));
    expect(migration, contains("'count', event_count"));
    expect(migration, contains("'latency_p95_ms', latency_p95_ms"));
    expect(migration, contains("'cost_micros', cost_micros"));
    expect(migration, contains('maximum_period_days'));
    expect(migration, contains('maximum_history_days'));
  });

  test('small groups are suppressed before payload construction', () {
    expect(migration, contains('minimum_group_size'));
    expect(migration, contains('event_count >= v_policy.minimum_group_size'));
    expect(migration, contains('suppressed_group_count'));
    expect(runbook, contains('5件未満'));
  });

  test('payload validator rejects content and identity fields', () {
    expect(migration, contains('enforce_ai_budget_incident_export_payload'));
    for (final forbidden in <String>[
      'prompt',
      'response',
      'quest',
      'user_id',
      'provider_interaction_id',
      'trace_id',
      'reservation_id',
    ]) {
      expect(migration, contains(forbidden));
    }
    expect(migration, contains('forbidden_ai_budget_incident_export_field'));
    expect(migration, contains("'reconciliation:' || attempt.outcome"));
    expect(
      migration,
      isNot(contains("attempt.outcome || ':' || attempt.reason")),
    );
    expect(migration, contains('jsonb_array_length'));
  });

  test('generation access expiry and deletion are audited', () {
    expect(migration, contains('generated_by_operator_id'));
    expect(migration, contains('ai_budget_incident_export_events'));
    for (final event in <String>[
      "'generated'",
      "'accessed'",
      "'expired'",
      "'deleted'",
    ]) {
      expect(migration, contains(event));
    }
    expect(migration, contains('payload_digest'));
    expect(migration, contains('aggregate_payload = null'));
  });

  test('tables are server-only and operator functions are auth-bound', () {
    for (final table in <String>[
      'ai_budget_incident_export_policies',
      'ai_budget_incident_exports',
      'ai_budget_incident_export_events',
    ]) {
      expect(
        migration,
        contains('alter table public.$table enable row level security'),
      );
      expect(migration, contains('revoke all on public.$table'));
    }
    expect(
      migration,
      contains("current_ai_reconciliation_operator('reviewer')"),
    );
    expect(runbook, contains('認証済み運用者'));
  });

  test('export cannot change billing entitlement or premium state', () {
    for (final forbiddenMutation in <String>[
      'update public.profiles',
      'update public.subscriptions',
      'update public.ai_usage_counters',
      'update public.ai_operation_controls',
    ]) {
      expect(migration, isNot(contains(forbiddenMutation)));
    }
    expect(runbook, contains('課金やPremium状態を変更しない'));
  });
}
