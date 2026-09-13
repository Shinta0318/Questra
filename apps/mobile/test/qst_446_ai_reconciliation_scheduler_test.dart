import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;
  final migration = File(
    '${repo.path}/supabase/migrations/'
    '202609130006_ai_budget_reconciliation_scheduler.sql',
  ).readAsStringSync();
  final edgeFunction = File(
    '${repo.path}/supabase/functions/reconcile-ai-budget/index.ts',
  ).readAsStringSync();
  final worker = File(
    '${repo.path}/supabase/functions/_shared/'
    'ai_budget_reconciliation_worker.ts',
  ).readAsStringSync();
  final runbook = File(
    '${repo.path}/docs/product/ai_budget_reconciliation_scheduler.md',
  ).readAsStringSync();

  test(
    'scheduler is disabled by default and schedule slots are idempotent',
    () {
      expect(migration, contains('enabled boolean not null default false'));
      expect(migration, contains("'ai-budget-reconciliation-scheduler'"));
      expect(migration, contains("'service_worker'"));
      expect(migration, contains("encode(digest(p_schedule_key, 'sha256')"));
      expect(migration, contains('unique check'));
      expect(migration, contains("v_run.status = 'completed'"));
      expect(migration, contains("'idempotent', true"));
    },
  );

  test('stale classification and expired leases remain lock safe', () {
    expect(migration, contains('classify_stale_ai_budget_reservations'));
    expect(migration, contains('for update skip locked'));
    expect(migration, contains('review.claim_expires_at <= now()'));
    expect(migration, contains("'lease_recovered'"));
    expect(migration, contains("'expired_claim_recovered'"));
    expect(migration, contains('alert.claim_expires_at <= now()'));
  });

  test('outgoing alert contract contains aggregate fields only', () {
    final payloadStart = worker.indexOf('export type PrivacySafeAlertPayload');
    final payloadEnd = worker.indexOf('const scheduleKeyPattern', payloadStart);
    final payloadContract = worker.substring(payloadStart, payloadEnd);
    for (final allowed in <String>[
      'alert_kind',
      'severity',
      'open_count',
      'sla_breached_count',
      'oldest_age_bucket',
    ]) {
      expect(payloadContract, contains(allowed));
    }
    for (final forbidden in <String>[
      'user_id',
      'quest_id',
      'reservation_id',
      'trace_id',
      'prompt',
      'response',
      'schedule_key',
    ]) {
      expect(payloadContract, isNot(contains(forbidden)));
    }
    expect(edgeFunction, contains('buildPrivacySafeAlertPayload(alert)'));
    expect(edgeFunction, isNot(contains('body: JSON.stringify(alert)')));
  });

  test('worker is server-only, signed, bounded, and retryable', () {
    expect(edgeFunction, contains('AI_RECONCILIATION_WORKER_SECRET'));
    expect(edgeFunction, contains('constantTimeEqual'));
    expect(edgeFunction, contains('parseHttpsEndpoint'));
    expect(edgeFunction, contains('HMAC'));
    expect(edgeFunction, contains('AbortSignal.timeout'));
    expect(
      edgeFunction,
      contains('record_ai_budget_reconciliation_worker_failure'),
    );
    expect(edgeFunction, contains('retry_after_seconds: 300'));
    expect(migration, contains("status = 'retryable_failed'"));
    expect(migration, contains("now() + interval '5 minutes'"));
    expect(migration, isNot(contains('provider_usage_estimate')));
  });

  test('runbook preserves evidence and documents the kill switch', () {
    expect(runbook, contains('既定値はOFF'));
    expect(runbook, contains('provider実行や利用量を推測しない'));
    expect(runbook, contains('利用者識別子なし'));
    expect(runbook, contains('破壊的なdown migrationは実行しない'));
    expect(runbook, contains('QST-447'));
  });
}
